/*
Copyright (c) 2013, Raspberry Pi Foundation
Copyright (c) 2013, RISC OS Open Ltd
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

.macro memcpy_leading_15bytes backwards
 .if backwards
        movs    DAT3, DAT2, lsl #31
        ldrmib  DAT0, [S, #-1]!
        ldrcsh  DAT1, [S, #-2]!
        submi   N, N, #1
        subcs   N, N, #2
        strmib  DAT0, [D, #-1]!
        strcsh  DAT1, [D, #-2]!
        movs    DAT3, DAT2, lsl #29
        ldrmi   DAT0, [S, #-4]!
        ldrcs   DAT2, [S, #-4]! /* use 2 LDRs in case source is misaligned */
        ldrcs   DAT1, [S, #-4]!
        submi   N, N, #4
        subcs   N, N, #8
        strmi   DAT0, [D, #-4]!
        stmcsdb D!, {DAT1, DAT2} /* but destination will be word-aligned */
 .else
        movs    DAT3, DAT2, lsl #31
        ldrmib  DAT0, [S], #1
        ldrcsh  DAT1, [S], #2
        submi   N, N, #1
        subcs   N, N, #2
        strmib  DAT0, [D], #1
        strcsh  DAT1, [D], #2
        movs    DAT3, DAT2, lsl #29
        ldrmi   DAT0, [S], #4
        ldrcs   DAT1, [S], #4 /* use 2 LDRs in case source is misaligned */
        ldrcs   DAT2, [S], #4
        submi   N, N, #4
        subcs   N, N, #8
        strmi   DAT0, [D], #4
        stmcsia D!, {DAT1, DAT2} /* but destination will be word-aligned */
 .endif
.endm

.macro memcpy_trailing_15bytes  backwards, unaligned
 .if backwards
        movs    N, N, lsl #29
  .if unaligned
        ldrcs   DAT1, [S, #-4]!
        ldrcs   DAT0, [S, #-4]!
  .else
        ldmcsdb S!, {DAT0, DAT1}
  .endif
        ldrmi   DAT2, [S, #-4]!
        stmcsdb D!, {DAT0, DAT1}
        strmi   DAT2, [D, #-4]!
        movs    N, N, lsl #2
        ldrcsh  DAT0, [S, #-2]!
        ldrmib  DAT1, [S, #-1]
        strcsh  DAT0, [D, #-2]!
        strmib  DAT1, [D, #-1]
 .else
        movs    N, N, lsl #29
  .if unaligned
        ldrcs   DAT0, [S], #4
        ldrcs   DAT1, [S], #4
  .else
        ldmcsia S!, {DAT0, DAT1}
  .endif
        ldrmi   DAT2, [S], #4
        stmcsia D!, {DAT0, DAT1}
        strmi   DAT2, [D], #4
        movs    N, N, lsl #2
        ldrcsh  DAT0, [S], #2
        ldrmib  DAT1, [S]
        strcsh  DAT0, [D], #2
        strmib  DAT1, [D]
 .endif
.endm

.macro memcpy_long_inner_loop  backwards, unaligned
110:
 .if backwards
  .if unaligned
        ldr     DAT3, [S, #-4]!
        ldr     DAT7, [S, #-4]!
        ldr     DAT6, [S, #-4]!
        ldr     DAT5, [S, #-4]!
        ldr     DAT4, [S, #-4]!
        ldr     DAT2, [S, #-4]!
        ldr     DAT1, [S, #-4]!
        ldr     DAT0, [S, #-4]!
  .else
        ldmdb   S!, {DAT0, DAT1, DAT2, DAT4, DAT5, DAT6, DAT7, DAT3}
  .endif
 .else
  .if unaligned
        ldr     DAT0, [S], #4
        ldr     DAT1, [S], #4
        ldr     DAT2, [S], #4
        ldr     DAT4, [S], #4
        ldr     DAT5, [S], #4
        ldr     DAT6, [S], #4
        ldr     DAT7, [S], #4
        ldr     DAT3, [S], #4
  .else
        ldmia   S!, {DAT0, DAT1, DAT2, DAT4, DAT5, DAT6, DAT7, DAT3}
  .endif
 .endif
        pld     [S, OFF]
 .if backwards
        stmdb   D!, {DAT5, DAT6, DAT7, DAT3}
        stmdb   D!, {DAT0, DAT1, DAT2, DAT4}
 .else
        stmia   D!, {DAT0, DAT1, DAT2, DAT4}
        stmia   D!, {DAT5, DAT6, DAT7, DAT3}
 .endif
        subs    N, N, #32
        bhs     110b
        /* Just before the final (prefetch_distance+1) 32-byte blocks, deal with final preloads */
        preload_trailing  backwards, S, N, DAT3
        add     N, N, #(prefetch_distance+2)*32 - 16
        pop     {DAT4-DAT7}
        memcpy_medium_inner_loop  backwards, unaligned
.endm

.macro memcpy_medium_inner_loop  backwards, unaligned
120:
 .if backwards
  .if unaligned
        ldr     DAT3, [S, #-4]!
        ldr     DAT2, [S, #-4]!
        ldr     DAT1, [S, #-4]!
        ldr     DAT0, [S, #-4]!
  .else
        ldmdb   S!, {DAT0, DAT1, DAT2, DAT3}
  .endif
        stmdb   D!, {DAT0, DAT1, DAT2, DAT3}
 .else
  .if unaligned
        ldr     DAT0, [S], #4
        ldr     DAT1, [S], #4
        ldr     DAT2, [S], #4
        ldr     DAT3, [S], #4
  .else
        ldmia   S!, {DAT0, DAT1, DAT2, DAT3}
  .endif
        stmia   D!, {DAT0, DAT1, DAT2, DAT3}
 .endif
        subs    N, N, #16
        bhs     120b
        /* Trailing words and bytes */
        tst     N, #15
        beq     199f
        memcpy_trailing_15bytes  backwards, unaligned
199:    pop     {S, DAT1, DAT2, pc}
.endm

.macro memcpy_short_inner_loop  backwards, unaligned
        tst     N, #16
 .if backwards
  .if unaligned
        ldrne   DAT3, [S, #-4]!
        ldrne   DAT2, [S, #-4]!
        ldrne   DAT1, [S, #-4]!
        ldrne   DAT0, [S, #-4]!
  .else
        ldmnedb S!, {DAT0, DAT1, DAT2, DAT3}
  .endif
        stmnedb D!, {DAT0, DAT1, DAT2, DAT3}
 .else
  .if unaligned
        ldrne   DAT0, [S], #4
        ldrne   DAT1, [S], #4
        ldrne   DAT2, [S], #4
        ldrne   DAT3, [S], #4
  .else
        ldmneia S!, {DAT0, DAT1, DAT2, DAT3}
  .endif
        stmneia D!, {DAT0, DAT1, DAT2, DAT3}
 .endif
        memcpy_trailing_15bytes  backwards, unaligned
199:    pop     {S, DAT1, DAT2, pc}
.endm

.macro memcpy backwards
        D       .req    a1
        S       .req    a2
        N       .req    a3
        DAT0    .req    a4
        DAT1    .req    v1
        DAT2    .req    v2
        DAT4    .req    v3
        DAT5    .req    v4
        DAT6    .req    v5
        DAT7    .req    v6
        DAT3    .req    ip
        OFF     .req    lr

        push    {S, DAT1, DAT2, lr}

 .if backwards
        add     D, D, N
        add     S, S, N
 .endif

        /* See if we're guaranteed to have at least one 16-byte aligned 16-byte write */
        cmp     N, #31
        blo     170f
        /* To preload ahead as we go, we need at least (prefetch_distance+2) 32-byte blocks */
        cmp     N, #(prefetch_distance+3)*32 - 1
        blo     160f

        /* Long case */
        push    {DAT4-DAT7}
        /* Adjust N so that the decrement instruction can also test for
         * inner loop termination. We want it to stop when there are
         * (prefetch_distance+1) complete blocks to go. */
        sub     N, N, #(prefetch_distance+2)*32
        preload_leading_step1  backwards, DAT0, S
 .if backwards
        /* Bug in GAS: it accepts, but mis-assembles the instruction
         * ands    DAT2, D, #60, 2
         * which sets DAT2 to the number of leading bytes until destination is aligned and also clears C (sets borrow)
         */
        .word   0xE210513C
        beq     154f
 .else
        tst     D, #15
        beq     154f
        rsb     DAT2, D, #0
        and     DAT2, DAT2, #15 /* number of leading bytes until destination aligned */
 .endif
        preload_leading_step2  backwards, DAT0, S, DAT2, DAT3
        memcpy_leading_15bytes backwards
154:    /* Destination now 16-byte aligned; we have at least one prefetch as well as at least one 16-byte output block */
        /* Prefetch offset is best selected such that it lies in the first 8 of each 32 bytes - but it's just as easy to aim for the first one */
 .if backwards
        rsb     OFF, S, #0
        and     OFF, OFF, #31
        sub     OFF, OFF, #32*(prefetch_distance+1)
 .else
        and     OFF, S, #31
        rsb     OFF, OFF, #32*prefetch_distance
 .endif
        tst     S, #3
        bne     140f
        memcpy_long_inner_loop  backwards, 0
140:    memcpy_long_inner_loop  backwards, 1

160:    /* Medium case */
        preload_all  backwards, 0, 0, S, N, DAT2, DAT3
        sub     N, N, #16     /* simplifies inner loop termination */
 .if backwards
        ands    DAT2, D, #15
        beq     164f
 .else
        tst     D, #15
        beq     164f
        rsb     DAT2, D, #0
 .endif
        memcpy_leading_15bytes backwards
164:    /* Destination now 16-byte aligned; we have at least one 16-byte output block */
        tst     S, #3
        bne     140f
        memcpy_medium_inner_loop  backwards, 0
140:    memcpy_medium_inner_loop  backwards, 1

170:    /* Short case, less than 31 bytes, so no guarantee of at least one 16-byte block */
        teq     N, #0
        beq     199f
        preload_all  backwards, 1, 0, S, N, DAT2, DAT3
        tst     D, #3
        beq     174f
172:    subs    N, N, #1
        blo     199f
 .if backwards
        ldrb    DAT0, [S, #-1]!
        strb    DAT0, [D, #-1]!
 .else
        ldrb    DAT0, [S], #1
        strb    DAT0, [D], #1
 .endif
        tst     D, #3
        bne     172b
174:    /* Destination now 4-byte aligned; we have 0 or more output bytes to go */
        tst     S, #3
        bne     140f
        memcpy_short_inner_loop  backwards, 0
140:    memcpy_short_inner_loop  backwards, 1

        .unreq  D
        .unreq  S
        .unreq  N
        .unreq  DAT0
        .unreq  DAT1
        .unreq  DAT2
        .unreq  DAT4
        .unreq  DAT5
        .unreq  DAT6
        .unreq  DAT7
        .unreq  DAT3
.endm
