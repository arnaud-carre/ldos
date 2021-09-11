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

LDOS_VERSION				=	102

LDOS_BASE					=	$4
LDOS_MUSIC_PLAYER_ENABLED	=	1


; Pre-load & depack the next FX. Once the current FX end (using RTS) the next one
; is executed immediatly.
; NOTE: if you don't pre-load, next FX will be loaded & depacked once the previous one ends
LDOS_PRELOAD_NEXT_FX		=	0*4

; Wait for LDOS VBlank
LDOS_WAIT_VBLANK			=	1*4

; Install your own VBL handler ( should ends with RTS and not RTE )
; NOTE: you can override your own level3 interrupt in $6c if you don't want to use LDOS handler
LDOS_INSTALL_VCALLBACK		=	2*4

; Allocate several memory pointers
; NOTE: Internal use only. Each FX should use data or bss section instead of dynamic memory allocation
LDOS_MEMORY_BATCH_ALLOC		=	3*4

; Internal use only
LDOS_INSTALL_COPPERL		=	4*4

; LZ4 fast depack
; in : a0.l : LZ4 packed data
;      a1.l : LZ4 depacked data buffer
; Note: you can use depack in place, a1 should be at least 64 bytes after a0 (yeah 64bytes is enough!!)
LDOS_FAST_DEPACK			=	5*4

; Returns demo frame counter in d0.w
; NOTE: counter isn't incremented if you're overriding $6c level3 interrupt
LDOS_GET_FRAME_COUNTER		=	6*4

; Stop the demo and display ASSERT message (debugging purpose)
; a0: text message to display
LDOS_ASSERT					=	7*4

; Start music if already loaded
LDOS_MUSIC_START			=	8*4

; Get music position
; returns pos & rowpos in d0.w & d1.w
LDOS_MUSIC_GET_POSITION 	=	9*4

; Stop music playing
LDOS_MUSIC_STOP				=	10*4

; Check if demo disk 2 is inserted or not
; out : d0.b: $ff if disk 2 inserted, $00 if not
LDOS_IS_DISK2_INSERTED		=	11*4

; Alloc persistent CHIP memory block between two FX
; in : d0.l: size of block
; out: d0.l: Addr of the block
LDOS_PERSISTENT_CHIP_ALLOC	=	12*4

; Retreive any previously persistent CHIP memory block between two FX
; in : none
; out: d0.l: Addr of block ( or NULL if no persistent block)
;	   d1.l: Size of block ( in bytes )
LDOS_PERSISTENT_CHIP_GET	=	13*4

; Free any previously persistent CHIP memory block
; in : none
; out: none
LDOS_PERSISTENT_CHIP_TRASH	=	14*4

; Internal use only, don't use
LDOS_SET_KERNEL_BPM			=	15*4
LDOS_FREE_MEMORY_AREA		=	16*4
LDOS_MUSIC_SET_POSITION_IN_SYNC 	=	17*4

; Load binary blob
; in : d0.w: file id (same order as your script.txt)
; out: a0.l: allocated & loaded file buffer
;    : d0.l: file size
LDOS_LOAD_BINARY_BLOB				=	18*4

; Returns a pseudo random entropy number. You can use as a seed to PRNG
; out: d0.w: pseudo random number
LDOS_GET_ENTROPY					=	19*4

; In case you need to shut down the LDOS 50Hz tick CIA timer,
; you have to call this each frame if you want to trackload
; WARNING: Trash all registers
LDOS_TRACKLOADER_FRAME_TICK			=	20*4


LDOS_MEM_ANY_RAM		=	(1<<30)
LDOS_MEM_CLEAR			=	(1<<29)
