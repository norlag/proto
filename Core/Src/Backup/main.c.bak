/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "app_fatfs.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <stdio.h>
#include <string.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* DMA: 1000 stereo frames, each frame = 2 ch * 2 words/ch = 4 uint16_t */
#define NUM_STEREO_FRAMES 1000

/* Total samples per DMA transfer (interleaved L/R) */
#define NUM_SAMPLES (NUM_STEREO_FRAMES * 2)

/* Recording: 240 loops * 1000 frames = 48000 stereo frames = 1 sec at 48kHz */
#define MAX_RECORD_LOOPS 240

/* 24-bit output: 3 bytes per sample */
#define BYTES_PER_SAMPLE 3

/* Ping-pong buffers for audio data (half = 500 frames) */
#define HALF_FRAMES (NUM_STEREO_FRAMES / 2)
#define HALF_SAMPLES (HALF_FRAMES * 2)
#define HALF_AUDIO_SIZE (HALF_SAMPLES * BYTES_PER_SAMPLE)

/* DMA RX buffer: 24-bit I2S -> 2x16-bit words per sample, interleaved L/R */
uint16_t mic_rx_buffer[NUM_STEREO_FRAMES * 4];

/* Audio processing buffers */
int32_t stereo_audio[NUM_SAMPLES];

/* Ping-pong 24-bit buffers for non-blocking SD writes */
uint8_t audio_buf[2][HALF_AUDIO_SIZE];

/* Flags */
volatile uint8_t half_transfer = 0;
volatile uint8_t data_ready_flag = 0;
volatile uint8_t recording_started = 0;
volatile uint8_t recording_finished = 0;
volatile uint8_t sd_write_busy = 0;
volatile uint8_t sd_write_done = 0;
volatile uint8_t i2s_overrun = 0;

/* File info */
FATFS fs;
FIL fil;
UINT bw;
uint32_t total_data_bytes = 0;
uint32_t record_counter = 0;

/* WAV header: 48kHz, Stereo, 24-bit PCM */
uint8_t wav_header[44] = {
    'R', 'I', 'F', 'F',
    0, 0, 0, 0,             // [4-7] Total File Size (filled in later)
    'W', 'A', 'V', 'E',
    'f', 'm', 't', ' ',
    16, 0, 0, 0,            // Subchunk1Size (16 for PCM)
    1, 0,                   // AudioFormat (1 = PCM)
    2, 0,                   // NumChannels (2 = Stereo)
    0x80, 0xBB, 0x00, 0x00, // SampleRate (48000 Hz)
    0x00, 0x70, 0x03, 0x00, // ByteRate (48000 * 2 * 3 = 288000)
    6, 0,                   // BlockAlign (2 * 3 = 6)
    24, 0,                  // BitsPerSample (24 bits)
    'd', 'a', 't', 'a',
    0, 0, 0, 0              // [40-43] Data Size (filled in later)
};

/* Timestamp-based filename */
char filename[16];  // "YYMMDD_HHMMSS.WAV"

/* Recording state machine */
typedef enum {
    STATE_IDLE,
    STATE_MOUNTING,
    STATE_OPENING,
    STATE_WRITING_HEADER,
    STATE_RECORDING,
    STATE_FINALIZING,
    STATE_CLOSING,
    STATE_DONE
} recording_state_t;
static recording_state_t rec_state = STATE_IDLE;
static uint8_t button_pressed = 0;
static uint8_t button_debounced = 0;

/* Buffer swap tracking */
static volatile uint8_t half_buf_idx = 0;  // which buf half we're filling
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
ADC_HandleTypeDef hadc1;

I2S_HandleTypeDef hi2s2;
DMA_HandleTypeDef hdma_spi2_rx;

SPI_HandleTypeDef hspi1;

