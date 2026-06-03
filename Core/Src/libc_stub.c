#include <stddef.h>

void *memset(void *s, int c, size_t n) {
    unsigned char *p = (unsigned char *)s;
    for (size_t i = 0; i < n; i++) p[i] = (unsigned char)c;
    return s;
}

/* Weak symbol to satisfy crtbegin.o - must be a data symbol */
extern void *__TMC_END__;
__attribute__((weak, section(".data"))) void *__TMC_END__ = 0;

/* Stub: newlib init array - we don't use C++ so this is a no-op */
void __libc_init_array(void) {}
