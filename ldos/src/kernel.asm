;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Kernel
;
;---------------------------------------------------------

; NOTE: should be relocatable code

_LVOOpenLib			=	-552

		include	"../kernel.inc"
		include	"kernelPrivate.inc"


; come from boot sector
; d6 = disk offset|FAT size

; NOTE: here the AMIGA system is still running. We use amiga OS to get memory configuration.
;		After that, we kill everything, relocate and run our own OS ( from kernelStart to kernelEnd )

entry:
		lea		fatSize(pc),a0
		move.w	d6,(a0)
		lea		diskOffset(pc),a0
		clr.w	d6
		swap	d6
		move.l	d6,(a0)

	; switch off cache using system call if ROM > 37
		move.l	$4.w,a6
		move.w	14+6(a6),d0
		cmp.w   #37,d0		; LIB_VERSION should be at least 37
		blt.s   .noCache		
		moveq	#0,d0
		moveq	#-1,d1
		jsr		-648(a6)
.noCache:

	; Open graphics library to exec loadview & stuff on weird AMIGA Gfx card
		move.l	$4.w,a6
		lea		graphicsLibName(pc),a1
		moveq	#0,d0
		jsr		_LVOOpenLib(a6)
		tst.l	d0
		beq.s	.fail
		move.l	d0,a6
		sub.l   a1,a1
		jsr     -222(a6)            ; LoadView()
		jsr     -270(a6)            ; WaitTOF()
		jsr     -270(a6)
.fail:
		
	; check the CPU and clear cache & VBR if requiered
		move.l	$4.w,a6
		moveq	#3,d0
		and.b	$129(a6),d0
		beq.s	.mc68k
		lea		supervisor(pc),a5
		jsr		-30(a6)			; SuperVisor()
.mc68k:

	; weird random sprite bug: always wait vsync before disabling sprite DMA
		bsr		pollVSync

	; Now we don't need system anymore
	; switch off all interrupts
		lea		$dff000,a6
		move.w	#$7fff,d0
		move.w	d0,$96(a6)		;desactive tous les DMA
		move.w	d0,$9a(a6)		;desactive toutes les ITs
		move.w	d0,$9c(a6)
		move.w	d0,$9e(a6)
		move.w	#$0200,$100(a6)	; switch off bitplan
		move.w	#$000,$180(a6)

	; clear sprites
		bsr	clearSprites

	; store HDD version buffers
		move.l	m_hddBuffer1(a7),(SVAR_HDD_BUFFER).w
		move.l	m_hddBuffer2(a7),(SVAR_HDD_BUFFER2).w

	; read back entropy initial value
		lea		trackloaderVars(pc),a6
		move.w	m_entropyValue(a7),trkEntropyValue(a6)
		
		tst.l	m_hddBuffer1(a7)
		bne		.memInit

		; always suppose CHIP start at $0
		move.l	m_chipStart(a7),d0
		add.l	d0,m_chipSize(a7)		; CHIP start at 0, so add the base ad to the total size
		clr.l	m_chipStart(a7)
		lea		m_chipStart(a7),a0
		bsr		align128

		cmpi.l	#512*1024,m_chipSize(a7)
		blt		memoryError

		cmpi.l	#512*2*1024,m_chipSize(a7)
		blt.s	.needFake

		move.l	#512*1024,m_fakeStart(a7)
		bra		.memInit

.needFake:
		tst.l	m_fakeSize(a7)
		beq		memoryError

		; Align fake RAM start & end on 128KiB
		lea		m_fakeStart(a7),a0
		bsr		align128				

		cmpi.l	#512*1024,m_fakeSize(a7)
		blt		memoryError
	
	; initialize memory manager
.memInit:
		lea		chipMemTable(pc),a0
		move.l	m_chipStart(a7),d0
		bsr		initMemTable		
		
		lea		fastMemTable(pc),a0
		move.l	m_fakeStart(a7),d0				; base ad
		bsr		initMemTable		
		
		
		;--------------------------------------
		; Now we kill system and reloc kernel

		move.b	#MEMLABEL_SYSTEM,(SVAR_CURRENT_MEMLABEL).w

		; hack: patch the real size of kernel before calling batchAllocator
		; NOTE: It works because batchAllocator always alloc CHIP first, so we're sure
		;		that kernel code is not relocated at $0 adress
		lea		(kernelEnd-kernelStart).w,a1	; a1 is a size :)
		add.w	fatSize(pc),a1
		lea		pKernelBase(pc),a0
		move.l	a1,(a0)
		ori.l	#LDOS_MEM_ANY_RAM,(a0)
		
		; Alloc kernel chip memory
		lea		dynamicAllocs(pc),a0
		bsr		batchAllocator

		lea		pUserStack(pc),a0
		addi.l	#LDOS_USERSTACK_SIZE,(a0)
		lea		pSuperStack(pc),a0
		addi.l	#LDOS_SUPERSTACK_SIZE,(a0)

		move.l	pUserStack(pc),a7					; set user stack
		bsr		ispSet								; bug fixed! Set ISP before relocating kernel

		lea		kernelStart(pc),a0
		move.l	pKernelBase(pc),a1
		moveq	#0,d0
		move.w	#(kernelEnd-kernelStart),d0
		add.w	fatSize(pc),d0
		bsr		fastMemMove
		jmp		(a1)						; jump to kernel base relocated