/* USER CODE BEGIN PV */
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_DMA_Init(void);
static void MX_ADC1_Init(void);
static void MX_I2S2_Init(void);
static void MX_SPI1_Init(void);
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* Generate timestamp filename: YYMMDD_HHMMSS.WAV */
static void generate_filename(void)
{
    /* Use HAL_GetTick() as a simple counter since we don't have RTC */
    uint32_t tick = HAL_GetTick();
    uint32_t fake_time = (tick / 1000) % 86400;
    uint32_t fake_date = (tick / 86400000) % 1000000;

    uint8_t hh = (fake_time / 3600) % 24;
    uint8_t mm = (fake_time / 60) % 60;
    uint8_t ss = fake_time % 60;
    uint16_t yy = (fake_date / 10000) % 100;
    uint8_t month = (fake_date / 100) % 100;
    uint8_t dd = fake_date % 100;

    sprintf(filename, "%02d%02d%02d_%02d%02d%02d.WAV",
            yy, month, dd, hh, mm, ss);
}

/* Check if button (PB7) is pressed (active low with pull-up assumed) */
static uint8_t is_button_pressed(void)
{
    return (HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_7) == GPIO_PIN_RESET);
}

/* Extract 24-bit sample from HAL I2S 24-bit + HALFWORD DMA format.
 * DMA delivers each 24-bit sample as two 16-bit words:
 *   buffer[0] = low 16 bits
 *   buffer[1] = high 8 bits (in low byte of 2nd word, sign-extended)
 * This function extracts a sample at sample_idx from the DMA buffer.
 */
static int32_t extract_24bit_sample(const uint16_t *dma_buf, uint32_t sample_idx)
{
    uint32_t buf_idx = sample_idx * 2;
    /* Low 16 bits */
    uint16_t low = dma_buf[buf_idx];
    /* High byte: sign-extended by HAL in HALFWORD mode */
    int8_t high = (int8_t)(dma_buf[buf_idx + 1] >> 8);
    return ((int32_t)high << 16) | low;
}

/* Convert DMA buffer to 24-bit ping-pong buffer.
 * buf_idx: 0 = first half, 1 = second half
 * start_sample: first sample index for this half
 */
static void process_to_24bit(uint8_t buf_idx, uint32_t start_sample)
{
    uint8_t *dst = audio_buf[buf_idx];
    const uint16_t *src = mic_rx_buffer;
    uint32_t half_samples = HALF_SAMPLES;

    for (uint32_t i = 0; i < half_samples; i++) {
        int32_t sample = extract_24bit_sample(src, start_sample + i);
        uint32_t dst_idx = i * 3;
        /* Write 24-bit little-endian */
        dst[dst_idx]     = (uint8_t)(sample & 0xFF);
        dst[dst_idx + 1] = (uint8_t)((sample >> 8) & 0xFF);
        dst[dst_idx + 2] = (uint8_t)((sample >> 16) & 0xFF);
    }
}

/* Non-blocking SD write function */
static FRESULT sd_write_audio(const uint8_t *data, uint32_t size)
{
    FRESULT res = f_write(&fil, data, size, &bw);
    if (res == FR_OK) {
        total_data_bytes += bw;
        record_counter++;
    }
    return res;
}

