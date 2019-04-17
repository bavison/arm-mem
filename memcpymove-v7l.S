/*
Copyright (c) 2019, RISC OS Open Ltd
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

#include "arm-mem.h"

/* Prevent the stack from becoming executable */
#if defined(__linux__) && defined(__ELF__)
.section .note.GNU-stack,"",%progbits
#endif

    .text
    .fpu neon
    .arch armv7a
    .object_arch armv4
    .arm
    .altmacro
    .p2align 2

        D_1     .req    a1
        S_1     .req    a2
        N       .req    a3
        D_2     .req    a4
        S_2     .req    v1
        OFF1    .req    ip
        OFF2    .req    lr

.macro label string, number
__label \string, %number
.endm

.macro __label string, number
\string\number\():
.endm

.macro labelref string, number
__labelref \string, %number
.endm

.macro __labelref string, number
       .word   \string\number - 00b - 4
.endm

.macro memcpy_fw  align
 .if align == 0
        push    {a1, lr}
        .cfi_def_cfa_offset 8
        .cfi_rel_offset D_1, 0
        .cfi_rel_offset OFF2, 4
 .else
        push    {a1, v1, lr}
        .cfi_def_cfa_offset 12
        .cfi_rel_offset D_1, 0
        .cfi_rel_offset S_2, 4
        .cfi_rel_offset OFF2, 8
 .endif
        .cfi_undefined  S_1
        .cfi_undefined  N
        ands    ip, D_1, #15
        beq     10f

        // Leading 1..15 bytes
        rsb     ip, #16
        sub     N, ip
        lsls    lr, ip, #31
        ldrmib  lr, [S_1], #1
        strmib  lr, [D_1], #1
        ldrcsh  lr, [S_1], #2
        strcsh  lr, [D_1], #2
        lsls    lr, ip, #29
        ldrmi   lr, [S_1], #4
        strmi   lr, [D_1], #4
        bcc     10f
        vld1.8  {d0}, [S_1]!
        vst1.32 {d0}, [D_1 :64]!

        // Align destination to cacheline
10:     subs    N, #16
        bmi     12f
11:     tst     D_1, #48
        beq     12f
        vld1.8  {d0-d1}, [S_1]!
        subs    N, #16
        vst1.32 {d0-d1}, [D_1 :128]!
        bpl     11b
12:

 .if align == 0
        // Middle n * 32 bytes
        subs    N, #32-16
        bmi     14f
13:     vld1.32 {d0-d3}, [S_1 :64]!
        subs    N, #32
        vst1.32 {d0-d3}, [D_1 :256]!
        bpl     13b

        // Trailing 0..31 bytes
14:     lsls    N, #27
        beq     19f

 .else
        // Middle n * 64 bytes
        sub     S_1, #align
        add     D_2, D_1, #16
        add     S_2, S_1, #16
        mov     OFF1, #16
        mov     OFF2, #32
        vld1.32 {d16}, [S_1 :64]!
        subs     N, #64-16
        bmi     14f
13:     vld1.32 {d1}, [S_1 :64], OFF1
        vld1.32 {d2}, [S_2 :64], OFF1
        vld1.32 {d3}, [S_1 :64], OFF1
        subs    N, #64
        vld1.32 {d4}, [S_2 :64], OFF1
        vext.8  d0, d16, d1, #align
        vld1.32 {d5}, [S_1 :64], OFF1
        vext.8  d1, d1, d2, #align
        vld1.32 {d6}, [S_2 :64], OFF1
        vext.8  d2, d2, d3, #align
        vld1.32 {d7}, [S_1 :64], OFF1
        vext.8  d3, d3, d4, #align
        vld1.32 {d16}, [S_2 :64], OFF1
        vext.8  d4, d4, d5, #align
        vst1.32 {q0}, [D_1 :128], OFF2
        vext.8  d5, d5, d6, #align
        vst1.32 {q1}, [D_2 :128], OFF2
        vext.8  d6, d6, d7, #align
        vst1.32 {q2}, [D_1 :128], OFF2
        vext.8  d7, d7, d16, #align
        vst1.32 {q3}, [D_2 :128], OFF2
        bpl     13b

        // Trailing 0..63 bytes