align128:
		move.l	(a0),d0					; start
		move.l	d0,d1
		add.l	4(a0),d1				; end
		andi.l	#-128*1024,d0			; aligned start
		addi.l	#128*1024-1,d1
		andi.l	#-128*1024,d1
		sub.l	d0,d1					; aligned size
		move.l	d0,(a0)
		move.l	d1,4(a0)
		rts
		
supervisor:
		moveq	#0,d0
		dc.l	$4e7b0801		; opcode "MOVEC d0,VBR"
		move.l	$4.w,a6
		btst.b	#1,$129(a6)
		beq.s	.mc68010
		dc.l	$4e7b0002		; opcode "MOVEC d0,cacr"
.mc68010:
		rte

memoryError:
		move.w	#$7fff,$dff096
		move.w	#$7fff,$dff09a
		bsr		debugScreenSetup
		lea		.txt(pc),a0
		bsr		debugScreenPrint
.infl:	bra.s	.infl
		
.txt:	dc.b	'LDOS Kernel',10
		dc.b	'This demo requires 1MiB of RAM',10
		dc.b	0
graphicsLibName:	dc.b	'graphics.library',0		
		
		even
		
;-----------------------------------------------------------------------------------
;
; WARNING: this part contains kernel code only and is relocated in low memory
;
;-----------------------------------------------------------------------------------
kernelCrcStart:
kernelStart:
		bsr		vectorSet

		bsr		trackloaderInit
		
		bsr		systemInstall
		
		moveq	#125,d0						; 125 BPM is default kernel freq
		bsr		cia50HzInstall
		
mainDemoLoop:

		; if next FX is not loaded, do it!
		move.l	(nextFx+m_ad)(pc),d0
		bne.s	.already
		bsr		loadNextFile
.already:

		bsr		runLoadedFile
		
		bra.s	mainDemoLoop
		
			opt o-		; switch off ALL optimizations (we really want these bra to be 4bytes )

kernelLibrary:
			bra.w	userLoadNextFile
			bra.w	assertVector
			bra.w	musicStart
			bra.w	musicGetTick			; music get info
			bra.w	musicStop				; music stop (with fade out)
			bra.w	isDisk2Inserted
			bra.w	persistentChipAlloc
			bra.w	persistentChipGet
			bra.w	persistentChipTrash
			bra.w	loadBinaryBlob
			bra.w	getEntropy
			bra.w	trackLoaderTick
			bra.w	ldosGetClockTick
			bra.w	LSP_MusicGetPos			; LDOS_MUSIC_GET_SEQ_POS
			bra.w	persistentFakeAlloc
			bra.w	persistentFakeGet
			bra.w	persistentFakeTrash
			bra.w	loadFileCustom
			bra.w	setNextFileId
			bra.w	getBlackboardAddr
			bra.w	preloadFromLz4Memory
			bra.w	wipePreviousFx
			
			
			opt o+		; enable
			
persistentChipAlloc:
			movem.l	a0,-(a7)
			move.l	d0,-(a7)
			bsr		persistentChipTrash			; Always trash any previous persistent CHIP if persistent alloc is made
			bsr		allocPersistentChip
			lea		persistentChipAd(pc),a0
			move.l	d0,(a0)+				; store AD
			move.l	(a7)+,(a0)+				; store original size
			movem.l	(a7)+,a0			
			rts

persistentFakeAlloc:
			movem.l	a0,-(a7)
			move.l	d0,-(a7)
			bsr		persistentFakeTrash		; Always trash any previous persistent FAKE if persistent alloc is made
			bsr		allocPersistentFake
			lea		persistentFakeAd(pc),a0
			move.l	d0,(a0)+				; store AD
			move.l	(a7)+,(a0)+				; store original size
			movem.l	(a7)+,a0			
			rts
			
persistentChipGet:
			move.l	persistentChipAd(pc),d0
			move.l	persistentChipSize(pc),d1
			rts

persistentFakeGet:
			move.l	persistentFakeAd(pc),d0
			move.l	persistentFakeSize(pc),d1
			rts
			
persistentChipTrash:
			movem.l	a0,-(a7)
			bsr		trashPersistentChip
			lea		persistentChipAd(pc),a0
			clr.l	(a0)+
			movem.l	(a7)+,a0			
			rts
			
persistentFakeTrash:
			movem.l	a0,-(a7)
			bsr		trashPersistentFake
			lea		persistentFakeAd(pc),a0
			clr.l	(a0)+
			movem.l	(a7)+,a0			
			rts
			
userLoadNextFile:
			bsr		loadNextFile
			rts

wipePreviousFx:
		; Free all memory of previous FX
			moveq	#MEMLABEL_USER_FX,d0
			bsr		freeMemLabel
			rts

; input: a0: lz4 frame data
;		 d0.l: unpacked data size
preloadFromLz4Memory:
			pea		(a0)
			move.l	d0,-(a7)

			lea		nextFx(pc),a0
			move.l	(a7)+,d0
			move.l	d0,m_size(a0)
			move.b	#MEMLABEL_PRECACHED_FX,(SVAR_CURRENT_MEMLABEL).w
			bsr		allocAnyMem

			lea		nextFx(pc),a6
			ori.w	#1<<kLDOSExeFile,m_flags(a6)	; hack to force type to LDOS exe
			move.l	d0,m_ad(a6)
			move.l	d0,a1
			move.l	(a7)+,a0

			bsr		lz4_frame_depack

			rts

			include	"lz4_frame.asm"
			even


