/*
Copyright (c) 2015, RISC OS Open Ltd
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the copyright holder nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#define _GNU_SOURCE /* enable mempcpy */
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <elf.h>

#define DISPATCH_ON_NEON(func,suffix0,suffix1)           \
    typeof(func) func##_##suffix0;                       \
    typeof(func) func##_##suffix1;                       \
    asm(".type " #func ", %gnu_indirect_function");      \
    typeof(func) *func##_dispatch(void) __asm__(#func);  \
    typeof(func) *func##_dispatch(void)                  \
    {                                                    \
        Elf32_auxv_t aux;                                \
        int fd = open("/proc/self/auxv", O_RDONLY);      \
        if (fd < 0) /* Error? */                         \
            return func##_##suffix0;                     \
        while (read(fd, &aux, sizeof aux) == sizeof aux) \
        {                                                \
            if (aux.a_type == AT_HWCAP)                  \
            {                                            \
                close(fd);                               \
                return aux.a_un.a_val & 4096 ?           \
                    func##_##suffix1 : func##_##suffix0; \
            }                                            \
        }                                                \
        close(fd);                                       \
        return func##_##suffix0;                         \
    }                                                    \

DISPATCH_ON_NEON(memcpy,arm1176jzfs,cortexa7)
DISPATCH_ON_NEON(memmove,arm1176jzfs,cortexa7)
DISPATCH_ON_NEON(mempcpy,arm1176jzfs,cortexa7)