14:     tst     N, #63
        beq     19f
        lsls    N, #27
        bcc     15f
        vld1.32 {d5}, [S_1 :64], OFF1
        vld1.32 {d6}, [S_2 :64], OFF1
        vmov    d0, d16
        vld1.32 {d7}, [S_1 :64], OFF1
        vld1.32 {d16}, [S_2 :64], OFF1
        vext.8  d4, d0, d5, #align
        vext.8  d5, d5, d6, #align
        vst1.32 {q2}, [D_1 :128], OFF2
        vext.8  d6, d6, d7, #align
        vext.8  d7, d7, d16, #align
        vst1.32 {q3}, [D_2 :128], OFF2
15:     add     S_1, #align - 8
 .endif
        bpl     16f
        vld1.8  {d0-d1}, [S_1]!
        vst1.32 {d0-d1}, [D_1 :128]!
16:     lsls    N, #2
        bcc     17f
        vld1.8  {d0}, [S_1]!
        vst1.32 {d0}, [D_1 :64]!
17:     ldrmi   lr, [S_1], #4
        strmi   lr, [D_1], #4
        lsls    N, #2
        ldrcsh  lr, [S_1], #2
        strcsh  lr, [D_1], #2
        ldrmib  lr, [S_1]
        strmib  lr, [D_1]
19:
 .if align == 0
        pop     {a1, pc}
 .else
        pop     {a1, v1, pc}
 .endif
.endm

/*
 * void *memcpy(void * restrict s1, const void * restrict s2, size_t n);
 * On entry:
 * a1 = pointer to destination
 * a2 = pointer to source
 * a3 = number of bytes to copy
 * On exit:
 * a1 preserved
 */