runLoadedFile:		
		; WARNING: to avoid memory fragmentation, the next FX is always moved back to low memory
		; to do this, simply mark next FX pages as FREE, alloc a new block, and MOVE memory there.
		; DO NOT CHANGE ANYTHING HERE without caution: The memory block is marked as "free" but 
		; the memory is still valid. We just can move "down" some blocks
		; WARNING: Both memory array overlap! But destination always lower ad than source
			moveq	#MEMLABEL_PRECACHED_FX,d0
			bsr		unmarkMemLabel

		; Proceed and reloc loaded data ( exe, module, etc)
			move.w	(nextFx+m_flags)(pc),d0
			btst	#kLDOSExeFile,d0
			beq.s	.noExe
			bsr		amigaReloc			; AMIGA exe relocation routine + move memory down for fragmentation
			bra.s	.next
.noExe:		btst	#kLDOSLsMusicFile,d0
			beq.s	.noLsMusic
			bsr		relocLSMusic
			bra.s	.next

.noLsMusic:	btst	#kLDOSLsBankFile,d0
			beq.s	.noLsBank
			bsr		relocLSBank
			bra.s	.next

.noLsBank:	
			move.w	currentFile(pc),-(a7)
			movea.l	a7,a1
			lea		.txtUnknowFile(pc),a0
			trap	#0

.next:		lea		(nextFx+m_ad)(pc),a0
			move.l	(a0),a1
			clr.l	(a0)

		; inc current file in case the next FX do a PRELOAD command
			lea		currentFile(pc),a0
			addq.w	#1,(a0)	

		; get the kernel CRC
	IF _DEBUG

			moveq	#-1,d0
			bsr		crcCompute
	ENDC

		; call the FX code
			cmpa.l	#0,a1
			beq.s	.noExec
			
			move.b	#MEMLABEL_USER_FX,(SVAR_CURRENT_MEMLABEL).w
			lea		nextFx(pc),a0
			moveq	#0,d0
			move.w	m_arg(a0),d0			; user arg
			move.l	m_argd1(a0),d1
			jsr		(a1)
.noExec:

		; back from the FX: we should restore kernel state
	IF _DEBUG
			moveq	#0,d0
			bsr		crcCompute
	ENDC
			bsr		systemInstall

		; if user switched off our LDOS tick timer, run it again
			lea		ldos50Hz(pc),a0
			cmp.l	$78.w,a0			; if user changed $78 vector, reset it
			bne.s	.rset
			move.w	$dff01c,d0
			btst	#13,d0
			bne.s	.ok

.rset:		moveq	#125,d0						; 125 BPM is default kernel freq
			bsr		cia50HzInstall
.ok:
		; If no music is playing, switch off Audio (in case of audio still running in last fx)
			move.w	bMusicPlay(pc),d0
			bne.s	.ldosMusic
			lea		$dff000,a5
			move.w	#$f,$96(a5)
			moveq	#0,d0
			move.w	d0,$a8(a5)
			move.w	d0,$b8(a5)
			move.w	d0,$c8(a5)
			move.w	d0,$d8(a5)
			
.ldosMusic:

		; Free all memory of previous FX
			moveq	#MEMLABEL_USER_FX,d0
			bsr		freeMemLabel

			rts
	
.txtUnknowFile:	dc.b	"Unable to execute file id #%w",0
				even
								
installCopperList:
			lea		pCopperList1(pc),a2
			move.l	(a2),a1
.copy:		move.l	(a0)+,(a1)+
			cmpi.l	#-2,-4(a0)
			bne.s	.copy
			move.l	(a2),d0
			move.l	4(a2),(a2)
			move.l	d0,4(a2)
			move.l	d0,$dff080
			move.l	d0,a0
			rts
		
musicStop:	lea		bMusicPlay(pc),a0
			clr.w	(a0)
			lea		$dff000,a0
			move.w	#$000f,$96(a0)
			moveq	#0,d0
			move.w	d0,$a8(a0)
			move.w	d0,$b8(a0)
			move.w	d0,$c8(a0)
			move.w	d0,$d8(a0)
		; free music memory
			moveq	#MEMLABEL_MUSIC_LSM,d0
			bsr		freeMemLabel
			moveq	#MEMLABEL_MUSIC_LSB,d0
			bsr		freeMemLabel			
			rts

musicGetTick:
			move.l	musicTick(pc),d0
			rts

ldosGetClockTick:
			move.l	clockTick(pc),d0
			rts

musicStart:	
			lea		bMusicPlay(pc),a0
			tst.w	(a0)
			bne.s	.errm
			move.l	LSMusic(pc),d0
			beq.s	.skip
			move.l	LSBank(pc),d1
			beq.s	.skip

			move.l	d0,a0
			move.l	d1,a1
			lea		LSPDmaCon+1(pc),a2
			bsr		LSP_MusicInit
			lea		LSPInfos(pc),a1
			move.l	a0,(a1)

			lea		LSPCurBpm(pc),a2
			move.w	(a0),d0
			move.w	d0,(a2)					; current BPM
			bsr		cia50HzInstall

			lea		musicTick(pc),a0
			clr.l	(a0)
			lea		bMusicPlay(pc),a0
			move.w	#-1,(a0)
.skip:		rts
						
.errm:		lea		.txt(pc),a0
			trap	#0
.txt:		dc.b	"musicStart called while music is playing",0
			even

; wait 64 raster lines (about 4ms in PAL)
wait4ms:	move.w	d0,-(a7)
			move.w	#63,d0
			bsr.s	waitScanlines
			move.w	(a7)+,d0
			rts

