;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	debug_screen
;
;---------------------------------------------------------

High		=		256
Width		=		320

DiwStartyv	=		172-High/2
DiwStartxv	=		289-Width/2
DiwStopyv	=		High/2-84
DiwStopxv	=		33+Width/2
DdfStartv	=		(DiwStartxv-17)/2
DdfStopv	=		DdfStartv+(Width/16-1)*8


debugScreenCrcStart:



; input: a0: text to display
;		 a1: buffer for args ( %w or %l )
debugScreenPrint:
		move.l	dbgBss(pc),a6
		
charLoop:
		moveq	#0,d0
		move.b	(a0)+,d0
		beq		.ret		
		cmpi.b	#'%',d0
		beq		.integer
		cmpi.b	#10,d0
		beq		.carriage

		bsr		outputChar
		
		bra.s	charLoop
		
		
		
		
		
		
.ret:
		
		rts

.carriage:
			clr.w	dbg_printX(a6)
			addi.l	#40*8,dbg_pScreen(a6)
			bra		charLoop

.integer:	moveq	#4-1,d2
			move.w	(a1)+,d1		; pop 16bits
			swap	d1
			cmpi.b	#'w',(a0)+
			beq.s	.cLoop
			move.w	(a1)+,d1		; fetch 32bits
			moveq	#8-1,d2

.cLoop:		rol.l	#4,d1
			moveq	#15,d0
			and.w	d1,d0
			move.b	.hexa(pc,d0.w),d0

			bsr.s	outputChar
			
			dbf		d2,.cLoop
			bra		charLoop
.hexa:		dc.b	'0123456789abcdef'

outputChar:
			move.l	dbg_pScreen(a6),a3
			add.w	dbg_printX(a6),a3
			subi.b	#' ',d0
			lsl.w	#3,d0
			lea		fnt88(pc),a2
			add.w	d0,a2
			move.b	(a2)+,(a3)
			move.b	(a2)+,40*1(a3)
			move.b	(a2)+,40*2(a3)
			move.b	(a2)+,40*3(a3)
			move.b	(a2)+,40*4(a3)
			move.b	(a2)+,40*5(a3)
			move.b	(a2)+,40*6(a3)
			move.b	(a2)+,40*7(a3)
			addq.w	#1,dbg_printX(a6)
			rts
		

debugScreenSetup:

		move.l	dbgScreenAd(pc),a0
		move.w	#DEBUG_SCREEN_SIZE/4-1,d0
.cls:	clr.l	(a0)+
		dbf		d0,.cls

		move.l	dbgScreenAd(pc),d0
		lea		copS(pc),a0
		move.w	dbgScreenAd(pc),2(a0)
		move.w	dbgScreenAd+2(pc),6(a0)
		
		lea		debugScreenCopperList(pc),a0
		bsr		installCopperList
		bsr		clearSprites

		move.w	#$8000|(1<<9)|(1<<8)|(1<<7),$dff096			; bitplan + copper
		move.w	d0,$dff088

		move.l	dbgBss(pc),a6
		clr.w	dbg_printX(a6)
		move.l	dbgScreenAd(pc),dbg_pScreen(a6)
	
		rts

debugScreenShutdown:
		rts

		
dbgScreenAd:		dc.l	$78000
dbgBss:				dc.l	$78000-128
			
memoryStateDebug:

			movem.l	d0-a6,-(a7)

			bsr		debugScreenSetup
			lea		.txt(pc),a0
			bsr		debugScreenPrint
			
			move.l	dbgScreenAd(pc),a1
			lea		40*16(a1),a1
			lea		18(a1),a2
			move.l	#-1,(a1)+
			move.l	#-1,(a1)+
			move.l	#-1,(a1)+
			move.l	#-1,(a1)+

			move.l	#-1,(a2)+
			move.l	#-1,(a2)+
			move.l	#-1,(a2)+
			move.l	#-1,(a2)+

			lea		dbgLine(pc),a0
			move.w	(a0),d0
			addq.w	#1,(a0)
			addi.w	#24,d0
			mulu.w	#40,d0
			move.l	dbgScreenAd(pc),a2
			add.w	d0,a2
			lea		18(a2),a3

			lea		chipMemTable+4(pc),a0
			lea		fastMemTable+4(pc),a1
			moveq	#7,d1
			move.w	#128-1,d0
.dloop:		tst.b	(a0)+
			beq.s	.no1
			bset	d1,(a2)
.no1:		tst.b	(a1)+
			beq.s	.no2
			bset	d1,(a3)
.no2:		dbf		d1,.cont
			moveq	#7,d1
			addq.w	#1,a2
			addq.w	#1,a3
.cont:		dbf		d0,.dloop


.wait0:		btst 	#6,$bfe001  ; test LEFT mouse click
			bne.s	.wait0
.wait1:		btst 	#6,$bfe001  ; test LEFT mouse click
			beq.s	.wait1
			
			bsr		debugScreenShutdown

			movem.l	(a7)+,d0-a6

			rts
			
		
.txt:		dc.b	'LDOS Kernel Memory Report',10,0
			even
		
		
debugScreenCopperList:

		dc.w	$0100,$200+(1<<12)			; 1 bitplan
		dc.w	$0102,$0
		dc.w	$0108,$0
		dc.w	$010a,$0
		dc.w	$008e,(DiwStartyv<<8)+DiwStartxv
		dc.w	$0090,(DiwStopyv<<8)+DiwStopxv
		dc.w	$0092,DdfStartv
		dc.w	$0094,DdfStopv
		dc.w	$01fc,$0
copS:	dc.w	$00e0,0
		dc.w	$00e2,0
		dc.w	$0180,$000
		dc.w	$0182,$fc0
		dc.l	-2
		
fnt88:	incbin	"font88.bin"
		even
		
debugScreenCrcEnd:

dbgLine:		dc.w	0


	rsreset
	
dbg_printX:		rs.w	1
dbg_pScreen:	rs.l	1
dbg_iVector:	rs.l	1
dbg_SizeOf:		rs.w	1



