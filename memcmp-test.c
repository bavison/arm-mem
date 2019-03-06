#include <assert.h>
#include <stddef.h>
#include <stdint.h>

#define SIGNOF(x) (((x)>0)-((x)<0))

extern int neon_memcmp(const void *s1, const void *s2, size_t n);

int memcmp(const void *s1, const void *s2, size_t n)
{
    int result = 0, neon_result = neon_memcmp(s1, s2, n);
    const uint8_t *p1 = s1, *p2 = s2;
    for (; !result && n--; p1++, p2++)
        result = *p1 - *p2;
    assert(SIGNOF(result) == SIGNOF(neon_result));
    return result;
}
