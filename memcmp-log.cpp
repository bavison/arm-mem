#include <algorithm>
#include <iterator>
#include <map>
#include <mutex>
#include <string>

#include <cstdlib>
#include <cstddef>
#include <cstdint>

#include <sys/types.h>
#include <unistd.h>

static std::mutex mutex;
static bool registered;
static std::map<void *, uint32_t> map;

extern "C" int neon_memcmp(const void *s1, const void *s2, size_t n);

static void myatexit(void)
{
    /* Make a container of memcmp caller addresses, sorted by frequency */
    mutex.lock();
    std::multimap<uint32_t, void *> by_freq;
    std::transform(map.begin(), map.end(), std::inserter(by_freq, by_freq.begin()),
            [](const std::pair<void *, uint32_t> &p) {
        return std::pair<uint32_t, void *>(p.second, p.first);
    });
    mutex.unlock();

    for (auto it = by_freq.rbegin(); it != by_freq.rend(); it++)
    {
        /* The invocation of addr2line appears to call memcmp once; avoid recursion by filtering these out */
        if (it->first > 1)
        {
            char cmd[1024];
            printf("%u calls from:\n", it->first);
            snprintf(cmd, 1024, "awk '{split($1,range,\"-\"); if (range[1] <= \"%08x\" && \"%08x\" < range[2]) print $6 }' /proc/%d/maps", it->second, it->second, getpid());
            system(cmd);
            snprintf(cmd, 1024, "addr2line -C -e /proc/%d/exe -f %p", getpid(), it->second);
            system(cmd);
        }
    }
}

extern "C" int memcmp(const void *s1, const void *s2, size_t n)
{
    mutex.lock();
    if (!registered++)
        atexit(myatexit);
    ++map[__builtin_return_address(0)];
    mutex.unlock();

    int result = 0;
    const uint8_t *p1 = (const uint8_t *) s1, *p2 = (const uint8_t *) s2;
    for (; !result && n--; p1++, p2++)
        result = *p1 - *p2;
    return result;
}