/* Finalize WAV file header */
static void finalize_wav_file(void)
{
    uint32_t file_size = total_data_bytes + 36;

    f_lseek(&fil, 4);
    f_write(&fil, &file_size, 4, &bw);

    f_lseek(&fil, 40);
    f_write(&fil, &total_data_bytes, 4, &bw);

    f_sync(&fil);
}

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_DMA_Init();
  MX_ADC1_Init();
  MX_I2S2_Init();
  MX_SPI1_Init();
  if (MX_FATFS_Init() != APP_OK) {
    Error_Handler();
  }
  /* USER CODE BEGIN 2 */

    /* Initialize mic select pins */
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_1, GPIO_PIN_SET);   // PA1 = Right Mic
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_2, GPIO_PIN_RESET); // PA2 = Left Mic

    /* Generate initial filename */
    generate_filename();

    /* LED off initially */
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_7, GPIO_PIN_RESET);

  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* Button state machine: detect rising edge on PB7 to start/stop recording */
    if (is_button_pressed() && !button_debounced) {
        button_pressed = 1;
    }
    if (!is_button_pressed() && button_pressed) {
        button_pressed = 0;
        button_debounced = 1;
    }
    if (!is_button_pressed() && !button_pressed) {
        button_debounced = 0;
    }

    /* Start recording on button press */
    if (button_debounced && rec_state == STATE_IDLE && !recording_started) {
        button_debounced = 0;
        generate_filename();
        rec_state = STATE_MOUNTING;
    }

    /* State machine for recording */
    switch (rec_state) {

    case STATE_MOUNTING:
        if (f_mount(&fs, "", 1) == FR_OK) {
            rec_state = STATE_OPENING;
        } else {
            Error_Handler();  // SD mount failed
        }
        break;

    case STATE_OPENING:
        if (f_open(&fil, filename, FA_CREATE_ALWAYS | FA_WRITE) == FR_OK) {
            rec_state = STATE_WRITING_HEADER;
        } else {
            Error_Handler();  // File open failed
        }
        break;

    case STATE_WRITING_HEADER:
        if (f_write(&fil, wav_header, 44, &bw) == FR_OK) {
            /* Turn on LED to indicate recording has started */
            HAL_GPIO_WritePin(GPIOA, GPIO_PIN_7, GPIO_PIN_SET);
            /* Start DMA capture with ping-pong half-buffer callbacks */
            HAL_I2S_Receive_DMA(&hi2s2, (uint32_t *)mic_rx_buffer,
                                NUM_STEREO_FRAMES * 4);
            recording_started = 1;
            rec_state = STATE_RECORDING;
        } else {
            Error_Handler();  // Header write failed
        }
        break;

    case STATE_RECORDING:
        /* Handle button press to stop recording */
        if (button_debounced) {
            button_debounced = 0;
            if (record_counter > 0) {
                rec_state = STATE_FINALIZING;
            } else {
                /* Too short, abort */
                HAL_I2S_DMAStop(&hi2s2);
                f_close(&fil);
                f_mount(NULL, "", 1);
                HAL_GPIO_WritePin(GPIOA, GPIO_PIN_7, GPIO_PIN_RESET);
                rec_state = STATE_IDLE;
                recording_started = 0;
                total_data_bytes = 0;
                record_counter = 0;
            }
        }

        /* Check for I2S overrun */
        if (i2s_overrun) {
            i2s_overrun = 0;
            /* Overrun detected - could blink LED to indicate */
        }

        /* Handle half-transfer callback: process first half of DMA buffer */
        if (half_transfer) {
            half_transfer = 0;
            /* Process first half (samples 0..HALF_SAMPLES-1) into buf[0] */
            process_to_24bit(0, 0);
            /* Start DMA again with offset address for second half transfer */
            /* We use DMA half-transfer to signal first half is ready */
        }

        /* Handle transfer-complete callback: process second half */
        if (data_ready_flag) {
            data_ready_flag = 0;
            /* Process second half (samples HALF_SAMPLES..NUM_SAMPLES-1) into buf[1] */
            process_to_24bit(1, HALF_SAMPLES);

            /* Now write buf[0] to SD (it was processed on half-transfer) */
            if (sd_write_audio(audio_buf[0], HALF_AUDIO_SIZE) != FR_OK) {
                Error_Handler();  // SD write failed
            }

            /* Check if recording is complete */
            if (record_counter >= MAX_RECORD_LOOPS) {
                rec_state = STATE_FINALIZING;
                break;
            }

            /* Restart DMA for next transfer */
            HAL_I2S_Receive_DMA(&hi2s2, (uint32_t *)mic_rx_buffer,
                                NUM_STEREO_FRAMES * 4);
        }
        break;

    case STATE_FINALIZING:
        /* Stop DMA and I2S */
        HAL_I2S_DMAStop(&hi2s2);
        /* Wait for any pending DMA to complete */
        finalize_wav_file();
        rec_state = STATE_CLOSING;
        break;

    case STATE_CLOSING:
        if (f_close(&fil) == FR_OK) {
            f_mount(NULL, "", 1);
            /* Turn OFF LED to show recording is complete */
            HAL_GPIO_WritePin(GPIOA, GPIO_PIN_7, GPIO_PIN_RESET);
            rec_state = STATE_DONE;
        } else {
            Error_Handler();  // Close failed
        }
        break;

    case STATE_DONE:
        /* Recording complete - wait for button press to start again */
        if (!button_debounced && !is_button_pressed()) {
            /* Reset for next recording */
            recording_started = 0;
            recording_finished = 1;
            total_data_bytes = 0;
            record_counter = 0;
            rec_state = STATE_IDLE;
        }
        break;

    default:
        rec_state = STATE_IDLE;
        break;
    }

    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  HAL_PWREx_ControlVoltageScaling(PWR_REGULATOR_VOLTAGE_SCALE1_BOOST);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
  RCC_OscInitStruct.PLL.PLLM = RCC_PLLM_DIV1;
  RCC_OscInitStruct.PLL.PLLN = 20;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
  RCC_OscInitStruct.PLL.PLLQ = RCC_PLLQ_DIV2;
  RCC_OscInitStruct.PLL.PLLR = RCC_PLLR_DIV2;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_4) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief ADC1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_ADC1_Init(void)
{

  /* USER CODE BEGIN ADC1_Init 0 */

  /* USER CODE END ADC1_Init 0 */

  ADC_MultiModeTypeDef multimode = {0};
  ADC_ChannelConfTypeDef sConfig = {0};

  /* USER CODE BEGIN ADC1_Init 1 */

  /* USER CODE END ADC1_Init 1 */

  /** Common config
  */
  hadc1.Instance = ADC1;
  hadc1.Init.ClockPrescaler = ADC_CLOCK_SYNC_PCLK_DIV4;
  hadc1.Init.Resolution = ADC_RESOLUTION_12B;
  hadc1.Init.DataAlign = ADC_DATAALIGN_RIGHT;
  hadc1.Init.GainCompensation = 0;
  hadc1.Init.ScanConvMode = ADC_SCAN_DISABLE;
  hadc1.Init.EOCSelection = ADC_EOC_SINGLE_CONV;
  hadc1.Init.LowPowerAutoWait = DISABLE;
  hadc1.Init.ContinuousConvMode = DISABLE;
  hadc1.Init.NbrOfConversion = 1;
  hadc1.Init.DiscontinuousConvMode = DISABLE;
  hadc1.Init.ExternalTrigConv = ADC_SOFTWARE_START;
  hadc1.Init.ExternalTrigConvEdge = ADC_EXTERNALTRIGCONVEDGE_NONE;
  hadc1.Init.DMAContinuousRequests = DISABLE;
  hadc1.Init.Overrun = ADC_OVR_DATA_PRESERVED;
  hadc1.Init.OversamplingMode = DISABLE;
  if (HAL_ADC_Init(&hadc1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure the ADC multi-mode
  */
  multimode.Mode = ADC_MODE_INDEPENDENT;
  if (HAL_ADCEx_MultiModeConfigChannel(&hadc1, &multimode) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Regular Channel
  */
  sConfig.Channel = ADC_CHANNEL_1;
  sConfig.Rank = ADC_REGULAR_RANK_1;
  sConfig.SamplingTime = ADC_SAMPLETIME_2CYCLES_5;
  sConfig.SingleDiff = ADC_SINGLE_ENDED;
  sConfig.OffsetNumber = ADC_OFFSET_NONE;
  sConfig.Offset = 0;
  if (HAL_ADC_ConfigChannel(&hadc1, &sConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN ADC1_Init 2 */

  /* USER CODE END ADC1_Init 2 */

}

/**
  * @brief I2S2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_I2S2_Init(void)
{

  /* USER CODE BEGIN I2S2_Init 0 */

  /* USER CODE END I2S2_Init 0 */

  /* USER CODE BEGIN I2S2_Init 1 */

  /* USER CODE END I2S2_Init 1 */
  hi2s2.Instance = SPI2;
  hi2s2.Init.Mode = I2S_MODE_MASTER_RX;
  hi2s2.Init.Standard = I2S_STANDARD_PHILIPS;
  hi2s2.Init.DataFormat = I2S_DATAFORMAT_24B;
  hi2s2.Init.MCLKOutput = I2S_MCLKOUTPUT_DISABLE;
  hi2s2.Init.AudioFreq = I2S_AUDIOFREQ_48K;
  hi2s2.Init.CPOL = I2S_CPOL_LOW;
  if (HAL_I2S_Init(&hi2s2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN I2S2_Init 2 */

  /* USER CODE END I2S2_Init 2 */

}

/**
  * @brief SPI1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI1_Init(void)
{

  /* USER CODE BEGIN SPI1_Init 0 */

  /* USER CODE END SPI1_Init 0 */

  /* USER CODE BEGIN SPI1_Init 1 */

  /* USER CODE END SPI1_Init 1 */
  /* SPI1 parameter configuration*/
  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_256;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 7;
  hspi1.Init.CRCLength = SPI_CRC_LENGTH_DATASIZE;
  hspi1.Init.NSSPMode = SPI_NSS_PULSE_ENABLE;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI1_Init 2 */

  /* USER CODE END SPI1_Init 2 */

}

/**
  * Enable DMA controller clock
  */
static void MX_DMA_Init(void)
{

  /* DMA controller clock enable */
  __HAL_RCC_DMAMUX1_CLK_ENABLE();
  __HAL_RCC_DMA1_CLK_ENABLE();

  /* DMA interrupt init */
  /* DMA1_Channel1_IRQn interrupt configuration */
  HAL_NVIC_SetPriority(DMA1_Channel1_IRQn, 0, 0);
  HAL_NVIC_EnableIRQ(DMA1_Channel1_IRQn);

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOF_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOA, GPIO_PIN_1|GPIO_PIN_2|GPIO_PIN_3|GPIO_PIN_4
                          |GPIO_PIN_5|GPIO_PIN_6|GPIO_PIN_7, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_6, GPIO_PIN_SET);

  /*Configure GPIO pins : PA1 PA2 PA3 PA4
                           PA5 PA6 PA7 */
  GPIO_InitStruct.Pin = GPIO_PIN_1|GPIO_PIN_2|GPIO_PIN_3|GPIO_PIN_4
                          |GPIO_PIN_5|GPIO_PIN_6|GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /*Configure GPIO pin : PB6 */
  GPIO_InitStruct.Pin = GPIO_PIN_6;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pin : PB7 */
  GPIO_InitStruct.Pin = GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_PULLUP;  // Button needs pull-up
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */
// Ping-pong DMA callbacks for non-blocking audio processing + SD writes

// Called when half of the DMA buffer is full (half-transfer complete)
void HAL_I2S_RxHalfCpltCallback(I2S_HandleTypeDef *hi2s)
{
    if (hi2s->Instance == SPI2)
    {
        half_transfer = 1;
    }
}

// Called when the full DMA buffer is transferred (transfer complete)
void HAL_I2S_RxCpltCallback(I2S_HandleTypeDef *hi2s)
{
    if (hi2s->Instance == SPI2)
    {
        data_ready_flag = 1;
    }
}

// Called when DMA transfer is interrupted (error or abort)
void HAL_I2S_ErrorCallback(I2S_HandleTypeDef *hi2s)
{
    if (hi2s->Instance == SPI2)
    {
        // Check for overrun/underrun
        uint32_t isr = hi2s->Instance->ISR;
        if (isr & SPI_ISR_OVR) {
            i2s_overrun = 1;
            // Clear OVR flag
            __HAL_I2S_GET_FLAG(hi2s, SPI_FLAG_OVR);
            (void)hi2s->Instance->DR;
        }
    }
}
/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
    // Blink LED rapidly to indicate error
    HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_7);
    for (volatile uint32_t i = 0; i < 100000; i++);
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param file: pointer to the source file name
  * @param line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
