;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Public function library	
;
;---------------------------------------------------------

LDOS_VERSION				=	130

LDOS_BASE					=	$4
LDOS_MUSIC_PLAYER_ENABLED	=	1


; Pre-load & depack the next FX. Once the current FX end (using RTS) the next one
; is executed immediatly.
; NOTE: if you don't pre-load, next FX will be loaded & depacked once the previous one ends
LDOS_PRELOAD_NEXT_FX		=	0*4

; Stop the demo and display ASSERT message (debugging purpose)
; a0: text message to display
LDOS_ASSERT					=	1*4

; Start music if already loaded
LDOS_MUSIC_START			=	2*4

; Get LSP music frame tick 
; Use this counter if you want to sync gfx with music
; returns d0.l: music frame tick
LDOS_MUSIC_GET_TICK 		=	3*4

; Stop music playing
; Note: This also free music memory (so music won't play again if you LDOS_MUSIC_START)
LDOS_MUSIC_STOP				=	4*4

; Check if demo disk 2 is inserted or not
; out : d0.b: $ff if disk 2 inserted, $00 if not
LDOS_IS_DISK2_INSERTED		=	5*4

; Alloc persistent CHIP memory block between two FX
; in : d0.l: size of block
; out: d0.l: Addr of the block
LDOS_PERSISTENT_CHIP_ALLOC	=	6*4

; Retreive any previously persistent CHIP memory block between two FX
; in : none
; out: d0.l: Addr of block ( or NULL if no persistent block)
;	   d1.l: Size of block ( in bytes )
LDOS_PERSISTENT_CHIP_GET	=	7*4

; Free any previously persistent CHIP memory block
; in : none
; out: none
LDOS_PERSISTENT_CHIP_TRASH	=	8*4

; Load binary blob
; in : d0.w: file id (same order as your script.txt)
; out: a0.l: allocated & loaded file buffer
;    : d0.l: file size
LDOS_LOAD_BINARY_BLOB				=	9*4

; Returns a pseudo random entropy number. You can use as a seed to PRNG
; out: d0.w: pseudo random number
LDOS_GET_ENTROPY					=	10*4

; In case you need to shut down the LDOS 50Hz tick CIA timer,
; you have to call this each frame if you want to trackload
; WARNING: Trash all registers
LDOS_TRACKLOADER_FRAME_TICK			=	11*4

; out: d0.l 32bits clock counter
; This clock is incremented with internal 50hz-ish frequency.
; The frequency depends on ; the main music BPM. ( standard is 50hz if no music ).
; This counter is *not* synced to VBlank ( use your own VBL or Copper handler
; if you want VBL synced counter)
LDOS_GET_CLOCK_TICK					=	12*4

; Returns the current MOD music sequence position
; out: d0.w 16bits
LDOS_MUSIC_GET_SEQ_POS				=	13*4

; Alloc persistent FAKE memory block between two FX
; in : d0.l: size of block
; out: d0.l: Addr of the block
LDOS_PERSISTENT_FAKE_ALLOC			=	14*4

; Retreive any previously persistent FAKE memory block between two FX
; in : none
; out: d0.l: Addr of block ( or NULL if no persistent block)
;	   d1.l: Size of block ( in bytes )
LDOS_PERSISTENT_FAKE_GET			=	15*4

; Free any previously persistent FAKE memory block
; in : none
; out: none
LDOS_PERSISTENT_FAKE_TRASH			=	16*4

; Custom RAW (unpacked) file load
; in : d0: file id
;    : a0: buffer to load (WARNING: it's up to you to alloc enough space)
LDOS_LOAD_FILE_CUSTOM				=	17*4

; Force the next FX id. Could be nice if you want to load a previous FX
; Input d0.w : fx file id
;       d1.l : optional user argument passed to the next FX in d1
LDOS_SET_NEXT_FX_ID					=	18*4

LDOS_MEM_ANY_RAM		=	(1<<30)
LDOS_MEM_CLEAR			=	(1<<29)