; d0: scanlines number to wait
waitScanlines:
			movem.l	d0-d1/a0,-(a7)
			lea		$dff006,a0
.twait:		move.b	(a0),d1			; VPOS (bit 0..7)
.swait:		cmp.b	(a0),d1
			beq.s	.swait
			dbf		d0,.twait
			movem.l	(a7)+,d0-d1/a0
			rts


; a0: src ( aligned on 2 )
; a1: dst ( aligned on 2 )
; d0.l: size ( aligned on 2 )
fastMemMove:
			cmpa.l	a0,a1
			beq		.useless
			bgt		memMoveMinus

.memMovePlus:
			movem.l	d0-d7/a0-a2,-(a7)
			move.w	d0,-(a7)
			lsr.l	#7,d0
			beq.s	.reminder

			subq.w	#1,d0				; should fit in 15bits for the DBF
.copy:		movem.l	(a0)+,d1-d7/a2
			movem.l	d1-d7/a2,(a1)
			movem.l	(a0)+,d1-d7/a2
			movem.l	d1-d7/a2,32*1(a1)
			movem.l	(a0)+,d1-d7/a2
			movem.l	d1-d7/a2,32*2(a1)
			movem.l	(a0)+,d1-d7/a2
			movem.l	d1-d7/a2,32*3(a1)
			lea		32*4(a1),a1
			dbf		d0,.copy

.reminder:	moveq	#127,d0
			and.w	(a7)+,d0		; reminder on 128 bytes
			lsr.w	#1,d0
			beq.s	.over
			subq.w	#1,d0
.cloop:		move.w	(a0)+,(a1)+
			dbf		d0,.cloop

.over:		movem.l	(a7)+,d0-d7/a0-a2
.useless:	rts

memMoveMinus:
			movem.l	d0-d7/a0-a2,-(a7)
			add.l	d0,a0
			add.l	d0,a1
			move.w	d0,-(a7)
			lsr.l	#7,d0
			beq.s	.reminder

			subq.w	#1,d0				; should fit in 15bits for the DBF
.copy:		lea		-32*4(a0),a0
			movem.l	32*3(a0),d1-d7/a2
			movem.l	d1-d7/a2,-(a1)
			movem.l	32*2(a0),d1-d7/a2
			movem.l	d1-d7/a2,-(a1)
			movem.l	32*1(a0),d1-d7/a2
			movem.l	d1-d7/a2,-(a1)
			movem.l	(a0),d1-d7/a2
			movem.l	d1-d7/a2,-(a1)
			dbf		d0,.copy

.reminder:	moveq	#127,d0
			and.w	(a7)+,d0		; reminder on 128 bytes
			lsr.w	#1,d0
			beq.s	.over
			subq.w	#1,d0
.cloop:		move.w	-(a0),-(a1)
			dbf		d0,.cloop

.over:		movem.l	(a7)+,d0-d7/a0-a2
			rts


; a0: dst ( aligned on 2 )
; d0.l: size in bytes ( aligned on 2 )
fastClear:	
			movem.l	d0-d7/a0-a2,-(a7)
            add.l   d0,a0               ; clear top to bottom
			move.w	d0,-(a7)
			lsr.l	#7,d0
			beq.s	.reminder

			subq.w	#1,d0				; should fit in 15bits for the DBF
            moveq   #0,d1
            move.l  d1,d2
            move.l  d1,d3
            move.l  d1,d4
            move.l  d1,d5
            move.l  d1,d6
            move.l  d1,d7
            move.l  d1,a2
.copy:		movem.l	d1-d7/a2,-(a0)
            movem.l	d1-d7/a2,-(a0)
            movem.l	d1-d7/a2,-(a0)
            movem.l	d1-d7/a2,-(a0)
			dbf		d0,.copy

.reminder:	moveq	#127,d0
			and.w	(a7)+,d0		; reminder on 128 bytes
			lsr.w	#1,d0
			beq.s	.over
			subq.w	#1,d0
.cloop:		move.w	d1,-(a0)
			dbf		d0,.cloop

.over:		movem.l	(a7)+,d0-d7/a0-a2
.useless:	rts


		
		
; input: nextFx struct properly filled
nextEXEDoAlloc:
		movem.l	d0-d1/a0,-(a7)

		lea		nextFx(pc),a6
				
		move.b	#MEMLABEL_PRECACHED_FX,(SVAR_CURRENT_MEMLABEL).w

		move.l	m_size(a6),d0
		addi.l	#DEPACK_IN_PLACE_MARGIN+DISK_SECTOR_ALIGN_MARGIN,d0	; unpacked size
		
		btst.b	#kLDOSLsBankFile,(nextFx+m_flags+1)(pc)	; Try to directly load in CHIP if music file
		beq.s	.normal

		move.l	d0,-(a7)
		bsr		allocChipMem
		tst.l	d0
		bne.s	.ok

		move.l	(a7)+,d0
		bra.s	.normal
		
.ok:	addq.l	#4,a7
		bra.s	.next

.normal:
		bsr		allocAnyMem
.next:	lea		nextEXEDepacked(pc),a0
		move.l	d0,(a0)

		move.l	m_packedSize(a6),d0
		move.l	m_size(a6),d1
		addi.l	#DEPACK_IN_PLACE_MARGIN-DISK_SECTOR_ALIGN_MARGIN,d1
		sub.l	d0,d1						; offset
		add.l	(a0),d1						; loading AD
		lea		alignedDmaLoadAd(pc),a0
		move.l	d1,(a0)

		movem.l	(a7)+,d0-d1/a0
		rts

