;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/lz4-68k
;
;---------------------------------------------------------

;input: 	a0: packed data buffer
;			a1: output buffer
;
;output:	none

lz4_frame_depack:	

		cmpi.l	#$04224d18,(a0)+	; LZ4 frame MagicNb
		bne		lz4_frame_error

		move.b	(a0),d0
		andi.b	#%11001001,d0		; check version, no depacked size, and no DictID
		cmpi.b	#%01000000,d0
		bne		lz4_frame_error

		; read 24bits only block size without movep (little endian)
		move.b	6(a0),d0
		lsl.w	#8,d0
		move.b	5(a0),d0
		swap	d0
		move.b	4(a0),d0
		lsl.w	#8,d0
		move.b	3(a0),d0

		lea		7(a0),a0			; skip LZ4 block header + packed data size

		include "lz4_normal.asm"

lz4_frame_error:	lea		.txt(pc),a0
					trap	#0
.txt:				dc.b	'Bad LZ4 data',0
					even
