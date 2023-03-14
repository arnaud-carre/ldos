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
;	dc.b	'0123456789abcdef'
	dc.b	'LDOS v1.40 Amiga'
	dc.b	'-Leonard/OXYGENE'
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
		move.l	a0,m_buffer(a7)

		move.l	4.w,a6
		move.l	m_originalA1(a7),a1
		move.w	#2,$1c(a1)		; read cmd
		move.l	a0,$28(a1)		; load ad
		move.l	#$00004afc,$24(a1)		; size to load in bytes (4afc is patched by the installer)
		clr.l	$2c(a1)  		; start offset
		jsr		-456(a6)		; run IO command

		move.l	m_buffer(a7),a1
		lea		31*1024(a1),a0

		clr.l	m_hddBuffer1(a7)

	; WARNING: do NOT remove this NOP. hdd_loader.exe jump here at the NOP place
	nop
	
	lea		(kernelStart-bootStart)(a1),a1
	pea		(a0)
	
; ------------------------------------------
; packed data in a1
; dest in a0
decode:
		move.w	(a1)+,d0				; original size
		include "arj_m4.asm"

kernelStart:
