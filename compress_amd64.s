//+build !noasm !appengine

//
// Copyright 2016 Frank Wessels <fwessels@xs4all.nl>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// func compressSSE(compressSSE(p []uint8, in, iv, t, f, shffle, out []uint64)
TEXT ·compressSSE(SB), 7, $0

    // Load digest
    MOVQ   in+24(FP),  SI     // SI: &in
    MOVOU   0(SI), X0         // X0 = in[0]+in[1]      /* row1l = LOAD( &S->h[0] ); */
    MOVOU  16(SI), X1         // X1 = in[2]+in[3]      /* row1h = LOAD( &S->h[2] ); */
    MOVOU  32(SI), X2         // X2 = in[4]+in[5]      /* row2l = LOAD( &S->h[4] ); */
    MOVOU  48(SI), X3         // X3 = in[6]+in[7]      /* row2h = LOAD( &S->h[6] ); */

    // Load initialization vector
    MOVQ iv+48(FP), DX        // DX: &iv
    MOVOU   0(DX), X4         // X4 = iv[0]+iv[1]      /* row3l = LOAD( &blake2b_IV[0] ); */
    MOVOU  16(DX), X5         // X5 = iv[2]+iv[3]      /* row3h = LOAD( &blake2b_IV[2] ); */
    MOVOU  32(DX), X6         // X6 = iv[4]+iv[5]      /*                        LOAD( &blake2b_IV[4] )                      */
    MOVQ t+72(FP), SI         // SI: &t
    MOVOU   0(SI), X7         // X7 = t[0]+t[1]        /*                                                LOAD( &S->t[0] )    */
    PXOR       X7, X6         // X6 = X6 ^ X7          /* row4l = _mm_xor_si128(                       ,                  ); */
    MOVOU  48(DX), X7         // X7 = iv[6]+iv[7]      /*                        LOAD( &blake2b_IV[6] )                      */
    MOVQ t+96(FP), SI         // SI: &f
    MOVOU   0(SI), X8         // X8 = f[0]+f[0]        /* row4h = _mm_xor_si128(                         LOAD( &S->f[0] )    */
    PXOR       X8, X7         // X7 = X7 ^ X8          /* row4h = _mm_xor_si128(                       ,                  ); */

    ///////////////////////////////////////////////////////////////////////////
    // R O U N D   1
    ///////////////////////////////////////////////////////////////////////////

    // LOAD_MSG_ ##r ##_1(b0, b1);
    //   (X12 used as additional temp register)
    MOVQ   message+0(FP), DX  // DX: &p (message)
    MOVOU   0(DX), X12        // X12 = m[0]+m[1]
    MOVOU  16(DX), X13        // X13 = m[2]+m[3]
    MOVOU  32(DX), X14        // X14 = m[4]+m[5]
    MOVOU  48(DX), X15        // X15 = m[6]+m[7]
    BYTE $0xc4; BYTE $0x41; BYTE $0x19; BYTE $0x6c; BYTE $0xc5   // VPUNPCKLQDQ  XMM8, XMM12, XMM13  /* m[0], m[2] */

    // Load shuffle value
    MOVQ   shffle+120(FP), SI // SI: &shuffle
    MOVOU  0(SI), X12         // X12 = 03040506 07000102 0b0c0d0e 0f08090a

    // G1(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h,b0,b1);
    BYTE $0xc4; BYTE $0xc1; BYTE $0x79; BYTE $0xd4; BYTE $0xc0   // VPADDQ  XMM0,XMM0,XMM8   /* v0 += m[0], v1 += m[2] */
    BYTE $0xc5; BYTE $0xf9; BYTE $0xd4; BYTE $0xc2               // VPADDQ  XMM0,XMM0,XMM2   /* v0 += v4, v1 += v5 */
    BYTE $0xc5; BYTE $0xc9; BYTE $0xef; BYTE $0xf0               // VPXOR   XMM6,XMM6,XMM0   /* v12 ^= v0, v13 ^= v1 */
    BYTE $0xc5; BYTE $0xf9; BYTE $0x70; BYTE $0xf6; BYTE $0xb1   // VPSHUFD XMM6,XMM6,0xb1   /* v12 = v12<<(64-32) | v12>>32, v13 = v13<<(64-32) | v13>>32 */
    BYTE $0xc5; BYTE $0xd9; BYTE $0xd4; BYTE $0xe6               // VPADDQ  XMM4,XMM4,XMM6   /* v8 += v12, v9 += v13  */
    BYTE $0xc5; BYTE $0xe9; BYTE $0xef; BYTE $0xd4               // VPXOR   XMM2,XMM2,XMM4   /* v4 ^= v8, v5 ^= v9 */
    BYTE $0xc4; BYTE $0xc2; BYTE $0x69; BYTE $0x00; BYTE $0xd4   // VPSHUFB XMM2,XMM2,XMM12  /* v4 = v4<<(64-24) | v4>>24, v5 = v5<<(64-24) | v5>>24 */

    // Reload digest
    MOVQ   in+24(FP),  SI     // SI: &in
    MOVOU   0(SI), X12        // X12 = in[0]+in[1]      /* row1l = LOAD( &S->h[0] ); */
    MOVOU  16(SI), X13        // X13 = in[2]+in[3]      /* row1h = LOAD( &S->h[2] ); */
    MOVOU  32(SI), X14        // X14 = in[4]+in[5]      /* row2l = LOAD( &S->h[4] ); */
    MOVOU  48(SI), X15        // X15 = in[6]+in[7]      /* row2h = LOAD( &S->h[6] ); */

    // Final computations and prepare for storing
    PXOR   X4,  X0           // X0 = X0 ^ X4          /* row1l = _mm_xor_si128( row3l, row1l ); */
    PXOR   X5,  X1           // X1 = X1 ^ X5          /* row1h = _mm_xor_si128( row3h, row1h ); */
    PXOR   X12, X0           // X0 = X0 ^ X12         /*  STORE( &S->h[0], _mm_xor_si128( LOAD( &S->h[0] ), row1l ) ); */
    PXOR   X13, X1           // X1 = X1 ^ X13         /*  STORE( &S->h[2], _mm_xor_si128( LOAD( &S->h[2] ), row1h ) ); */
    PXOR   X6,  X2           // X2 = X2 ^ X6          /*  row2l = _mm_xor_si128( row4l, row2l ); */
    PXOR   X7,  X3           // X3 = X3 ^ X7          /*  row2h = _mm_xor_si128( row4h, row2h ); */
    PXOR   X14, X2           // X2 = X2 ^ X14         /*  STORE( &S->h[4], _mm_xor_si128( LOAD( &S->h[4] ), row2l ) ); */
    PXOR   X15, X3           // X3 = X3 ^ X15         /*  STORE( &S->h[6], _mm_xor_si128( LOAD( &S->h[6] ), row2h ) ); */

    // Store digest
    MOVQ  out+144(FP), DX     // DX: &out
    MOVOU  X0,  0(DX)         // out[0]+out[1] = X0
    MOVOU  X1, 16(DX)         // out[2]+out[3] = X1
    MOVOU  X2, 32(DX)         // out[4]+out[5] = X2
    MOVOU  X3, 48(DX)         // out[6]+out[7] = X3

    RET