getEntropy:
			pea		(a0)
			lea		trackloaderVars(pc),a0
			move.w	trkEntropyValue(a0),d0
			move.l	(a7)+,a0
			rts
		
;-----------------------------------------------------------------		
; input
; d0: screen number ( script.txt order )
; output:
; a0: loading address
; d0: size
loadBinaryBlob:
			move.w	d0,-(a7)

			move.b	#MEMLABEL_PRECACHED_FX,d0
			bsr		freeMemLabel

			move.w	(a7)+,d0
			bsr		allocAndLoadFile
		
			lea		nextFx(pc),a6
			move.l	m_ad(a6),a0
			move.l	m_size(a6),d0

			rts

;-----------------------------------------------------------------		
; input:
; d0: screen number ( script.txt order )		
; output:
; nextFx filled properly
getFSInfos:
			lsl.w	#4,d0				; FAT entry is 4 DWORDS: Floppy disk offset, Packed size, Unpacked size, user Arg

.infloop:	cmp.w	fatSize(pc),d0		; special case to test each FX. when we reach end of disk, loop here
			bge		.notf
		
			lea	directory(pc),a5
			add.w	d0,a5
			lea		nextFx(pc),a6
			move.w	12(a5),m_flags(a6)		; file entry flags
			move.w	14(a5),m_arg(a6)		; user arg

			move.l	8(a5),m_size(a6)		; depacked size
			move.l	(a5),d0			; offset dans le disk.
			add.l	diskOffset(pc),d0

			move.w	#511,d1
			and.w	d0,d1			; sector offset
			lea		sectorOffset(pc),a1
			move.w	d1,(a1)			; store in .sectorOffset

			move.l	d0,d1
			move.l	4(a5),d2
			move.l	d2,m_packedSize(a6)
			add.l	d2,d1		; +size = ad de fin
			andi.l	#-512,d0		; align on sector boundary
			sub.l	d0,d1			; size to load(with begin align)
			addi.l	#511,d1			; size should be a sector count

			moveq	#9,d2
			lsr.l	d2,d1			; sector count
			lsr.l	d2,d0			; sector start
			move.w	d0,m_secStart(a6)
			move.w	d1,m_secCount(a6)
			rts

.notf:		lsr.w	#4,d0
			move.w	d0,-(a7)
			movea.l	a7,a1
			lea		.txt(pc),a0
			trap	#0
.txt:		dc.b	'File index %w does not exist!',0
			even

		
;-----------------------------------------------------------------		
; d0: screen number ( script.txt order )		
; a0: buffer to load
loadFileCustom:
			pea		(a0)
			bsr		getFSInfos
			move.l	(a7)+,a0
			
			lea		alignedDmaLoadAd(pc),a1
			move.l	a0,(a1)
			lea		nextFx(pc),a6
			move.l	a0,m_ad(a6)

			bsr		loadFileRaw
			lea		nextFx(pc),a6
			clr.l	m_ad(a6)
			rts
		


;-----------------------------------------------------------------		
; d0: screen number ( script.txt order )		
allocAndLoadFile:

			bsr		getFSInfos

			move.l	nextFx+m_size(pc),d0	; depacked block size to alloc
			bsr		nextEXEDoAlloc

			lea		nextFx(pc),a6
			move.l	nextEXEDepacked(pc),m_ad(a6)
			move.l	alignedDmaLoadAd(pc),a0

; input: 
;	nextFx struct properly filled
;	a0: loading address (with enough margin to depack)
loadFileRaw:
			lea		nextFx(pc),a6

		; start trackloader !!
			movem.w	m_secStart(a6),d0-d1
			bsr		trackLoadStart

		; now loading is running async, we could alloc a mem block for depacked data
		; and run the depacker in the main thread (depacker takes care or loading ptr)		
			move.l	alignedDmaLoadAd(pc),a1
			add.w	sectorOffset(pc),a1		; packed data ad
			move.l	m_ad(a6),a0

			btst.b	#7,m_flags(a6)		; file entry flags
			beq.s	.depack

		; stored file (unpacked) wait for disk io ends		
			movem.l	a0-a1,-(a7)
.wLoop:		move.w	(trackloaderVars+trkDecodedSecCount)(pc),d0
			beq.s	.loadOk
			bsr		MFMDecodeTrackCallback
			bra.s	.wLoop

.loadOk:	movem.l	(a7)+,a0-a1
			exg		a0,a1
			move.l	m_size(a6),d0
			bsr		fastMemMove
			bra.s	.over

		; run the depacker (packed data are loading async)
.depack:	bsr		mainThreadDepack

		; free tackloading buffers
.over:		moveq	#MEMLABEL_TRACKLOAD,d0
			bsr		freeMemLabel

			rts

getBlackboardAddr:
			lea		blackBoardBuffer(pc),a0
			rts

setNextFileId:
			lea		currentFile(pc),a0
			move.w	d0,(a0)
			rts

;-----------------------------------------------------------------		
loadNextFile:
			move.l	(nextFx+m_ad)(pc),d0
			bne		loadNextFileError

			move.w	currentFile(pc),d0
			bsr		allocAndLoadFile

			rts
		
		
