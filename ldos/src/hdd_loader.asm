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


_LVOAvailMem		=	-216	
_LVOAllocMem		=	-198	
_LVOOpenLib			=	-552
_LVOCloseLib		=	-414

_LVOOpenFile		=	-30
_LVOCloseFile		=	-36
_LVOReadFile		=	-42
_LVOWriteFile		=	-48

MEMF_CHIP   	=	(1<<1)	; Chip memory
MEMF_FAST		=	(1<<2)	; Fast memory
MEMF_LARGEST	=	(1<<17)	; AvailMem: return the largest chunk size

DISK1_SIZE			=	880*1024
DISK2_SIZE			=	880*1024


		include "kernelPrivate.inc"

		
	;	code
	
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

		; alloc and load first ADF disk
			lea	floppy1Name(pc),a0
			move.l	#DISK1_SIZE,d0
			bsr	loadFile
			move.l	a0,m_hddBuffer1(a7)

		; alloc and load second ADF disk
			clr.l	m_hddBuffer2(a7)
;			lea	floppy2Name(pc),a0
;			move.l	#DISK2_SIZE,d0
;			bsr	loadFile
;			move.l	a0,m_hddBuffer2(a7)

		; finally alloc max block of FAST and CHIP mem
			move.l	$4.w,a6
			move.l	#(512*1024),d0
			move.l	#MEMF_CHIP,d1
			jsr		_LVOAllocMem(a6)
			tst.l	d0
			beq		mallocError
			move.l	d0,m_chipStart(a7)

			move.l	#(512*1024),d0
			moveq	#0,d1							; MEMF_ANY
			jsr		_LVOAllocMem(a6)
			tst.l	d0
			beq		mallocError
			move.l	d0,m_fakeStart(a7)

		; search the NOP to jump in the code
			move.l	m_hddBuffer1(a7),a0
			movea.l	a0,a2
.search:	cmpi.w	#$4e71,(a2)+
			bne.s	.search

			move.l	m_chipStart(a7),a1
			add.l	#(512-64)*1024,a1
			jmp		(a2)				; jump in the bootsector code

		
; a0: file name
; d0: bytes to load
; returns: a0: load buffer ad (0 if ERROR)	
loadFile:
			move.l	d0,fsize

			move.l	a0,d1
			tst.b	isOS2
			bne.s	.os2
			addq.l	#8,d1
.os2:		move.l	#1005,d2		; Old file.
			move.l	dosHandle,a6
			jsr		_LVOOpenFile(a6)
			tst.l	d0
			beq	fileNotFound
			move.l	d0,fileH

			move.l	$4.w,a6
			move.l	fsize,d0			; size to read
			moveq	#0,d1
			jsr		_LVOAllocMem(a6)
			tst.l	d0
			beq		mallocError
			move.l	d0,pBuffer

			move.l	fileH,d1			; file handle
			move.l	pBuffer,d2			; Buffer Ad.
			move.l	fsize,d3			; read size
			move.l	dosHandle,a6
			jsr		_LVOReadFile(a6)
			tst.l	d0
			beq		readError

			move.l	fileH,d1
			move.l	dosHandle,a6
			jsr		_LVOCloseFile(a6)

			move.l	pBuffer,a0
			rts

			
exitProg:

		; close console
			move.l	conHandle,d1
			beq.s	.nocon
			move.l	dosHandle,a6
			jsr		_LVOCloseFile(a6)

		; close DOS library
.nocon:		move.l	dosHandle,a1
			move.l	$4.w,a6
			jsr		_LVOCloseLib(a6)

		; exit
			move.l	pOriginalStack,a7
			moveq	#0,d0
			rts
			
			
waitKey:	lea		txtPressReturn,a0
			bsr		gemdos9
			bsr		gemdos7
			rts
			
mallocError:
			lea		txtMallocError,a0
			bsr		gemdos9
			bsr		waitKey
			bra		exitProg


			
fileNotFound:
			lea		txtFNFError,a0
			bsr		gemdos9
			bsr		waitKey
			bra		exitProg

readError:
			lea		txtReadError,a0
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
			
	;data

conHandle:		dc.l	0
dosHandle:		dc.l	0

dosLibName:		dc.b	'dos.library',0
consoleName:	dc.b	'CON:0/224/480/24/LDOS HDD Loader...',0
floppy1Name:	dc.b	'PROGDIR:ldos_demo.adf',0
;floppy2Name:	dc.b	'PROGDIR:ldos_demo_d2.adf',0
txtPressReturn:	dc.b	10,'Press RETURN key',0
txtMallocError:	dc.b	'Floppy version requires 1MiB RAM',10
				dc.b	'HDD version requieres 3MiB RAM',10,0
txtFNFError:	dc.b	'Unable to find ADF file to load',10,0
txtReadError:	dc.b	'Error reading the ADF file',10,0
isOS2:			dc.b	0


				even
			
	;bss

pOriginalStack:	ds.l	1	
fsize:		ds.l	1			
fileH:		ds.l	1
pBuffer:	ds.l	1
buffer		ds.b	8

