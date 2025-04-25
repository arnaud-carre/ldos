;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Track Loader
;	Full ASYNC loading (depacker runs at the same time)
;
;---------------------------------------------------------

; async trackloader
; trackloading state machine is ticked by VBL
; decoding ptr is updated, and main thread could depack at the same time
; (depacking routine has a fence using decoding ptr in case of faster depacking than loading)


TRKS_IDLE			=	0
TRKS_SEEK			=	1
TRKS_READ_TRACK		=	2
TRKS_MOTOR_OFF		=	3

DISK_SYNC			=	$4489

SIMULATE_ERROR		=	0

loaderCrcStart:


trackloaderInit:

		lea		trackloaderVars(pc),a6				
		move.w	#TRKS_IDLE,trkState(a6)
		clr.w	trkDiskBusy(a6)
		move.w	#$7fff,trkTrack(a6)			; set current track to crazy high number, so next load will trigger a Seek0
		
		rts

		
seekTrack0:

		lea		trackloaderVars(pc),a6
		; seek track 0
		lea	$dff000,a3
		lea	$bfe001,a4
		lea	$bfd100,a5
		
		bsr		clockSync
		bset	#1,(a5)			; dir=1  (inside)
		bset	#2,(a5)			; side=0 (lower)
		bsr		clockSync
		
.wait0:	bsr		trkStep
		btst	#4,(a4)
		bne.s	.wait0
		
		clr.w	trkTrack(a6)
		
		; keep seek to outside now
		bclr	#1,(a5)			; dir=0  (outside)
		bsr		clockSync
		bsr		clockSync

		rts
		
isDisk2Inserted:		

			tst.l	(SVAR_HDD_BUFFER).w
			bne		hddChangeDisk


			lea	$dff000,a3
			lea	$bfe001,a4
			lea	$bfd100,a5
			move.w	#(1<<1),$9c(a3)				; clear disk req
			move.w	#(1<<1),$9a(a3)				; Disable disk interrupt

			bsr	motorOn
			
			lea		trackloaderVars(pc),a6
			tst.w	trkTrack(a6)
			beq.s	.track0
			bsr.s	seekTrack0
.track0:

			move.l	#512+MFM_DMA_SIZE,d0
			moveq	#MEMLABEL_BOOTREAD,d1
			bsr		allocChipMemLabel
			
			move.l	d0,-(a7)			; 512 bytes buffer
			addi.l	#512,d0
			move.l	d0,a5				; MFM buffer
			
			move.l	a5,a0
			bsr		readTrackCMD
			bsr		waitDiskReady
			
			move.l	a5,a0
			move.l	(a7)+,a1			; 512 bytes dest buffer
			clr.l	4(a1)				; clear the location where "key" should be found
			bsr		MFMBootSectorDecode	
			
			move.l	4(a1),-(a7)			; backup LDOS disk2 "key"
						
			moveq	#MEMLABEL_BOOTREAD,d0
			bsr		freeMemLabel

			move.l	(a7)+,d0
			cmpi.l	#'DP.1',d0
			seq		d0
			andi.l	#$ff,d0
			tst.b	d0
			beq.s	.no
			lea		diskOffset(pc),a0
			clr.l	(a0)
.no:
			rts
		
clockSync:	movem.l	d0/a0,-(a7)
			lea		clockTick(pc),a0
			move.l	(a0),d0
.wait:		cmp.l	(a0),d0
			beq.s	.wait
			movem.l	(a7)+,d0/a0
			rts

hddChangeDisk:

			move.l	(SVAR_HDD_BUFFER2).w,a0
			cmpi.l	#'DP.1',4(a0)
			beq.s	.ok
			trap	#0
.ok:		move.l	a0,(SVAR_HDD_BUFFER).w		; patch disk2 on disk1 buffer
			lea		diskOffset(pc),a0
			clr.l	(a0)

			move.l	#$000000ff,d0
			rts
		
; Main trackload ASYNC function
; input: 	d0.w  sector start
; 			d1.w  sector count
;			a0.l  loading address
; return	a1.l  busy flag address (.w)

