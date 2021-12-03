       
;
; very old and slow sprite anim to demonstrate LDOS loading & depacking
;

SCREENW					=	320
SCREENH					=	256
PLANCOUNT				=	3
MUSIC					=	0
CIA_PLAYER				=	0
SPRITE_COUNT            =   8
FRAME_COUNT             =   512
LINE_PITCH	            =	40		; 40 octets par ligne
PROFILING				=	0


Sp1			=		4
Sp2			=		6
Sp3			=		10
Sp4			=		8
Dp1			=		46*2
Dp2			=		48*2
Dp3			=		36*2
Dp4			=		40*2


	code


		include "../../ldos/kernel.inc"


			bsr		blitterWait

            bsr     InitSprites
            bsr     WaveCompute
            bsr     blitterInit
            bsr     setPalette
          

        ; install interrupt handler to animate sprites
			bsr		pollVSync		
			move.w	#(1<<5),$dff09a			; disable VBL
			move.w	#(1<<5),$dff09c
			lea		copperDummy,a0
			bsr		copperInstall
			move.l	#InterruptLevel3,$6c.w		;ma vbl
			move.w	#$8000|(1<<6)|(1<<7)|(1<<8)|(1<<10),$dff096	; Blitter, Copper, Bitplans, Nasty Bit
			move.w	#$c000|(1<<4),$dff09a		;interruption copper

			move.l	(LDOS_BASE).w,a6
			jsr		LDOS_MUSIC_START(a6)

        ; music is loaded, we now load & depack the next part ( simple scroll text to demonstrate )
			move.l	(LDOS_BASE).w,a6
			jsr		LDOS_PRELOAD_NEXT_FX(a6)
        
        
        ; we now can terminate this part by RTS. Next part will execute a start music command
       
            rts         ; end of this part
            
            
			
InterruptLevel3:
			btst	#4,$dff01f
			beq.s	.intError

		IFNE	PROFILING
			move.w	#7,copPal+2
		ENDC

			movem.l	d0-a6,-(a7)



            movem.l SCR1(pc),d1-d2
            move.l  d1,SCR2
            move.l  d2,SCR1

            move.l  SCR2(pc),d0
            moveq   #PLANCOUNT-1,d1
            lea     copScrSet,a1
.sloop:     move.w  d0,6(a1)
            swap    d0
            move.w  d0,2(a1)
            swap    d0
            addq.w  #8,a1
            addi.l  #LINE_PITCH,d0
            dbf     d1,.sloop


            bsr     spriteClear

            bsr     spriteRender
           

            addq.w  #1,frame
			
			movem.l	(a7)+,d0-a6

		IFNE	PROFILING
			move.w	#0,$dff180
		ENDC

.none:		move.w	#1<<4,$dff09c		;clear copper interrupt bit
			move.w	#1<<4,$dff09c		;clear VBL interrupt bit
			nop
			rte
			
.intError:	illegal
			
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

blitterInit:
			lea	$dff000,a6
			clr.w	$64(a6)			; Modulo pour A
			clr.w	$62(a6)			; Modulo pour B
			move.w	#LINE_PITCH-6,$60(a6)	; Modulo pour C
			move.w	#LINE_PITCH-6,$66(a6)	; Modulo pour D
			move.l	#-1,$44(a6)
            rts


InitSprites
		lea	SpriteMotif,a0
		lea	pSprite,a1
		lea	pMasque,a2
		moveq	#31,d5
.Loop2:	moveq	#2-1,d4
.Loop:	movem.w	(a0)+,d0-d3
		move.w	d0,(a1)
		move.w	d1,6(a1)
		move.w	d2,12(a1)
;		move.w	d3,18(a1)
		or.w	d0,d3
		or.w	d1,d3
		or.w	d2,d3
		not.w	d3
		move.w	d3,(a2)
		move.w	d3,6(a2)
		move.w	d3,12(a2)
