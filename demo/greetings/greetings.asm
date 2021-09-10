       
;
; We Were @ greetings part fast amiga convert to make Amiga LDOS sample code
;

SCREENW					=	320+16
SCREENH					=	272
PLANCOUNT				=	4
LINE_PITCH              =   SCREENW/8 

	code


		include "../../ldos/kernel.inc"

			bsr		blitterWait
            bsr     chunkyToPlanar
            bsr     setupPalettes

        ; install interrupt handler to animate sprites
			bsr		pollVSync		
			move.w	#(1<<5),$dff09a			; disable VBL
			move.w	#(1<<5),$dff09c
			lea		copperDummy,a0
			bsr		copperInstall
			move.l	#InterruptLevel3,$6c.w		;ma vbl
			move.w	#$8000|(1<<6)|(1<<7)|(1<<8)|(1<<10),$dff096	; Blitter, Copper, Bitplans, Nasty Bit
			move.w	#$c000|(1<<4),$dff09a		;interruption copper


mainLoop:
         


            bra.s   mainLoop

            

InterruptLevel3:
			btst	#4,$dff01f
			beq.s	.intError

			movem.l	d0-a6,-(a7)

            sf      d6
			cmpi.w	#(1248+320+16)/8,xWinPos
			beq.s	.noinc
            addi.l  #(1<<16)/1,xShift
.noinc:     move.w  xShift(pc),d0         ; xPos
            cmpi.w  #16,d0
            blt     .skip
            subi.w  #16,d0
            move.w  d0,xShift
            addq.w  #2,xWinPos
            
            st      d6
            
.skip:      moveq   #0,d7
            tst.w   d0
            bne.s   .notz
            moveq   #-2,d7
.notz:      neg.w   d0
            andi.w  #15,d0
            move.w  d0,d1
            lsl.w   #4,d1
            or.w    d1,d0
            move.w  d0,copSetScroll+2
            
            move.l  screenAd(pc),a0
            add.w   xWinPos(pc),a0
            add.w   d7,a0
            move.l  a0,d0
      
            moveq   #PLANCOUNT-1,d1
            lea     copScrSet,a1
.sloop:     move.w  d0,6(a1)
            swap    d0
            move.w  d0,2(a1)
            swap    d0
            addq.w  #8,a1
            addi.l  #LINE_PITCH,d0
            dbf     d1,.sloop

            ; update column
            tst.b   d6
            beq.s   .noUp
            move.w  xWinPos(pc),d0
            lsr.w   #1,d0               ; in column
            move.w  d0,d1
            add.w   #20,d1              ; update most right column
			subq.w	#1,d0
			cmpi.w	#1248/16,d0
			bge.s	.clear
            bsr     columnUpdate
			bra.s	.noUp
.clear:		bsr		columnClear			
.noUp:
            
			movem.l	(a7)+,d0-a6

.none:		move.w	#1<<4,$dff09c		;clear copper interrupt bit
			move.w	#1<<4,$dff09c		;clear VBL interrupt bit
			nop
			rte
			
.intError:	illegal
			
xShift:     dc.l    0
xWinPos:    dc.w    0
            
pollVSync:	btst	#0,$dff005
			beq.s	pollVSync
.wdown:		btst	#0,$dff005
			bne.s	.wdown
			rts

copperInstall:
			move.w	#(1<<7),$dff096		; swith OFF copper DMA
			move.l	a0,$dff080
			move.w	#($8000|(1<<7)),$dff096
			rts

blitterWait:
		tst.w	$dff002
.bltwt:	btst	#6,$dff002
		bne.s   .bltwt
		rts


chunkyToPlanar:
				lea		largePic,a0
				move.w	#(26*3*SCREENH)-1,d5				
.cLoop:			
				rept    4
					move.w	(a0)+,d4		; 4 chunky pixels
					rept    4
						add.w	d4,d4
						addx.w	d3,d3
						add.w	d4,d4
						addx.w	d2,d2
						add.w	d4,d4
						addx.w	d1,d1
						add.w	d4,d4
						addx.w	d0,d0
                    endr
                endr
				movem.w	d0-d3,-8(a0)
				dbf		d5,.cLoop
				rts


setupPalettes:
                lea     palettes,a0
                lea     copPalPatch,a1
                move.w  #SCREENH-1,d0
                move.l  #($1f<<24)|($dffffe),d2     ; copper wait end of line instruction