ldos50Hz:	
			move.w	#$2000,$dff09c
			move.w	#$2000,$dff09c
			btst.b	#0,$bfdd00
			beq.s	.skipa

			movem.l	d0-a6,-(a7)
			move.w	bMusicPlay(pc),d0
			beq.s	.noMusic

			lea		$dff0a0,a6
			bsr		LSP_MusicPlayTick

			lea		musicTick(pc),a0
			addq.l	#1,(a0)

			; check if BMP changed in the middle of the music
			move.l	LSPInfos(pc),a0
			move.w	(a0),d0					; current music BPM
			cmp.w	LSPCurBpm(pc),d0
			beq.s	.noChg
			lea		LSPCurBpm(pc),a2
			move.w	d0,(a2)					; current BPM
			bsr		cia50HzInstall
.noChg:
			lea		LSP_DmaconIrq(pc),a0
			move.l	a0,$78.w
			move.b	#$19,$bfdf00			; start timerB, one shot
	
.noMusic:	bsr		trackLoaderTick

			movem.l	(a7)+,d0-a6
;			move.w	#0,$dff180
.skipa:		nop
			rte

LSP_DmaconIrq:
			move.w	#$2000,$dff09c
			btst.b	#1,$bfdd00
			beq.s	.skipb
			move.w	LSPDmaCon(pc),$dff096
			pea		ldos50Hz(pc)
			move.l	(a7)+,$78.w
.skipb:		nop
			rte


ispSet:		lea		.supervisor(pc),a0
			move.l	a0,$80.w
			trap	#0
			lea		assertVector(pc),a0
			move.l	a0,$80.w
			rts

.supervisor:
			; set SSP
			move.l	pSuperStack(pc),a0	; TRAP #xx is a 4 words stack frame on >= 68020
			move.l	4(a7),-(a0)			; so copy 8 bytes of stack frame (680x0 fix!)
			move.l	(a7),-(a0)
			move.l	a0,a7
			rte

vectorSet:				
			; set both user & supervisor stack
			lea		.supervisor(pc),a0
			move.l	a0,$80.w
			trap	#0
			rts			

.supervisor:
		; Set all suspicious interrupts to RTE intruction
			move.w	#$2700,sr				; disable any 68k interrupt		
			lea		unRTE(pc),a1
			lea		$30.w,a0
.fill:		move.l	a1,(a0)+
			cmpa.l	#$f0,a0
			bne.s	.fill
			
			moveq	#($30-$8)/4-1,d0
			lea		guruBootStrap(pc),a0
			lea		$8.w,a1
.set:		move.l	a0,(a1)+
			addq.w	#4,a0
			dbf		d0,.set
			lea		assertVector(pc),a0
			move.l	a0,$80.w
unRTE:		rte					; back to user land

			
pollVSync:	btst	#0,$dff005
			beq.s	pollVSync
.wdown:		btst	#0,$dff005
			bne.s	.wdown
			rts
		
			
systemInstall:
			; Always disable IRQ ( but keep DMA )
			move.w	#(1<<12)|(1<<6)|(1<<5)|(1<<4),$dff09a	; Disable DSKSync, Copper, VBL, Blitter
			move.w	#$5fff,$dff09c				; clear all int req		

			; wait any pending blitter op
.waitb:		btst	#6,$dff002
			bne.s	.waitb

			bsr		ispSet
			
			lea		kernelLibrary(pc),a0
			move.l	a0,(LDOS_BASE).w
			
			move.l	persistentChipAd(pc),d0
			bne.s	.skip						; if persistent chip memory is here, don't trash copper

			lea		copperListData(pc),a0
			bsr		installCopperList
			move.w	d0,$dff088					; start copper
			move.w	#$8000|(1<<7),$dff096		; switch ON COPPER DMA

			bsr.s	pollVSync
			move.w	#(1<<5)|(1<<7),$dff096					; switch OFF Sprite DMA & copper
			bsr		clearSprites
			
.skip:
			move.w	#$8000|(1<<4)|(1<<9),$dff096		; DMA disk enabled
			rts
			
cia50HzInstall:
		; install 50Hz CIA TimerA for LDOS_TICK (& music player)
		; input: d0 : BPM
			movem.l	d0-d1/a0,-(a7)
			move.w 	#(1<<13),$dff09a	; CIA interrupt
			lea		ldos50Hz(pc),a0
			move.l	a0,$78.w
			lea		$bfd000,a0
			move.b 	#$7f,$d00(a0)
			move.b 	#$10,$e00(a0)
			move.b 	#$10,$f00(a0)
			move.l	#1773447,d1			; PAL
			divu.w	d0,d1
			move.b	d1,$400(a0)
			lsr.w 	#8,d1
			move.b	d1,$500(a0)
			move.b	#$83,$d00(a0)
			move.b	#$11,$e00(a0)
			
			move.b	#496&255,$600(a0)		; set timer b to 496 ( to set DMACON )
			move.b	#496>>8,$700(a0)

			move.w 	#(1<<13),$dff09c		; clear any req CIA
		
			move.w 	#$8000|(1<<13),$dff09a	; CIA interrupt enabled
			movem.l	(a7)+,d0-d1/a0
			rts

clearSprites:
			lea		$dff140,a0
			moveq	#8-1,d0			; 8 sprites to clear
			moveq	#0,d1
.clspr:		move.l	d1,(a0)+
			move.l	d1,(a0)+
			dbf		d0,.clspr
			rts
		
guruBootStrap:
		rept	(($30-$8)/4)
			bsr.w	guruMeditation
		endr
		
guruMeditation:
			move.w	#$7fff,$dff096
			move.w	#$7fff,$dff09a
			move.l	a6,DEBUG_SCREEN_AD		
			move.l	(a7)+,DEBUG_BSS_ZONE+dbg_iVector				; to get the vector id (bsr)					
			lea		DEBUG_REGS_ZONE,a6
			move.l	2(a7),(a6)+		; PC
			move.w	(a7),(a6)+		; SR
			move.l	d0,(a6)+
			move.l	a0,(a6)+
			move.l	d1,(a6)+
			move.l	a1,(a6)+
			move.l	d2,(a6)+
			move.l	a2,(a6)+
			move.l	d3,(a6)+
			move.l	a3,(a6)+
			move.l	d4,(a6)+
			move.l	a4,(a6)+
			move.l	d5,(a6)+
			move.l	a5,(a6)+
			move.l	d6,(a6)+
			move.l	DEBUG_SCREEN_AD,(a6)+
			move.l	d7,(a6)+
			move.l	a7,(a6)+
			move.l	usp,a0
			move.l	a0,(a6)+		; usp
			
			bsr		debugScreenSetup
		
		; get the vector number
			lea		guruBootStrap(pc),a0
			move.l	DEBUG_BSS_ZONE+dbg_iVector,d0
			sub.l	a0,d0
			subq.w	#4,d0
			lsr.w	#2,d0
			addq.w	#2,d0
			move.w	d0,DEBUG_BSS_ZONE+dbg_iVector
			move.w	d0,-(a7)

		; print vector number
			lea		.crTxt(pc),a0
			lea		DEBUG_BSS_ZONE+dbg_iVector,a1
			bsr		debugScreenPrint
		
		; print vector name
			move.w	(a7)+,d0
			subq.w	#2,d0
			cmpi.w	#9,d0
			bgt.s	.nog
			add.w	d0,d0
			lea		.eTable(pc),a1
			lea		.e02(pc),a0
			add.w	0(a1,d0.w),a0
			bsr		debugScreenPrint

.nog:		lea		.regDump(pc),a0
			lea		DEBUG_REGS_ZONE,a1
			bsr		debugScreenPrint

			move.l	DEBUG_REGS_ZONE+16*4+2,d0
			andi.l	#$00fffffe,d0
			move.l	d0,DEBUG_BSS_ZONE+dbg_iVector
			move.l	d0,-(a7)
			lea		.iMemDump0(pc),a0
			lea		DEBUG_BSS_ZONE+dbg_iVector,a1
			bsr		debugScreenPrint
		
			lea		.iMemDump1(pc),a0
			move.l	(a7)+,a1
			bsr		debugScreenPrint
	
			move.l	DEBUG_REGS_ZONE+17*4+2,d0
			andi.l	#$00fffffe,d0
			move.l	d0,DEBUG_BSS_ZONE+dbg_iVector
			move.l	d0,-(a7)
			lea		.iMemDump0(pc),a0
			lea		DEBUG_BSS_ZONE+dbg_iVector,a1
			bsr		debugScreenPrint
		
			lea		.iMemDump1(pc),a0
			move.l	(a7)+,a1
			bsr		debugScreenPrint

.infLoop:	bra.s	.infLoop

.crTxt:		dc.b	'LDOS Kernel Exception vector $%w',10,0

.regDump:
.iDump:		dc.b	10
			dc.b	'PC : $%l   SR : $%w',10
			dc.b	10
			dc.b	'D0 : $%l   A0 : $%l',10
			dc.b	'D1 : $%l   A1 : $%l',10
			dc.b	'D2 : $%l   A2 : $%l',10
			dc.b	'D3 : $%l   A3 : $%l',10
			dc.b	'D4 : $%l   A4 : $%l',10
			dc.b	'D5 : $%l   A5 : $%l',10
			dc.b	'D6 : $%l   A6 : $%l',10
			dc.b	'D7 : $%l   A7 : $%l',10
			dc.b	'                USP : $%l',10
			dc.b	10
			dc.b	0

.iMemDump0:	dc.b	'Memory dump at $%l:',10
			dc.b	0
.iMemDump1:	dc.b	'%w %w %w %w %w %w %w %w',10
			dc.b	'%w %w %w %w %w %w %w %w',10
			dc.b	'%w %w %w %w %w %w %w %w',10
			dc.b	'%w %w %w %w %w %w %w %w',10,10
			dc.b	0
			even
			
.eTable:	dc.w	.e02-.e02
			dc.w	.e03-.e02
			dc.w	.e04-.e02
			dc.w	.e05-.e02
			dc.w	.e06-.e02
			dc.w	.e07-.e02
			dc.w	.e08-.e02
			dc.w	.e09-.e02
			dc.w	.e10-.e02
			dc.w	.e10-.e02

.e02:		dc.b	'Bus error',10,0
.e03:		dc.b	'Address error',10,0
.e04:		dc.b	'Illegal instruction',10,0
.e05:		dc.b	'Division by zero',10,0
.e06:		dc.b	'CHK instruction',10,0
.e07:		dc.b	'TRAPV instruction',10,0
.e08:		dc.b	'Privilege violation',10,0
.e09:		dc.b	'Trace',10,0
.e10:		dc.b	'Unimplemented instruction',10,0
			even

assertVector:
			movem.l	a0-a1,-(a7)
			move.w	#$7fff,$dff096
			move.w	#$7fff,$dff09a
			
			bsr		debugScreenSetup

			lea		.txtAssert(pc),a0
			bsr		debugScreenPrint
	
			movem.l	(a7)+,a0-a1
			bsr		debugScreenPrint
			