myfunc memcpy
1000:
        .cfi_startproc
        .cfi_undefined  D_2
        .cfi_undefined  OFF1
        add     ip, D_1, N
        sub     a4, S_1, D_1
        eor     ip, D_1
        and     a4, #7
        bics    ip, #15
        beq     20f
        ldr     ip, [pc, a4, lsl #2]
        add     pc, ip
 00:
 .set align, 0
 .rept 8
        labelref .Lfw, align
 .set align, align + 1
 .endr

 .set align, 0
 .rept 8
        label .Lfw, align
        memcpy_fw  align
 .set align, align + 1
 .endr

        // Short case: 0..15 bytes, arbitrary alignment
20:     push    {a1, lr}
        .cfi_def_cfa_offset 8
        .cfi_rel_offset D_1, 0
        .cfi_rel_offset OFF2, 4
        tst     D_1, #3
        beq     22f
21:     subs    N, #1
        bmi     29f
        ldrb    a4, [S_1], #1
        add     ip, D_1, #1
        tst     ip, #3
        strb    a4, [D_1], #1
        bne     21b
22:     lsls    N, #29
        bcc     23f
        vld1.8  {d0}, [S_1]!
        vst1.8  {d0}, [D_1]!
23:     ldrmi   lr, [S_1], #4
        strmi   lr, [D_1], #4
        lsls    N, #2
        ldrcsh  lr, [S_1], #2
        strcsh  lr, [D_1], #2
        ldrmib  lr, [S_1]
        strmib  lr, [D_1]
29:     pop     {a1, pc}
        .cfi_endproc

.endfunc


.macro memcpy_bw  align
 .if align != 0
        push    {v1}
        .cfi_def_cfa_offset 12
        .cfi_rel_offset D_1, 0
        .cfi_rel_offset S_2, 4
        .cfi_rel_offset OFF2, 8
 .endif
        .cfi_undefined  N
        ands    ip, D_1, #15
        beq     10f

        // Leading 1..15 bytes
        sub     N, ip
        lsls    lr, ip, #31
        ldrmib  lr, [S_1, #-1]!
        strmib  lr, [D_1, #-1]!
        ldrcsh  lr, [S_1, #-2]!
        strcsh  lr, [D_1, #-2]!
        lsls    lr, ip, #29
        ldrmi   lr, [S_1, #-4]!
        strmi   lr, [D_1, #-4]!
        bcc     10f
        sub     S_1, #8
        sub     D_1, #8
        vld1.8  {d0}, [S_1]
        vst1.32 {d0}, [D_1 :64]

        // Align destination to cacheline
10:     sub     S_1, #16
        sub     D_2, D_1, #16
        subs    N, #16
        bmi     12f
        mov     OFF1, #-16
11:     tst     D_1, #48
        beq     12f
        vld1.8  {d0-d1}, [S_1], OFF1
        sub     D_1, #16
        vst1.32 {d0-d1}, [D_2 :128], OFF1
        subs    N, #16
        bpl     11b
12:

 .if align == 0
        // Middle n * 32 bytes
        mov     OFF1, #-32
        sub     S_1, #32-16
        sub     D_1, #32
        subs    N, #32-16
        bmi     14f
13:     vld1.32 {d0-d3}, [S_1 :64], OFF1
        subs    N, #32
        vst1.32 {d0-d3}, [D_1 :256], OFF1
        bpl     13b

        // Trailing 0..31 bytes
14:     add     S_1, #32
        add     D_1, #32
        lsls    N, #27
        beq     19f

 .else
        // Middle n * 64 bytes
        sub     D_1, #16
        sub     S_1, #align - 16
        sub     D_2, D_1, #16
        sub     S_2, S_1, #8 + 8
        mov     OFF1, #-16
        mov     OFF2, #-32
        vld1.32 {d1}, [S_1]
        sub     S_1, #8
        subs    N, #64-16
        bmi     14f
13:     vld1.32 {d16}, [S_1 :64], OFF1
        vld1.32 {d7}, [S_2 :64], OFF1
        vld1.32 {d6}, [S_1 :64], OFF1
        subs    N, #64
        vld1.32 {d5}, [S_2 :64], OFF1
        vext.8  d17, d16, d1, #align
        vld1.32 {d4}, [S_1 :64], OFF1
        vext.8  d16, d7, d16, #align
        vld1.32 {d3}, [S_2 :64], OFF1
        vext.8  d7, d6, d7, #align
        vld1.32 {d2}, [S_1 :64], OFF1
        vext.8  d6, d5, d6, #align
        vld1.32 {d1}, [S_2 :64], OFF1
        vext.8  d5, d4, d5, #align
        vst1.32 {q8}, [D_1 :128], OFF2
        vext.8  d4, d3, d4, #align
        vst1.32 {q3}, [D_2 :128], OFF2
        vext.8  d3, d2, d3, #align
        vst1.32 {q2}, [D_1 :128], OFF2
        vext.8  d2, d1, d2, #align
        vst1.32 {q1}, [D_2 :128], OFF2
        bpl     13b

        // Trailing 0..63 bytes
14:     tst     N, #63
        beq     19f
        lsls    N, #27
        bcc     15f
        vld1.32 {d4}, [S_1 :64], OFF1
        vld1.32 {d3}, [S_2 :64], OFF1
        vmov    d16, d1
        vld1.32 {d2}, [S_1 :64], OFF1
        vld1.32 {d1}, [S_2 :64], OFF1
        vext.8  d5, d4, d16, #align
        vext.8  d4, d3, d4, #align
        vst1.32 {q2}, [D_1 :128], OFF2
        vext.8  d3, d2, d3, #align
        vext.8  d2, d1, d2, #align
        vst1.32 {q1}, [D_2 :128], OFF2
15:     add     D_1, #16
        add     S_1, #8 + align
 .endif
        bpl     16f
        sub     S_1, #16
        sub     D_1, #16
        vld1.8  {d0-d1}, [S_1]
        vst1.32 {d0-d1}, [D_1 :128]
16:     lsls    N, #2
        bcc     17f
        sub     S_1, #8
        sub     D_1, #8
        vld1.8  {d0}, [S_1]
        vst1.32 {d0}, [D_1 :64]
17:     ldrmi   lr, [S_1, #-4]!
        strmi   lr, [D_1, #-4]!
        lsls    N, #2
        ldrcsh  lr, [S_1, #-2]!
        strcsh  lr, [D_1, #-2]!
        ldrmib  lr, [S_1, #-1]
        strmib  lr, [D_1, #-1]
19:
 .if align == 0
        mov     a1, v1
        pop     {v1, pc}
 .else
        pop     {a1, v1, pc}
 .endif
.endm

/*
 * void *memmove(void *s1, const void *s2, size_t n);
 * On entry:
 * a1 = pointer to destination
 * a2 = pointer to source
 * a3 = number of bytes to copy
 * On exit:
 * a1 preserved
 */

myfunc memmove
        .cfi_startproc
        .cfi_undefined  D_2
        .cfi_undefined  OFF1
        cmp     a2, a1
        bpl     1000b   /* pl works even over -1 - 0 and 0x7fffffff - 0x80000000 boundaries */
        push    {v1, lr}
        .cfi_def_cfa_offset 8
        .cfi_rel_offset S_2, 0
        .cfi_rel_offset OFF2, 4
        mov     v1, a1
        add     ip, D_1, N
        sub     a4, S_1, D_1
        eor     D_1, ip, D_1
        .cfi_undefined  D_1
        and     a4, #7
        bics    D_1, #15
        mov     D_1, ip
        add     S_1, N
        .cfi_undefined  S_1
        beq     20f
        ldr     ip, [pc, a4, lsl #2]
        add     pc, ip
 00:
 .set align, 0
 .rept 8
        labelref .Lbw, align
 .set align, align + 1
 .endr

 .set align, 0
 .rept 8
        label .Lbw, align
        memcpy_bw  align
 .set align, align + 1
 .endr

        // Short case: 0..15 bytes, arbitrary alignment
        .cfi_def_cfa_offset 8
        .cfi_undefined  D_1
        .cfi_rel_offset S_2, 0
        .cfi_rel_offset OFF2, 4
20:     tst     D_1, #3
        beq     22f
21:     subs    N, #1
        bmi     29f
        ldrb    a4, [S_1, #-1]!
        sub     ip, D_1, #1
        tst     ip, #3
        strb    a4, [D_1, #-1]!
        bne     21b
22:     lsls    N, #29
        bcc     23f
        sub     S_1, #8
        sub     D_1, #8
        vld1.8  {d0}, [S_1]
        vst1.8  {d0}, [D_1]
23:     ldrmi   lr, [S_1, #-4]!
        strmi   lr, [D_1, #-4]!
        lsls    N, #2
        ldrcsh  lr, [S_1, #-2]!
        strcsh  lr, [D_1, #-2]!
        ldrmib  lr, [S_1, #-1]
        strmib  lr, [D_1, #-1]
29:     mov     a1, v1
        pop     {v1, pc}
        .cfi_endproc

.endfunc


/*
 * void *mempcpy(void * restrict s1, const void * restrict s2, size_t n);
 * On entry:
 * a1 = pointer to destination
 * a2 = pointer to source
 * a3 = number of bytes to copy
 * On exit:
 * a1 = pointer to immediately after destination block
 */

myfunc mempcpy
.global __mempcpy
__mempcpy:
        .cfi_startproc
        push    {v1, lr}
        .cfi_def_cfa_offset 8
        .cfi_rel_offset v1, 0
        .cfi_rel_offset lr, 4
        mov     v1, a3
        bl      1000b
        add     a1, a1, v1
        pop     {v1, pc}
        .cfi_endproc
.endfunc