;		move.w	d3,18(a2)
		lea	2(a2),a2
		lea	2(a1),a1
		dbf	d4,.Loop
		clr.w	(a1)
		clr.w	6(a1)
		clr.w	12(a1)
;		clr.w	18(a1)
		moveq	#-1,d3
		move.w	d3,(a2)
		move.w	d3,6(a2)
		move.w	d3,12(a2)
;		move.w	d3,18(a2)
		lea	18-4(a1),a1
		lea	18-4(a2),a2
		dbf	d5,.Loop2
		rts

WaveCompute		lea	    WaveForm,a5
				moveq	#0,d0
				moveq	#0,d1
				moveq	#0,d2
				moveq	#0,d3
				movem.w	d0-d3,Angles
				move.w	#FRAME_COUNT,-(a7)

.Loop1:			movem.w	Angles(pc),d0-d3
				move.w	#1024-1,d4
				add.w	#Sp1,d0
				add.w	#Sp2,d1
				add.w	#Sp3,d2
				add.w	#Sp4,d3
				and.w	d4,d0
				and.w	d4,d1
				and.w	d4,d2
				and.w	d4,d3
				movem.w	d0-d3,Angles

				lea		Cosinus,a0
				lea		1024(a0),a1
				moveq	#SPRITE_COUNT-1,d7
.Loop2:	        move.w	#1024-1,d4
				add.w	#Dp1,d0
				add.w	#Dp2,d1
				add.w	#Dp3,d2
				add.w	#Dp4,d3
				and.w	d4,d0
				and.w	d4,d1
				and.w	d4,d2
				and.w	d4,d3
				move.w	0(a0,d0.w),d4
				muls.w	#72,d4
				move.w	0(a0,d1.w),d5
				muls.w	#72,d5
				add.l	d5,d4
				add.l	d4,d4
				swap	d4
				move.w	0(a1,d2.w),d5
				muls.w	#51,d5
				move.w	0(a1,d3.w),d6
				muls.w	#51,d6
				add.l	d6,d5
				add.l	d5,d5				; Y
				swap	d5
				add.w	#144,d4
				add.w	#103,d5
				move.w	d4,(a5)+
				move.w	d5,(a5)+
				dbf		d7,.Loop2
				subq.w	#1,(a7)
				bne		.Loop1
                addq.w  #2,a7
                

Repasse:	    lea     WaveForm,a0
                move.l	#SPRITE_COUNT*FRAME_COUNT,d7

.Loop1:	        move.w	(a0),d0			; X
				move.w	d0,d2
				and.w	#15,d2			; dicalage
				lsr.w	#4,d0
				add.w	d0,d0			; Offset X
				move.w	2(a0),d1
				mulu.w	#(PLANCOUNT*LINE_PITCH),d1
				subi.l	#(SCREENH/2)*LINE_PITCH*PLANCOUNT,d1
				add.w	d0,d1			; Offset total signie
				move.w	d1,(a0)+
				ror.w	#4,d2			; 4 bits de poids fort pour blitter
				move.w	d2,(a0)+
				subq.l	#1,d7
				bne.s	.Loop1

				rts

Angles		    dc.w    0,0,0,0

setPalette	    lea		.palette(pc),a0
                lea		copPal,a1
                moveq	#8-1,d0
.Loop2:	        move.w	(a0)+,d1    ; atari palette :)
                add.w	d1,d1
                move.w	d1,2(a1)
                addq.w  #4,a1
                dbf	d0,.Loop2
                rts

.palette:		dc.w	$000,$777,$740,$520,$747,$605,$323,$555


spriteClear:

		move.w	frame(pc),d0
		subq.w	#2,d0
		andi.w	#FRAME_COUNT-1,d0
		mulu.w	#SPRITE_COUNT*4,d0
		lea     WaveForm,a0
		add.l	d0,a0

		move.l	SCR1(pc),a2
		lea	(SCREENH/2)*LINE_PITCH*PLANCOUNT(a2),a2	; milieu de l'ecran
		
			lea		$dff000,a6
			move.w	#$0100,$40(a6)
			move.w	#((31*3)<<6)+3,d2		; pour les masques
			moveq	#SPRITE_COUNT-1,d7
.clear:		movea.l	a2,a1
			add.w 	(a0),a1
			addq.w	#4,a0
.waitB:		btst	#6,2(a6)
			bne.s	.waitB
			move.l	a1,$54(a6)
			move.w	d2,$58(a6)
			dbf		d7,.clear
			
		
		rts

spriteRender:
		
	; display sprites

		move.w	frame(pc),d0
		andi.w	#FRAME_COUNT-1,d0
		mulu.w	#SPRITE_COUNT*4,d0
		lea	    WaveForm,a5
		add.l	d0,a5
		
		lea	$dff000,a6
		move.l	SCR1(pc),a0
		lea	(SCREENH/2)*LINE_PITCH*PLANCOUNT(a0),a0	; milieu de l'ecran
		lea pSprite,a2
		lea pMasque,a3
		move.w	#$0ff8,d3				; masked sprite
		move.w	#$09f0,d1				; copy sprite (first)
		move.w	#((31*3)<<6)+3,d2		; pour les masques
		moveq	#SPRITE_COUNT-1,d7

.sLoop:	move.l	(a5)+,d0
.waitB:	btst	#6,2(a6)
		bne.s	.waitB
		move.w	d0,$42(a6)		; decalage source B
		or.w	d1,d0
		move.w	d0,$40(a6)		;    "     source A + opirations
		move.l	a2,$50(a6)		; A
		move.l	a3,$4c(a6)		; B
		swap	d0
		movea.l	a0,a1			; ecran
		add.w	d0,a1
		move.l	a1,$48(a6)		; C
		move.l	a1,$54(a6)		; D
		move.w	d2,$58(a6)
		move.w	d3,d1
		dbf	    d7,.sLoop

        rts
			
SCR1:           dc.l    screenBuffer1
SCR2:           dc.l    screenBuffer2
frame:          dc.w    0
            
            
	data

SpriteMotif:	incbin	"m_sprite.spr"
                even
Cosinus		    incbin	"cosinus.bin"
                even

	
	data_c
		
				; CHIP Memory					
copperDummy:	dc.l	$01fc0000

				; screen 320*256
				dc.l	$008e2881
				dc.l	$009028c1
				dc.l	$00920038
				dc.l	$009400d0				
				dc.l	$01020000
				dc.l	$01040000	; $24: HW sprite priority over playfield
				dc.l	$01060000
				dc.l	$01080000|((PLANCOUNT-1)*LINE_PITCH)
				dc.l	$010a0000|((PLANCOUNT-1)*LINE_PITCH)
				dc.l	$01000200|(PLANCOUNT<<12)

				dc.l	$009c8000|(1<<4)		; fire copper interrupt

				dc.l	(24<<24)|($09fffe)      ; wait few lines so CPU has time to patch copper list
copScrSet:      dc.l    $00e00000
                dc.l    $00e20000
                dc.l    $00e40000
                dc.l    $00e60000
                dc.l    $00e80000
                dc.l    $00ea0000
                
copPal:         dc.l    $01800000
                dc.l    $01820000
                dc.l    $01840000
                dc.l    $01860000
                dc.l    $01880000
                dc.l    $018a0000
                dc.l    $018c0000
                dc.l    $018e0000


				dc.l	-2

        bss

WaveForm:		ds.b	(SPRITE_COUNT*4*512)


        bss_c

screenBuffer1:  ds.b    LINE_PITCH*PLANCOUNT*SCREENH
screenBuffer2:  ds.b    LINE_PITCH*PLANCOUNT*SCREENH

pSprite:		ds.b	6*32*4
pMasque:		ds.b	6*32*4
