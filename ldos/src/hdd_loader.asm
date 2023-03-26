;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Hard Disk Drive boot loader
;
;---------------------------------------------------------


		macro	ADF_DISK_NAME
			dc.b	"cycle-op.adf"
		endm

_LVOOpenLib			=	-552
_LVOCloseLib		=	-414
_LVOOpenFile		=	-30
_LVOCloseFile		=	-36
_LVOReadFile		=	-42
_LVOWriteFile		=	-48

DISK1_SIZE			=	880*1024



		include "kernelPrivate.inc"

		
		code
	
start:

			move.l	a7,pOriginalStack

			lea		-m_sizeOf(a7),a7

			move.l	$4.w,a6
			lea		dosLibName(pc),a1
			moveq	#36,d0		; check OS2.0++ 
			jsr		_LVOOpenLib(a6)
			move.l	d0,dosHandle
			sne		isOS2
			bne.s	.dosOk

		; open DOS library
			move.l	$4.w,a6
			lea		dosLibName(pc),a1
			moveq	#0,d0
			jsr		_LVOOpenLib(a6)
			move.l	d0,dosHandle
			beq		exitProg
.dosOk:
		; open console
			pea	consoleName(pc)
			move.l	(a7)+,d1
			move.l	#1005,d2
			move.l	dosHandle(pc),a6
			jsr	_LVOOpenFile(a6)
			move.l	d0,conHandle
			beq		exitProg

		; Load ADF disk
			lea		floppy1Name(pc),a0
			move.l	#DISK1_SIZE,d0
			lea		diskBuffer,a1
			move.l	a1,m_hddBuffer1(a7)
			bsr		loadFile

			clr.l	m_hddBuffer2(a7)

		; set the CHIP & ANY buffers addr
			move.l	#chipBuffer,m_chipStart(a7)
			move.l	#anyBuffer,m_fakeStart(a7)

		; search the NOP to jump in the code
			move.l	m_hddBuffer1(a7),a1
			movea.l	a1,a2
			lea		512(a2),a3
.search:	cmpi.w	#$4e71,(a2)+
			beq.s	.found
			cmpa.l	a2,a3
			bne.s	.search
			bra		exitProg		; ERROR: NOP not found in bootsector, probably means it's not LDOS ADF file

.found:		move.l	m_chipStart(a7),a0
			add.l	#(512-64)*1024,a0
			jmp		(a2)				; jump in the bootsector code

		
; a0: file name
; a1: buffer
; d0: bytes to load
loadFile:
			move.l	d0,fsize
			move.l	a1,pBuffer

			move.l	a0,d1
			tst.b	isOS2
			bne.s	.os2
			addq.l	#8,d1
.os2:		move.l	#1005,d2		; Old file.
			move.l	dosHandle,a6
			jsr		_LVOOpenFile(a6)
			tst.l	d0
			beq		readError
			move.l	d0,fileH

			move.l	fileH(pc),d1			; file handle
			move.l	pBuffer(pc),d2			; Buffer Ad.
			move.l	fsize(pc),d3			; read size
			move.l	dosHandle(pc),a6
			jsr		_LVOReadFile(a6)
			tst.l	d0
			beq		readError

			move.l	fileH(pc),d1
			move.l	dosHandle(pc),a6
			jsr		_LVOCloseFile(a6)

			rts

			
exitProg:

		; close console
			move.l	conHandle(pc),d1
			beq.s	.nocon
			move.l	dosHandle(pc),a6
			jsr		_LVOCloseFile(a6)

		; close DOS library
.nocon:		move.l	dosHandle(pc),a1
			move.l	$4.w,a6
			jsr		_LVOCloseLib(a6)

		; exit
			move.l	pOriginalStack(pc),a7
			moveq	#0,d0
			rts
			
waitKey:	lea		txtPressReturn(pc),a0
			bsr		gemdos9
			bsr		gemdos7
			rts

readError:
			lea		txtReadError(pc),a0
			bsr		gemdos9
			bsr		waitKey
			bra		exitProg

; Gemdos9 is "print" on ATARI :)
gemdos9:	move.l	a0,d2			; String AD
			moveq	#0,d3
.loop:		tst.b	(a0)+			; Calc string Lenght
			beq.s	.fin
			addq.w	#1,d3
			bra.s	.loop
.fin:		move.l	conHandle,d1		; Handle display.
			move.l	dosHandle,a6
			jsr		_LVOWriteFile(a6)
			rts	

gemdos7:	move.l	conHandle,d1
			move.l	#buffer,d2
			moveq	#1,d3
			move.l	dosHandle,a6
			jsr		_LVOReadFile(a6)
			rts
			
conHandle:		dc.l	0
dosHandle:		dc.l	0
dosLibName:		dc.b	'dos.library',0
consoleName:	dc.b	'CON:0/224/480/24/LDOS HDD Loader...',0
floppy1Name:	dc.b	"PROGDIR:"
				ADF_DISK_NAME
				dc.b	0
txtReadError:	dc.b	'Unable to load the ADF file',10,0
txtPressReturn:	dc.b	10,'Press RETURN key',0
isOS2:			dc.b	0
				even

pOriginalStack:	ds.l	1	
fsize:			ds.l	1			
fileH:			ds.l	1
pBuffer:		ds.l	1
buffer			ds.b	8

	bss disk_buffer

diskBuffer:		ds.b	DISK1_SIZE

	bss any_ram

anyBuffer:		ds.b	512*1024

	bss_c chip_ram

chipBuffer:		ds.b	512*1024
