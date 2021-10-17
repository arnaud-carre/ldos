;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Boot sector
;
;---------------------------------------------------------

MEMF_CHIP   	=	(1<<1)	; Chip memory
MEMF_FAST		=	(1<<2)	; Fast memory
MEMF_LARGEST	=	(1<<17)	; AvailMem: return the largest chunk size
_LVOAvailMem	=	-216	
_LVOAllocMem	=	-198	



		include "kernelPrivate.inc"


bootStart:
	dc.b 'DOS',0
	dc.l 0				; 4		; checksum, patched by installer
	dc.l 880			; 8
	bra.s	start0		; 12
	dc.b	'  '
	dc.b	'-LDOS v1.2 by Le'
	dc.b	'onard/OXYGENE-  '
	even
	
start0:
		lea		-m_sizeOf(a7),a7
		move.l	a1,m_originalA1(a7)

		move.l	#(MEMF_LARGEST|MEMF_CHIP),d1
		jsr		_LVOAvailMem(a6)
		move.l	d0,m_chipSize(a7)
		moveq	#MEMF_CHIP,d1
		jsr		_LVOAllocMem(a6)
		move.l	d0,m_chipStart(a7)

		move.l	#(MEMF_LARGEST|MEMF_FAST),d1
		jsr		_LVOAvailMem(a6)
		move.l	d0,m_fakeSize(a7)
		beq.s	.noFast
		moveq	#MEMF_FAST,d1
		jsr		_LVOAllocMem(a6)
		move.l	d0,m_fakeStart(a7)
.noFast:

		move.l	m_chipStart(a7),a0
		add.l	m_chipSize(a7),a0
		sub.l	#64*1024,a0
		move.l	a0,m_buffer(a7)

		move.l	4.w,a6
		move.l	m_originalA1(a7),a1
		move.w	#2,$1c(a1)		; read cmd
		move.l	a0,$28(a1)		; load ad
		move.w	#$4afc,d0		; sector count (4afc is patched by the installer)
		mulu.w	#512,d0
		move.l	d0,$24(a1)		; size in bytes
		clr.l	$2c(a1)  		; start offset
		jsr		-456(a6)		; run IO command

		move.l	m_buffer(a7),a0
		lea		24*1024(a0),a1

		clr.l	m_hddBuffer1(a7)

	; WARNING: do NOT remove this NOP. hdd_loader.exe jump here at the NOP place
	nop
	
	lea		(kernelStart-bootStart)(a0),a0
	pea		(a1)
	
	bsr.s	decode
	move.w	#$4afc,d6		; disk offset		(4AFC is patched by installer)
	move.w	#$4afc,d7		; FAT size			(4AFC is patched by installer)
	rts
; ------------------------------------------
; packed data in a0
; dest in a1
decode:
		move.l	(a0)+,d0				; original size
		exg		a0,a1
		include "arj_m4.asm"

kernelStart:
