;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Relocation code
;
;---------------------------------------------------------


MAX_HUNKS	=	32


relocCrcStart:


amigaReloc:
				
			lea		-m_relocSizeof(a7),a7
			movea.l	a7,a6

		; parse Amiga EXE header
			lea		(nextFx+m_ad)(pc),a1
			move.l	(a1),a0
			clr.l	(a1)				; clear nextRunAd so the next hunkCode could set the right pointer
			cmpi.l	#$3f3,(a0)+
			bne		relocError
			tst.l	(a0)+				; string must be empty
			bne		relocError
			move.l	(a0)+,d0			; hunk count
			beq		relocError
			cmpi.l	#MAX_HUNKS,d0
			bge		relocError
			move.w	d0,m_relHunkCount(a6)
			addq.w	#8,a0				; skip first and last hunk id
			
		; now build a LDOS dynamic alloc request (to alloc everything in one go)
			lea		m_hunkAds(a6),a1
			lea		m_hunkClearSize(a6),a2
			subq.w	#1,d0
.tLoop:		move.l	(a0)+,d1
			move.l	#$00ffffff,d2
			and.l	d1,d2
			lsl.l	#2,d2					; DWORD to bytes
			btst	#30,d1
			bne.s	.chip
			ori.l	#LDOS_MEM_ANY_RAM,d2
.chip:		move.l	d2,(a1)+
			clr.l	(a2)+
			dbf		d0,.tLoop
			move.l	#-2,(a1)+				; end marker
			
		; Now allocate everything in one go			
			move.l	a0,-(a7)
			lea		m_hunkAds(a6),a0
			bsr		batchAllocator
			move.l	(a7)+,a0
			
		; browse all hunks, move each one to its new memory zone, and backup relocation tables
			clr.w	m_relHunkId(a6)
.hunkLoop:	move.w	m_relHunkId(a6),d0
			cmp.w	m_relHunkCount(a6),d0
			beq.s	.theEnd

			lsl.w	#2,d0
			lea		m_hunkAds(a6,d0.w),a5
			pea		.hunkLoop(pc)

			move.l	(a0)+,d1				; chunk id
			andi.l	#$3fffffff,d1
			cmpi.l	#$3e9,d1
			beq		hunkCode
			cmpi.l	#$3ea,d1
			beq		hunkData
			cmpi.l	#$3eb,d1
			beq		hunkBss			
			bra		relocError

			
.theEnd:	
			; clear BSS sections
			move.w	m_relHunkCount(a6),d7
			subq.w	#1,d7
			bmi.s	.empty
			lea		m_hunkAds(a6),a5
			lea		m_hunkClearSize(a6),a4
.bssClear:	move.l	(a4)+,d0
			beq.s	.nobc
			move.l	(a5),a0
			bsr		fastClear
.nobc:		addq.w	#4,a5
			dbf		d7,.bssClear
			
.empty:


			lea		m_relocSizeof(a7),a7
			rts
			
		
hunkCode:	
hunkData:	
			move.l	(a0)+,d0
			lsl.l	#2,d0
			move.l	(a5),a1
			cmpi.l	#$3e9,d1
			bne.s	.noCode
			lea		(nextFx+m_ad)(pc),a2
			tst.l	(a2)
			bne.s	.noCode
			move.l	a1,(a2)			
.noCode:	
		; WARNING: here we should always copy to lower ad ( dst < src )
			bsr		fastMemMove
			add.l	d0,a0

		; maybe reloc hunk here
			cmpi.l	#$3ec,(a0)
			bne.s	hunkExit
			addq.w	#4,a0

.offLoop:	move.l	(a0)+,d0					; offset count
			beq.s	hunkExit
			move.l	(a0)+,d1					; hunk number
			lsl.w	#2,d1
			move.l	m_hunkAds(a6,d1.w),d1		; hunk base
			subq.w	#1,d0
.pLoop:		move.l	(a0)+,d2
			add.l	d1,0(a1,d2.l)
			dbf		d0,.pLoop
			bra.s	.offLoop		
							
hunkExit:	cmpi.l	#$3f2,(a0)+
			bne		relocError
			addq	#1,m_relHunkId(a6)
			rts
			
hunkBss:	
			move.l	(a0)+,d0
			lsl.l	#2,d0						; size in bytes
			lea		m_hunkClearSize(a6),a1
			move.w	m_relHunkId(a6),d1
			lsl.w	#2,d1
			move.l	d0,0(a1,d1.w)
			bra.s	hunkExit

				
				rsreset
m_relHunkCount:		rs.w	1
m_relHunkId:		rs.w	1
m_hunkAds:			rs.l	MAX_HUNKS+1
m_hunkClearSize:	rs.l	MAX_HUNKS
m_relocSizeof:		rs.w	1
		

relocError:
			lea		.txt(pc),a0
			trap	#0
.txt:		dc.b	'RELOC Error',0
			even

			
; AMIGA Module relocation
; split data between music score data ( any ram ) and samples data (CHIP)
relocP61:
			illegal
			rts
			
relocCrcEnd:
