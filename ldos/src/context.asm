;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Amiga context save & restore
;
;---------------------------------------------------------

kVectorHighAddr	=	$100

kickstartContextSave:

			lea		m_ctxBuffer(pc),a5

			lea		.getSsp(pc),a0
			bsr		superCall


			lea		sCtxGfxLib(pc),a1
			moveq	#0,d0
			move.l	$4.w,a6
			jsr		-552(a6)			; open library
			move.l	d0,m_ctxGfxBase(a5)
			beq		.error

			move.l	d0,a6
			move.l	34(a6),m_ctxOldView(a5)
;			sub.l	a1,a1
;			bsr		ctxDoView
			move.l	$26(a6),m_ctxOldCop1(a5)
			move.l	$32(a6),m_ctxOldCop2(a5)

			moveq	#0,d0				; default VBR
			btst	#0,296+1(a6)		; 68010+?
			beq.s	.is68k
			lea		.getVbrSuperv(pc),a0
			bsr		superCall
.is68k:		move.l	d0,m_ctxOldVBR(a5)

			lea		$dff000,a6
			move.w	$10(a6),m_ctxADK(a5)
			move.w	$1C(a6),m_ctxINTENA(a5)
			move.w	$02(a6),m_ctxDMA(a5)

			lea		m_ctxVectors(a5),a1
			lea		$4.w,a0
			moveq	#(kVectorHighAddr-$4)/4-1,d0
.copy1:		move.l	(a0)+,(a1)+
			dbf		d0,.copy1

			rts

.getSsp:	move.l	a7,m_ctxSsp(a5)
			rte

.getVbrSuperv:
			mc68020
			movec   vbr,d0
			mc68000
			rte				; back to user state code

.error:		moveq	#0,d0
			rts

kickstartContextRestore:
			lea		m_ctxBuffer(pc),a5
			lea		$dff000,a6
						
			move.w	#$8000,d0
			or.w	d0,m_ctxINTENA(a5)
			or.w	d0,m_ctxDMA(a5)
			or.w	d0,m_ctxADK(a5)

.waitVbl:	move.l	$04(a6),d1
			and.l	#$1ff00,d1
			cmp.l	#303<<8,d1
			bne.s	.waitVbl

			move.w	#$7fff,d0
			move.w	d0,$9a(a6)			; Clear all INT bits
			move.w	d0,$96(a6)			; Clear all DMA channels
			move.w	d0,$9c(a6)			; Clear all INT requests

			move.l	m_ctxOldVBR(a5),d0
			beq.s	.vbrOk
			lea		.setVbrSuperv(pc),a0
			bsr		superCall
.vbrOk:
			lea		.setSsp(pc),a0
			bsr		superCall

			lea		m_ctxVectors(a5),a0
			lea		$4.w,a1
			moveq	#(kVectorHighAddr-$4)/4-1,d0
.copy2:		move.l	(a0)+,(a1)+
			dbf		d0,.copy2

			move.l	m_ctxOldCop1(a5),$80(a6)
			move.l	m_ctxOldCop2(a5),$84(a6)
			move.w	d0,$88(a6)

			move.w	m_ctxINTENA(a5),$9a(a6)
			move.w	m_ctxDMA(a5),$96(a6)
			move.w	m_ctxADK(a5),$9e(a6)

			move.l	m_ctxGfxBase(a5),a6
			move.l	m_ctxOldView(a5),a1			; restore old viewport
			bsr.s	ctxDoView

			move.l	a6,a1
			move.l	$4.w,a6
			jsr		-414(a6)			; Closelibrary()

			rts

.setSsp:	movem.l	(a7),d0-d1		; sr, back addr and int status just in case
			move.l	(m_ctxBuffer+m_ctxSsp)(pc),a7	; restore ssp
			movem.l	d0-d1,(a7)		; but keep same return addr
			rte

.setVbrSuperv:
			mc68020
			movec   d0,vbr
			mc68000
			rte

ctxDoView:	jsr		-222(a6)			; LoadView()
			jsr		-270(a6)			; WaitTOF()
			jsr		-270(a6)
			rts

superCall:	move.l	$80.w,-(a7)
			move.l	a0,$80.w
			trap	#0
			move.l	(a7)+,$80.w
			rts

sCtxGfxLib:			dc.b	'graphics.library',0
					even

			rsreset

m_ctxGfxBase:		rs.l	1
m_ctxSsp:			rs.l	1
m_ctxOldView:		rs.l	1
m_ctxOldCop1:		rs.l	1
m_ctxOldCop2:		rs.l	1
m_ctxOldVBR:		rs.l	1
m_ctxVectors:		rs.b	(kVectorHighAddr-$4)
m_ctxINTENA:		rs.w	1
m_ctxDMA:			rs.w	1
m_ctxADK:			rs.w	1

m_ctxSizeof:		rs.w	0
m_ctxBuffer:		ds.b	m_ctxSizeof
