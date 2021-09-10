;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Memory Allocator
;
;---------------------------------------------------------



		include	"kernelPrivate.inc"

		
memoryCrcStart:	

; input: A0 array of 32bits of size + RAM type ( ends with "-2" value )
batchAllocator:
			movem.l	d0-a6,-(a7)

		; first total count each kind of mem
			lea		_chipInfo(pc),a2
			clr.l	(a2)+
			clr.l	(a2)+
			movea.l	a0,a1
.count:		move.l	(a1)+,d0
			bmi.s	.next
			lea		_chipInfo(pc),a2
			btst	#LDOS_MEM_ANY_RAM_BIT,d0
			beq.s	.noAny1
			lea		_fastInfo(pc),a2
.noAny1:	addq.l	#7,d0						; size aligned on 8 bytes
			andi.l	#MEM_SIZE_MASK,d0
			add.l	d0,(a2)
			bra.s	.count
			
			; do one alloc only for each kind of RAM
.next:		lea		_chipInfo(pc),a2
			move.l	(a2)+,d0			; chip size requested
			beq.s	.noNeed1
			bsr		allocChipMem
			move.l	d0,-4(a2)
.noNeed1:	move.l	(a2)+,d0			; fast size requested
			beq.s	.noNeed2
			bsr		allocAnyMem
			move.l	d0,-4(a2)
.noNeed2:				

			; and then patch the caller array with valid pointers
.patchLoop:	move.l	(a0)+,d1
			bmi.s	.end
			lea		_chipInfo(pc),a2
			btst	#LDOS_MEM_ANY_RAM_BIT,d1
			beq.s	.noAny2
			lea		_fastInfo(pc),a2
.noAny2:	move.l	d1,d0
			addq.l	#7,d0					; size aligned on 8 bytes
			andi.l	#MEM_SIZE_MASK,d0
			btst	#LDOS_MEM_CLEAR_BIT,d1
			beq.s	.noClear
			move.l	(a2),a0
			bsr		fastClear
.noClear:	move.l	(a2),-4(a0)				; path with allocated address
			add.l	d0,(a2)
			bra.s	.patchLoop

.end:		movem.l	(a7)+,d0-a6
			rts
			
; a0: mem table
; d0: base ad
initMemTable:
		movea.l	a0,a1
		move.l	d0,(a1)+
		move.w	#MEMPAGE_COUNT/4-1,d0
.clr:	clr.l	(a1)+
		dbf		d0,.clr
		rts

; d0: size
allocChipMem:
		move.w	d1,-(a7)
		move.b	(SVAR_CURRENT_MEMLABEL).w,d1
		bsr.s	allocChipMemLabel
		move.w	(a7)+,d1
		rts
		
allocChipMemLabel:
		movem.l	d2-a6,-(a7)
		lea		chipMemTable(pc),a0
		bsr		allocMemoryExt
		tst.l	d0
		bmi		mallocError
		movem.l	(a7)+,d2-a6
		rts
		
allocAnyMem:
		move.w	d1,-(a7)
		move.b	(SVAR_CURRENT_MEMLABEL).w,d1
		bsr.s	allocAnyMemLabel
		move.w	(a7)+,d1
		rts

allocAnyMemLabel:
		movem.l	d2-a6,-(a7)
		move.l	d0,-(a7)
		lea		fastMemTable(pc),a0
		bsr		allocMemoryExt
		tst.l	d0
		bpl.s	.ok
		move.l	(a7),d0
		bsr		allocChipMemLabel
.ok:	addq.w	#4,a7
		tst.l	d0
		bmi		mallocError
		movem.l	(a7)+,d2-a6
		rts
	
; in	
; a0: src ad
; d0: size
; out
; d0 : new ad
allocAnyMemCopy:
		pea		(a1)
		move.l	d0,-(a7)
		bsr		allocAnyMem
		move.l	d0,a1			; dst ad
		move.l	(a7)+,d0		; original size, a0=src is preserved
		bsr		fastMemcpy
		move.l	a1,d0
		move.l	(a7)+,a1
		rts

; in	
; a0: src ad
; d0: size
; out
; d0 : new ad
allocChipMemCopy:
		pea		(a1)
		move.l	d0,-(a7)
		bsr		allocChipMem
		move.l	d0,a1			; dst ad
		move.l	(a7)+,d0		; original size, a0=src is preserved
		bsr		fastMemcpy
		move.l	a1,d0
		move.l	(a7)+,a1
		rts
		
		
; really simple block allocator
; memory is made of 128 block of 4KiB each
; linear search consecutive free memory block		
; d0: size
; a0: memtable
allocMemoryExt:
		addi.l	#MEMPAGE_SIZE-1,d0
		moveq	#MEMPAGE_SIZE_BIT,d2
		lsr.l	d2,d0				; consecutive page count
		moveq	#0,d2				
		moveq	#0,d3
		move.l	(a0)+,d4			; base ad
		move.l	a0,a1
		move.w	#MEMPAGE_COUNT-1,d3
.loop1:	tst.b	(a0)+			; -1 for post inc
		bne.s	.busy
		addq.w	#1,d2				; one more consecutive block
		cmp.w	d2,d0				; did we get the size?
		bne.s	.next
		bra.s	.found
.busy:	moveq	#0,d2				; reset consecutive block to 0 if busy block
.next:	dbf		d3,.loop1
		moveq	#-1,d0				; no more memory!
		rts
.found:	sub.w	d2,a0				; begin
		move.l	a0,d0
		sub.l	a1,d0				; id page start
		moveq	#MEMPAGE_SIZE_BIT,d3
		lsl.l	d3,d0
		add.l	d4,d0				; base ad	
		subq.w	#1,d2
.fill:	move.b	d1,(a0)+			; write label on all blocks
		dbf		d2,.fill
		rts

; input: d0: size in bytes
allocPersistentChip:

			movem.l	d1-a6,-(a7)
			lea		chipMemTable(pc),a0
			addi.l	#MEMPAGE_SIZE-1,d0
			moveq	#MEMPAGE_SIZE_BIT,d2
			lsr.l	d2,d0				; consecutive page count

			move.l	(a0)+,d4				; base ad
			lea		MEMPAGE_COUNT(a0),a1	; end of memory map (persistent is allocated from top)
.search:	tst.b	-(a1)
			bne.s	.memError
			move.b	#MEMLABEL_PERSISTENT_CHIP,(a1)
			subq.w	#1,d0
			beq.s	.found
			cmpa.l	a0,a1
			bne.s	.search
.memError:	lea		.txt(pc),a0
			trap	#0

.found:		suba.l	a0,a1				; page count
			move.l	a1,d0
			lsl.l	d2,d0
			add.l	d4,d0				; final Ad
			movem.l	(a7)+,d1-a6
			rts
		
.txt:		dc.b	'Persistent CHIP alloc fail',0
			even

		
trashPersistentChip:
		movem.l	d0/a0,-(a7)
		moveq	#MEMLABEL_PERSISTENT_CHIP,d0
		lea		chipMemTable(pc),a0
		bsr.s	freeMemLabelExt
		movem.l	(a7)+,d0/a0
		rts
		
; d0.b: memory label to release		
freeMemLabel:
		movem.l	d0-a6,-(a7)
		lea		chipMemTable(pc),a0
		bsr.s	freeMemLabelExt
		lea		fastMemTable(pc),a0
		bsr.s	freeMemLabelExt
		movem.l	(a7)+,d0-a6
		rts

; d0: label
; a0: memtable
freeMemLabelExt:
		move.l	(a0)+,a1		; base
	IF MEM_ALLOCATOR_DEBUG
	{
		move.l	#$cdcdcdcd,d2
	}
		move.w	#MEMPAGE_COUNT-1,d1
