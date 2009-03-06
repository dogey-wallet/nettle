C nettle, low-level cryptographics library
C 
C Copyright (C) 2001, 2002, 2005, 2008 Rafael R. Sevilla, Niels M�ller
C  
C The nettle library is free software; you can redistribute it and/or modify
C it under the terms of the GNU Lesser General Public License as published by
C the Free Software Foundation; either version 2.1 of the License, or (at your
C option) any later version.
C 
C The nettle library is distributed in the hope that it will be useful, but
C WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
C or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
C License for more details.
C 
C You should have received a copy of the GNU Lesser General Public License
C along with the nettle library; see the file COPYING.LIB.  If not, write to
C the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
C MA 02111-1307, USA.

include_src(<x86_64/aes.m4>)

C Register usage:

C AES state, use two of them
define(<SA>,<%eax>)
define(<SB>,<%ebx>)
define(<SC>,<%ecx>)
define(<SD>,<%edx>)

define(<TA>,<%r10d>)
define(<TB>,<%r11d>)
define(<TC>,<%r12d>)

define(<CTX>,	<%rdi>)
define(<TABLE>,	<%rsi>)
define(<PARAM_LENGTH>,<%edx>)		C Length is only 32 bits
define(<PARAM_DST>,	<%rcx>)
define(<SRC>,	<%r8>)

define(<DST>, <%r9>) 
define(<KEY>,<%r14>)
define(<COUNT>,	<%r15d>)
define(<BLOCK_COUNT>, <%r13d>)

define(<TMP>,<%rbp>)

	.file "aes-decrypt-internal.asm"
	
	C _aes_decrypt(struct aes_context *ctx, 
	C	       const struct aes_table *T,
	C	       unsigned length, uint8_t *dst,
	C	       uint8_t *src)
	.text
	ALIGN(4)
PROLOGUE(_nettle_aes_decrypt)
	test	PARAM_LENGTH, PARAM_LENGTH
	jz	.Lend

        C save all registers that need to be saved
	push	%rbx
	push	%rbp
	push	%r12
	push	%r13
	push	%r14
	push	%r15	

	mov	PARAM_DST, DST
	movl	PARAM_LENGTH, BLOCK_COUNT
	shrl	$4, BLOCK_COUNT
.Lblock_loop:
	mov	CTX,KEY
	
	AES_LOAD(SA, SB, SC, SD, SRC, KEY)
	add	$16, SRC	C Increment src pointer

	C  get number of rounds to do from ctx struct	
	movl	AES_NROUNDS (CTX), COUNT
	shrl	$1, COUNT
	subl	$1, COUNT

	add	$16,KEY		C  point to next key
	ALIGN(4)
.Lround_loop:
	AES_ROUND(TABLE, SA,SD,SC,SB, TA, TMP)
	xorl	(KEY), TA

	AES_ROUND(TABLE, SB,SA,SD,SC, TB, TMP)
	xorl	4(KEY),TB

	AES_ROUND(TABLE, SC,SB,SA,SD, TC, TMP)
	xorl	8(KEY),TC

	AES_ROUND(TABLE, SD,SC,SB,SA, SD, TMP)
	xorl	12(KEY),SD

	AES_ROUND(TABLE, TA,SD,TC,TB, SA, TMP)
	xorl	16(KEY), SA

	AES_ROUND(TABLE, TB,TA,SD,TC, SB, TMP)
	xorl	20(KEY),SB

	AES_ROUND(TABLE, TC,TB,TA,SD, SC, TMP)
	xorl	24(KEY),SC

	AES_ROUND(TABLE, SD,TC,TB,TA, SD, TMP)
	xorl	28(KEY),SD
	
	add	$32,KEY	C  point to next key
	decl	COUNT
	jnz	.Lround_loop

	C last two rounds

	AES_ROUND(TABLE, SA,SD,SC,SB, TA, TMP)
	xorl	(KEY), TA

	AES_ROUND(TABLE, SB,SA,SD,SC, TB, TMP)
	xorl	4(KEY),TB

	AES_ROUND(TABLE, SC,SB,SA,SD, TC, TMP)
	xorl	8(KEY),TC

	AES_ROUND(TABLE, SD,SC,SB,SA, SD, TMP)
	xorl	12(KEY),SD

	AES_FINAL_ROUND(TA,SD,TC,TB, TABLE, SA, TMP)
	AES_FINAL_ROUND(TB,TA,SD,TC, TABLE, SB, TMP)
	AES_FINAL_ROUND(TC,TB,TA,SD, TABLE, SC, TMP)
	AES_FINAL_ROUND(SD,TC,TB,TA, TABLE, SD, TMP)

	C Inverse S-box substitution
	mov	$3, COUNT
.Lsubst:
	AES_SUBST_BYTE(SA,SB,SC,SD, TABLE, TMP)

	decl	COUNT
	jnz	.Lsubst

	C Add last subkey, and store decrypted data
	AES_STORE(SA,SB,SC,SD, KEY, DST)
	
	add	$16, DST
	decl	BLOCK_COUNT

	jnz	.Lblock_loop

	pop	%r15	
	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbp
	pop	%rbx
.Lend:
	ret
EPILOGUE(_nettle_aes_decrypt)