.yloop:         move.l  d2,(a1)+
                moveq   #16-1,d3
.cloop:         move.w  (a0)+,d4                    ; atari STE color
                move.w  d4,d5
                andi.w  #$777,d4
                andi.w  #$888,d5
                lsr.w   #3,d5
                add.w   d4,d4
                or.w    d4,d5
                move.w  d5,2(a1)
                addq.w  #4,a1
                dbf     d3,.cloop
                addi.l  #$01000000,d2
                dbf     d0,.yloop
                rts


; d0: input big picture column
; d1: output screen column 
columnUpdate:

            movem.l d0-d4/a0-a1,-(a7)
            lea     largePic,a0
            lea     screenBuffer,a1

            lsl.w   #3,d0
            add.w   d0,a0
            
            add.w   d1,d1
            add.w   d1,a1
            
            move.w  #SCREENH-1,d4
.yloop:            
            movem.w (a0)+,d0-d3        ; 4 plans
            move.w  d0,(a1)
            move.w  d1,LINE_PITCH*1(a1)
            move.w  d2,LINE_PITCH*2(a1)
            move.w  d3,LINE_PITCH*3(a1)
            lea     (1248/2-8)(a0),a0
            lea     LINE_PITCH*PLANCOUNT(a1),a1
            dbf     d4,.yloop
            movem.l (a7)+,d0-d4/a0-a1
            rts
            
; d1: output screen column 
columnClear:
            movem.l d0-d4/a0-a1,-(a7)
            lea     screenBuffer,a1
            add.w   d1,d1
            add.w   d1,a1
            
            move.w  #SCREENH-1,d4
			moveq	#0,d0
.yloop:     move.w  d0,(a1)
            move.w  d0,LINE_PITCH*1(a1)
            move.w  d0,LINE_PITCH*2(a1)
            move.w  d0,LINE_PITCH*3(a1)
            lea     LINE_PITCH*PLANCOUNT(a1),a1
            dbf     d4,.yloop
            movem.l (a7)+,d0-d4/a0-a1
            rts



screenAd:   dc.l    screenBuffer

        data

largePic:
			incbin	"large_pic.bin"
			even

palettes:
			incbin	"large_pic.pal"
			even


				; CHIP Memory					
	data_c
		
copperDummy:	dc.l	$01fc0000

				; screen 320*256
				dc.l	$008e2081
				dc.l	$009030c1
				dc.l	$00920030   ; fetch one column more left (fullscreen) to allow smooth pixel scrolling
				dc.l	$009400d0				
				dc.l	$01020000
				dc.l	$01040000	; $24: HW sprite priority over playfield
				dc.l	$01060000
				dc.l	$01080000|((PLANCOUNT*LINE_PITCH)-(LINE_PITCH))
				dc.l	$010a0000|((PLANCOUNT*LINE_PITCH)-(LINE_PITCH))
				dc.l	$01000200|(PLANCOUNT<<12)

				dc.l	$009c8000|(1<<4)		; fire copper interrupt

				dc.l	($1e<<24)|($09fffe)      ; wait few lines so CPU has time to patch copper list
copScrSet:      dc.l    $00e00000
                dc.l    $00e20000
                dc.l    $00e40000
                dc.l    $00e60000
                dc.l    $00e80000
                dc.l    $00ea0000
                dc.l    $00ec0000
                dc.l    $00ee0000
copSetScroll:   dc.l    $01020000

copPalPatch:
                rept    SCREENH
                    dc.l	($1f<<24)|($dffffe)      ; wait few lines so CPU has time to patch copper list
                    dc.l    $01800000
                    dc.l    $01820000
                    dc.l    $01840000
                    dc.l    $01860000
                    dc.l    $01880000
                    dc.l    $018a0000
                    dc.l    $018c0000
                    dc.l    $018e0000
                    dc.l    $01900000
                    dc.l    $01920000
                    dc.l    $01940000
                    dc.l    $01960000
                    dc.l    $01980000
                    dc.l    $019a0000
                    dc.l    $019c0000
                    dc.l    $019e0000
                endr
                
				dc.l	-2


        bss


        bss_c

screenBuffer:   ds.b    LINE_PITCH*SCREENH*PLANCOUNT
                ds.b    64*1024         ; some safety margin