trackLoadStart:

		; Alloc trackloading buffers ( MFM and ARJ7 depacking buffer)
			pea		(a0)
			move.b	#MEMLABEL_TRACKLOAD,(SVAR_CURRENT_MEMLABEL).w
			lea		nextEXEAllocs(pc),a0
			move.l	#MFM_DMA_SIZE,(a0)+
			move.l	#INFLATE_TMP_BUFFER_SIZE|LDOS_MEM_ANY_RAM,(a0)+
			lea		nextEXEAllocs(pc),a0
			bsr		batchAllocator
			move.l	(a7)+,a0

			tst.l	(SVAR_HDD_BUFFER).w
			bne		hddLoadStart

			movem.l	d2-d7/a2-a6,-(a7)
			lea		trackloaderVars(pc),a6

			move.w	#TRKS_IDLE,trkState(a6)		; bug: prevent disk motor off to trigger from a previous loading

			move.w	#-1,trkDiskBusy(a6)
			
			move.l	a0,(SVAR_LOAD_PTR).w
			move.w	d1,trkSectorCount(a6)
			move.w	d1,trkDecodedSecCount(a6)

			add.w	d0,d1				; sector end
			subq.w	#1,d1
			ext.l	d1
			divu.w	#11,d1
			move.w	d1,d2
			lsl.w	#8,d2
			swap	d1
			move.b	d1,d2
			move.w	d2,trkTSEnd(a6)		; end marker
			
			ext.l	d0
			divu.w	#11,d0
			move.w	d0,trkWantedTrack(a6)
			move.w	d0,d1
			lsl.w	#8,d1
			swap	d0
			move.w	d0,trkFirstSector(a6)
			move.b	d0,d1
			move.w	d1,trkTSBegin(a6)
		
			lea		floppyInt(pc),a0
			move.l	a0,$64.w
			
			lea	$dff000,a3
			lea	$bfe001,a4
			lea	$bfd100,a5
			
			move.w 	#$8000|(1<<4),$96(a3)		; Enable DMA Disk
			move.w	#DISK_SYNC,$7e(a3)			; synchro word
			move.w	#(1<<1),$9c(a3)				; clear disk req
			move.w	#$c000|(1<<1),$9a(a3)		; Enable Disk DMA Int


			bsr	motorOn

		; LDOS only support forward seek
		; if we need backward seek, reset to track 0
			move.w	trkWantedTrack(a6),d0			
			cmp.w	trkTrack(a6),d0
			bge.s	.ok
			
			bsr		seekTrack0
			
.ok:
			clr.w	trkDmaFlag(a6)
			move.w	#TRKS_SEEK,trkState(a6)
			lea		trkDiskBusy(a6),a1
			
			movem.l	(a7)+,d2-d7/a2-a6
			rts

motorOn:	
			ori.b	#$f<<3,(a5)		; no drive 0,1,2 & 3
			bclr	#7,(a5)			; motor on
			bclr	#3,(a5)			; drive 0

			movem.l	d0/a0,-(a7)
			lea		clockTick(pc),a0
			move.l	(a0),d0
			addi.l	#25,d0
			
.wait:		btst	#5,(a4)			; test si disk est pret
			beq.s	.ready
			cmp.l	(a0),d0
			bgt.s	.wait
.ready:
			movem.l	(a7)+,d0/a0
			rts

			
trkStep:	bclr	#0,(a5)
			bsr		lwait
			bset	#0,(a5)			 ; motor step
			bsr		wait4ms
			rts
			
lwait:		bsr.s	.lwait
			bsr.s	.lwait
			nop
.lwait:		rts


unknownInterrupt:
			move.w	$dff01e,-(a7)
			move.w	$dff01a,-(a7)
			movea.l	a7,a1
			lea		.txt(pc),a0
			trap	#0
.txt:		dc.b	'Unknown interrupt! ($%w,$%w)',0
			even

floppyInt:

			btst	#1,$dff01f
			beq.s	unknownInterrupt

			pea		(a6)
			lea		fiberData+15*4+4+2(pc),a6
			move.l	(a7)+,-(a6)
			movem.l	d0-a5,-(a6)

			move.w	(a7),-(a6)			; save SR
			move.l	2(a7),-(a6)			; return PC

			move.w	(a7),d0
			andi.w	#$2000,d0
			bne		.super

			; first, set the decode buffer
			lea		trackloaderVars(pc),a6
			move.w	trkFirstSector(a6),m_sectorStart(a6)
			move.w	trkTrack(a6),m_track(a6)
			move.w	trkSectorsInTrack(a6),m_sectorCount(a6)
			move.w	#-1,trkDmaFlag(a6)			; marker decoder buffer as ready for async decoder

			move.w	$dff006,d0
			lsl.w	#8,d0
			add.b	$bfd800,d0
			add.w	d0,trkEntropyValue(a6)

			lea		fiberDecoder(pc),a0
			move.l	a0,2(a7)

			move.w	#(1<<1),$dff09c				; clear disk req
			move.w	#(1<<1),$dff09c				; clear disk req
			nop
			rte