.infl:		bra.s	.infl
			
.txtAssert:	dc.b	'LDOS Kernel User ASSERT:',10,0
			even

	
crcCompute:		movem.l	d1-d4/a0-a2,-(a7)
				lea		crcProceedInfo(pc),a0
				lea		kernelStart(pc),a1
				moveq	#0,d4
.loop1:			move.w	(a0)+,d1			; offset
				bmi.s	.over
				lea		0(a1,d1.w),a2
				move.w	(a0)+,d2			; size
				moveq	#0,d3				; CRC
				lsr.w	#1,d2
				subq.w	#1,d2
.count:			add.w	(a2)+,d3
				dbf		d2,.count
				
				tst.w	d0
				bne.s	.set
			; check
				cmp.w	(a0),d3
				bne.s	.bad
				
.set:			move.w	d3,(a0)+
				addq.w	#1,d4
				bra.s	.loop1
.over:			movem.l	(a7)+,d1-d4/a0-a2
				rts

.bad:			move.w	d4,-(a7)
				move.l	a7,a1
				lea		.txt(pc),a0
				trap	#0
.txt:			dc.b	'Kernel CRC Error',10,'(block %w)',0
				even


loadNextFileError:				
		lea		.err(pc),a0
		trap	#0
.err:	dc.b	'loadNextFile called several times',0
		even

				
kernelCrcEnd:	
	
	;-------------------------------------------------------------------				
	; Memory Allocator
	;-------------------------------------------------------------------					
		include "memoryAllocator.asm"
				
	;-------------------------------------------------------------------				
	; Track Loader
	;-------------------------------------------------------------------					
		include	"trackLoader.asm"

	;-------------------------------------------------------------------				
	; Relocation routines
	;-------------------------------------------------------------------					
		include	"relocator.asm"

	;-------------------------------------------------------------------				
	; screen output debug routines
	;-------------------------------------------------------------------					
		include	"debug_screen.asm"
		
	;-------------------------------------------------------------------				
	; ARJ mode 7 depacker 
	;-------------------------------------------------------------------				
		include "arj7.asm"

	;-------------------------------------------------------------------				
	; Light Speed Module Player
	;-------------------------------------------------------------------				
		include	"LightSpeedPlayer.asm"

blackBoardBuffer:	dcb.b	LDOS_BLACKBOARD_SIZE,0

crcProceedInfo:
		dc.w	kernelCrcStart-kernelStart, kernelCrcEnd-kernelCrcStart,0
		dc.w	arjCrcStart-kernelStart, arjCrcEnd-arjCrcStart,0
		dc.w	loaderCrcStart-kernelStart, loaderCrcEnd-loaderCrcStart,0
		dc.w	relocCrcStart-kernelStart, relocCrcEnd-relocCrcStart,0
		dc.w	memoryCrcStart-kernelStart, memoryCrcEnd-memoryCrcStart,0
		dc.w	debugScreenCrcStart-kernelStart, debugScreenCrcEnd-debugScreenCrcStart,0
		dc.w	directory-kernelStart
fatSize:	dc.w	0,0				; hacky: fatsize is patched at begin

		dc.w	-2			; end marker
		
dynamicAllocs:
; this struct is patched by FUNC_CHIP_BATCH_ALLOC
systemChipBase:		dc.l	$100			; this is the first CHIP alloc by kernel, so if it fall to $0, keep $100 space for cpu vectors
pCopperList1:		dc.l	1024
pCopperList2:		dc.l	1024
pKernelBase:		dc.l	0|LDOS_MEM_ANY_RAM
pUserStack:			dc.l	LDOS_USERSTACK_SIZE|LDOS_MEM_ANY_RAM
pSuperStack:		dc.l	LDOS_SUPERSTACK_SIZE|LDOS_MEM_ANY_RAM
					dc.l	-2

	rsreset
	
; nextFx struct
m_ad:				rs.l	1
m_size:				rs.l	1
m_packedSize:		rs.l	1
m_flags:			rs.w	1
m_arg:				rs.w	1
m_secStart:			rs.w	1
m_secCount:			rs.w	1
m_argd1:			rs.l	1
m_nextFxSize:		rs.w	0
					
diskOffset:			ds.l	1
currentFile:		dc.w	0
nextFx:				dcb.b	m_nextFxSize,0
LSMusic:			dc.l	0
LSBank:				dc.l	0
LSPInfos:			dc.l	0
LSPCurBpm:			dc.w	0
LSPDmaCon:			dc.w	$8000
sectorOffset:		ds.w	1
bMusicPlay:			dc.w	0
musicTick:			dc.l	0
clockTick:			dc.l	0

	rsreset

copperListData:
		dc.l	$01fc0000
		dc.l	$01000200
		dc.l	-2

persistentChipAd:	dc.l	0
persistentChipSize:	dc.l	0
persistentFakeAd:	dc.l	0
persistentFakeSize:	dc.l	0

nextEXEDepacked:	dc.l	0
alignedDmaLoadAd:	dc.l	0

nextEXEAllocs:
pMFMRawBuffer:		dc.l	0	;MFM_DMA_SIZE
pArj7Buffer:		dc.l	0	;13320 | LDOS_MEM_ANY_RAM		; ARJ Method 7 depacking buffer
					dc.l	-2


		
directory:		; NOTE: Directory data are directly appended here by the installer
kernelEnd:

	