.loop:	cmp.b	(a0)+,d0
		bne.s	.next
		clr.b	-1(a0)
	IF MEM_ALLOCATOR_DEBUG
	{
		move.w	#MEMPAGE_SIZE/16-1,d3
		movea.l	a1,a2
.clear:	move.l	d2,(a2)+
		move.l	d2,(a2)+
		move.l	d2,(a2)+
		move.l	d2,(a2)+
		dbf		d3,.clear
	}
.next:	lea		MEMPAGE_SIZE(a1),a1
		dbf		d1,.loop
		rts

; d0.b: memory label to release		
unmarkMemLabel:
		movem.l	d0-a6,-(a7)
		lea		chipMemTable(pc),a0
		bsr.s	unmarkMemLabelExt
		lea		fastMemTable(pc),a0
		bsr.s	unmarkMemLabelExt
		movem.l	(a7)+,d0-a6
		rts
		
; d0: label
; a0: memtable
unmarkMemLabelExt:
		addq.w	#4,a0				; skip base ad
		move.w	#MEMPAGE_COUNT-1,d1
.loop:	cmp.b	(a0)+,d0
		bne.s	.next
		clr.b	-1(a0)
.next:	dbf		d1,.loop
		rts


; a0: ad
; d0: size (in bytes)
; return: d0: real free size
freeMemoryArea:
			lea		chipMemTable(pc),a1
			cmp.l	(a1),a0
			blt.s	.noChip
			move.l	(a1),d1
			addi.l	#MEMBANK_SIZE,d1
			cmp.l	a0,d1
			blt.s	.noChip
			
			bsr		freeBankMemoryArea
			bra.s	.over
			
.noChip:	lea		fastMemTable(pc),a1
			cmp.l	(a1),a0
			blt.s	.merror
			move.l	(a1),d1
			addi.l	#MEMBANK_SIZE,d1
			cmp.l	a0,d1
			blt.s	.merror
			
			bsr		freeBankMemoryArea
.over:
			rts
		
.merror:	lea		.txt(pc),a0
			trap	#0
.txt:		dc.b	'MemoryFreeArea out of range',0
			even
			
			
		
		
; a0: ad
; d0: size (in bytes)
; a1: memtable
; return: d0: real free size
freeBankMemoryArea:
		movem.l	d1/a6,-(a7)
		move.l	a0,d1
		sub.l	(a1)+,d1				; offset in bank
		move.l	d1,d2
		add.l	d0,d2					; end offset
		addi.l	#MEMPAGE_SIZE-1,d1
		moveq	#MEMPAGE_SIZE_BIT,d3
		lsr.l	d3,d1					; start block id
		lsr.l	d3,d2
		sub.l	d1,d2					; block count to do
		beq.s	.none
		move.w	d2,d4
		subq.w	#1,d4
		add.w	d1,a1
.loop:	clr.b	(a1)+
		dbf		d4,.loop
.none:	lsl.l	d3,d2					; real free size
		move.l	d2,d0
		movem.l	(a7)+,d1/a6
		rts
		
		
		
		
mallocError:	lea		.txt(pc),a0
				pea		fastMemTable(pc)
				pea		chipMemTable(pc)
				movea.l	a7,a1
				trap	#0						; assert
.txt:			dc.b	'MALLOC ERROR!',10
				dc.b	'Chip Table: $%l',10
				dc.b	'Fake Table: $%l',10
				dc.b	0
				even

memoryCrcEnd:

				
_chipInfo:	ds.l	1
_fastInfo:	ds.l	1
			
chipMemTable:
		dc.l	-1				; base ad
		ds.b	MEMPAGE_COUNT	; 512KiB (4KiB pages)

fastMemTable:
		dc.l	-1				; base ad
		ds.b	MEMPAGE_COUNT	; 512KiB (4KiB pages)