.super:		move.l	#$12345678,d7
			illegal


trackLoaderTick:

			lea		trackloaderVars(pc),a6
			move.w	trkState(a6),d0
			beq.s	.idle

			pea		.idle(pc)
			lea		$dff000,a3
			lea		$bfe001,a4
			lea		$bfd100,a5
			lsl.w	#2,d0
			jmp		.switch(pc,d0.w)

.switch:	bra.w	.idle					; 0
			bra.w	stateSeek				; 1
			bra.w	stateReadTrack
			bra.w	stateMotorOff

.idle:		
			lea		clockTick(pc),a0
			addq.l	#1,(a0)

			rts
		
		
stateSeek:
				move.w	trkWantedTrack(a6),d0
				cmp.w	trkTrack(a6),d0
				bne.s	.needMove

				; already on same track, read track immediatly
				move.w	#TRKS_READ_TRACK,trkState(a6)
				bra		stateReadTrack
				
				; first set the side
.needMove:		moveq	#1,d0
				and.w	trkWantedTrack(a6),d0
				beq.s	.side0
				bclr	#2,(a5)			; Side 1
				ori.w	#1,trkTrack(a6)
				bra.s	.next
.side0:			bset	#2,(a5)			; Side 0
				andi.w	#-2,trkTrack(a6)
.next:			move.w	trkWantedTrack(a6),d0
				lsr.w	#1,d0						; cylinder
				move.w	trkTrack(a6),d1
				lsr.w	#1,d1
				cmp.w	d0,d1
				beq.s	.goodOne
				
				; we must step out to next cylinder
				bclr	#0,(a5)			; step
				bsr		lwait
				bset	#0,(a5)			; step  (impulsion)
				addq.w	#2,trkTrack(a6)	; one cylinder more (two tracks)
				rts
				
.goodOne:		move.w	#TRKS_READ_TRACK,trkState(a6)
				rts



stateReadTrack:
				tst.w	trkDmaFlag(a6)
				bne		.busy					; can't start DMA loading, decoder has not finished (should not)
				
				; compute number of sectors to read in this track
				move.w	trkFirstSector(a6),d0
				add.w	trkSectorCount(a6),d0
				cmpi.w	#11,d0
				ble.s	.ok
				moveq	#11,d0
.ok:			sub.w	trkFirstSector(a6),d0
				move.w	d0,trkSectorsInTrack(a6)

				move.l	pMFMRawBuffer(pc),a0
				bsr.s	readTrackCMD
				
				move.w	#TRKS_IDLE,trkState(a6)				; idle state (DMA interrupt should fire soon)
				
.busy:			rts


; a0: MFM_DMA_SIZE bytes buffer to store  track data
; warning: this run the command and returns immediatly
readTrackCMD:
				pea		(a3)
				lea		$dff000,a3								
				move.w	#2,$9c(a3)						; Clear disk int req				
				move.l	a0,$20(a3)		; DMA address
				move.w 	#$8000|(1<<4),$96(a3)
				move.w	#DISK_SYNC,$7e(a3)			; synchro word
				move.w	#$6600,$9e(a3)
				move.w	#$8000|(1<<12)|(1<<10)|(1<<8),$9E(a3)		; disk mode: fast, MFM and WORD sync
				move.w	#$4000,$24(a3)
				move.w	#(MFM_DMA_SIZE/2)|($8000),$24(a3)	; Lance la lecture DMA
				move.w	#(MFM_DMA_SIZE/2)|($8000),$24(a3)	; (A faire 2 fois, voir bible)
				move.l	(a7)+,a3
				rts

waitDiskReady:	btst 	#1,$dff01f
				beq.s 	waitDiskReady
				rts


fiberDecoder:
				bsr.s	MFMDecodeTrackCallback

				lea		fiberData(pc),a6
				move.l	(a6)+,-(a7)
				move.w	(a6)+,d0
				move	d0,ccr
				movem.l	(a6),d0-a6
				rts

MFMDecodeTrackCallback:

			movem.l	d0-a6,-(a7)

			lea		trackloaderVars(pc),a6

		; backup values for retry
			move.w	m_sectorCount(a6),-(a7)
			move.w	trkDecodedSecCount(a6),-(a7)
			
.retry:
			move.w	(a7),trkDecodedSecCount(a6)
;			move.w	2(a7),m_sectorCount(a5)

.notReady:	tst.w	trkDmaFlag(a6)
			beq.s	.notReady

			move.l	pMFMRawBuffer(pc),a0
			lea		MFM_DMA_SIZE(a0),a2			; end buffer check

		; simulate error by patching random byte	
	IF SIMULATE_ERROR
			moveq	#3,d0
			and.b	$dff006,d0
			bne		.noerr
			move.w	$dff006,d0
			andi.w	#8190,d0
			move.w	d0,0(a0,d0.w)		; scratch MFM buffer with bad data
.noerr:
	ENDC
.sectorLoop:


			movea.l	a2,a1						; MFM buffer end
			bsr		MFMSearchNextSector
			tst.w	d0
			bmi		.diskSectorError
			cmpi.w 	#11,d0
			bge		.diskSectorError

			move.w	m_track(a6),d1
			lsl.w	#8,d1
			move.b	d0,d1		; d1 = track|sector
			cmp.w	trkTSBegin(a6),d1
			bcs.s	.skip
			cmp.w	trkTSEnd(a6),d1
			bhi.s	.skip
			sub.w	m_sectorStart(a6),d0
			lsl.w	#8,d0
			add.w	d0,d0				; *512
			move.l	(SVAR_LOAD_PTR).w,a1
			add.w	d0,a1							
			bsr		MFMSectorDecode			
			tst.b	d0
			bne		.diskSectorError
			subq.w	#1,m_sectorCount(a6)
			subq.w	#1,trkDecodedSecCount(a6)

.skip:		lea		(512*2)(a0),a0					; skip odd bits for next turn
			tst.w	m_sectorCount(a6)
			bne		.sectorLoop

		; everything is decoded without error
			addq.w	#4,a7			; skip backup values

			; now check if there is still sectors to go
			move.w	trkSectorsInTrack(a6),d0
			sub.w	d0,trkSectorCount(a6)
			bne.s	.cont
			
			move.w	#TRKS_MOTOR_OFF,trkState(a6)
			clr.w	trkDiskBusy(a6)
			move.w	#50,trkMotorOffTimeOut(a6)
			bra.s	.back
			
.cont:		bpl.s	.noassert
			lea		.txt(pc),a0
			trap	#0
.txt:		dc.b	'trkSectorCount!',0
			even
.noassert:
		
			addq.w	#1,trkWantedTrack(a6)
			clr.w	trkFirstSector(a6)
			move.w	#TRKS_IDLE,trkState(a6)

.back:




			moveq	#11,d0
			sub.w	m_sectorStart(a6),d0
			lsl.w	#8,d0
			add.w	d0,d0
			add.l	d0,(SVAR_LOAD_PTR).w

			; mark decode buffer as free (so trackloader can use it)
			clr.w	trkDmaFlag(a6)
			
			; advance "get" pointer (decoder)
	IF SIMULATE_ERROR
			move.w	#$0f0,$dff180
	ENDC
			tst.w	trkDecodedSecCount(a6)
			beq.s	.done
			move.w	#TRKS_SEEK,trkState(a6)				; idle state (DMA interrupt should fire soon)
.done:
			movem.l	(a7)+,d0-a6
			rts


.diskSectorError:
		IF SIMULATE_ERROR
			move.w	#$f00,$dff180
		ENDC
			; mark decode buffer as free (so trackloader can use it)
			clr.w	trkDmaFlag(a6)
			bsr		stateReadTrack
			bra		.retry


					
stateMotorOff:	subq.w	#1,trkMotorOffTimeOut(a6)
				bne.s	.notYet
				move.w	#TRKS_IDLE,trkState(a6)
				bset	#3,(a5)		; no drive 0,1,2 & 3
				bset	#7,(a5)		; motor off
				bclr	#3,(a5)		; drive 0
.notYet:		rts

trkError:
			move.w	d1,-(a7)
			move.l	a7,a1
			lea		.txt(pc),a0
			trap	#0
.txt:		dc.b	'MFM Track id error ($%w)',0
			even

; a0: MFM data
; a1: 512 bytes dest buffer
; returns: d0=0 means OK
MFMBootSectorDecode:
			movem.l	d7/a1-a3,-(a7)
			move.l	a1,a3						; dest buffer
			lea		MFM_DMA_SIZE(a0),a2			; end buffer check
			moveq	#11-1,d7					; at worst, parse 11 sectors to find sector 0

.sectorLoop:			
			movea.l	a2,a1						; MFM end ad buffer
			bsr		MFMSearchNextSector
			tst.w	d0
			bmi.s	.error
			tst.w	d0
			bne.s	.skip
			movea.l	a3,a1						;decode
			bsr.s	MFMSectorDecode
			tst.b	d0
			bne.s	.error
			moveq	#0,d0
			bra.s	.back
			
.skip:		lea		(512*2)(a0),a0
			dbf		d7,.sectorLoop
.error:		moveq	#-1,d0
.back:		movem.l	(a7)+,d7/a1-a3
			rts


; a0: MFM data
; a1: 512 bytes dest buffer
; returns: d0.b=0 means OK
MFMSectorDecode:
			movem.l	d1-d4/a0-a2,-(a7)
			move.l	#$55555555,d2			; clear les bits de check.
			movem.l	(a0)+,d0/d3
;			and.l	d2,d0
			and.l	d2,d3
;			add.l	d0,d0
;			or.l	d0,d3			; Data checksum.
			moveq	#512/4-1,d4
			lea		512(a0),a2

.decLoop:	move.l	(a0)+,d0
			and.l	d2,d0
			eor.l	d0,d3
			move.l	(a2)+,d1
			and.l	d2,d1
			eor.l	d1,d3
			add.l	d0,d0
			or.l	d1,d0
			move.l	d0,(a1)+
			dbf		d4,.decLoop
			tst.l	d3
			sne		d0
			movem.l	(a7)+,d1-d4/a0-a2
			rts

; a0: MFM current search PTR
; a1: End of MFM buffer
; returns: d0.w: sector number or <0 if ERROR
;		   a0:   current MFM pointer
MFMSearchNextSector:
			movem.l	d1,-(a7)
.search		cmpa.l	a0,a1
			ble.s	.error
			cmpi.w	#DISK_SYNC,(a0)+
			bne.s	.search
			cmpi.w	#DISK_SYNC,(a0)
			beq.s	.search

		; check header CRC
			move.l	44(a0),d1
			move.l	#$55555555,d2
			moveq	#10-1,d3
.crcLoop:	move.l	(a0)+,d0
			eor.l	d0,d1
			dbf		d3,.crcLoop
			and.l	d2,d1
			bne.s	.error
			addq.w	#8,a0

	; Cherche le numero de secteur physique.
			move.l	-48(a0),d0
			move.l	-48+4(a0),d1
			and.l	d2,d0
			and.l	d2,d1
			add.l	d0,d0
			or.l	d1,d0
			move.l	d0,d1
			swap	d1
			cmp.b	m_track+1(a6),d1
			bne		trkError
			lsr.w	#8,d0		; sector number
			bra.s	.back

.error:		moveq	#-1,d0
.back:		movem.l	(a7)+,d1
			rts
		
				
; Main trackload ASYNC function
; input: 	d0.w  sector start
; 			d1.w  sector count
;			a0.l  loading address
; return	a1.l  busy flag address (.w)
hddLoadStart:
			movea.l	a0,a1						; dest ad
			move.l	(SVAR_HDD_BUFFER).w,a0
			mulu.w	#512,d0
			add.l	d0,a0						; src ad
			mulu.w	#512,d1						;
			move.l	d1,d0						; size

			bsr		fastMemMove

			add.l	d0,a1						; end ad
			move.l	a1,(SVAR_LOAD_PTR).w		; allow depacker to run 

			lea		(trackloaderVars+trkDiskBusy)(pc),a1

			rts			


loaderCrcEnd:
				
		rsreset
trkState:			rs.w	1
trkDiskBusy:		rs.w	1
trkSectorCount:		rs.w	1
trkDecodedSecCount:	rs.w	1
trkTrack:			rs.w	1
trkWantedTrack:		rs.w	1
trkTSBegin:			rs.w	1
trkTSEnd:			rs.w	1
trkSectorsInTrack:	rs.w	1
trkFirstSector:		rs.w	1
trkMotorOffTimeOut:	rs.w	1
trkEntropyValue:	rs.w	1
trkDmaFlag:			rs.w	1
m_sectorStart:		rs.w	1
m_track:			rs.w	1
m_sectorCount:		rs.w	1
trkSizeOf:			rs.w	0
		
trackloaderVars:	ds.b	trkSizeOf
