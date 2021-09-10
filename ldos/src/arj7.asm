;
; ARJ Mode 1-3 and 7 decode functions
; Size optimized
;
; Copyleft 1993-1997 Mr Ni! (the Great) of the TOS-crew
;
; altered version, two nullbytes have to be added at the end of the
; packed data. Orig size isn't necesarry then.
; packed data has to start on an even adress
; These alterations make the program a bit faster and smaller
;
; This function uses a BIG amount of stack space!
; It uses about 16kB!
; You can reduce this amount with 13320 bytes
; by suppyling A3 with a pointer to a 13320 bytes big
; workspace and removing the stack allocation and
; deallocation code at the right places in the source
; text. (total is 3 lines, 2 at the start, 1 at main rts)
;
; Note:
; ARJ_OFFS.TTP. This program is an addition to UNARJ_PR. It 
; calculates the minimum offset between the source and destination 
; address for in memory depacking of files.
; (Depacking A1-referenced data to A0... The calculated 'offset' is
; the minimum amount of bytes required to be reserved before the
; packed data block.) 
;
;void decode(char* depack_space, char* packed_data)
;
; CALL:
; A0 = ptr to depack space
; A1 = ptr to packed data
;
; RETURN
; depacked data in depack space
;

;workspacesize   = 13320
pointer         = 0
rbuf_current    = 4
_c_table         = 8
_c_len           = 8200
avail           = 8710
_left            = 8712
_right           = 10750
_pt_len          = 12788
_pt_table        = 12808


; register usage:
; D0 =
; D1 =
; D2 = temporary usage
; D3 = 
; D4 = command tri-nibble
; D5 = const:  #$100
; D6 = bitbuf, subbitbuf
; D7 = .H: command count, .B: bits in subbitbuf
;
; A0 = klad
; A1 = rbuf_current
; A2 = _c_table
; A3 = workspace_ptr
; A4 = text_pointer
; A5 = _c_len
; A6 = copy_pointer
; A7 = Stack pointer
mainThreadDepack:
decode:
     movem.l D3-D7/A2-A6,-(a7) ;
;     lea     -workspacesize(a7),a7 ; or supply your own workspace here
;     lea     (a7),A3         ; remove if alternative workspace supplied

;	cmpi.l	#'LeO!',(a1)+
;	bne	.noArj7
;	cmpi.l	#'Arj7',(a1)+
;	bne	.noArj7

	move.l	pArj7Buffer(pc),a3
	
     movea.l A0,A4           ; depack space
     moveq   #0,D3           ; blocksize = 0
     moveq   #16,D7          ; bitcount = 16

	 moveq	#16,d0
	 bsr	fillbits
	 swap	d6
	 moveq	#16,d0
	 bsr	fillbits
	 	 
;     move.l  (A1)+,D6        ; long in bitbuf
;     swap    D6

;	addq.w	#4,a1
;.sync:
;	cmp.l	(SVAR_LOAD_PTR).w,a1
;	bge.s	.sync
;	move.l	-4(a1),d6
;	swap	d6

     lea     _c_len-pointer(A3),A5 ;
     lea     _c_table-_c_len(A5),A2
     lea     _pt_table-_c_len(A5),A0 ;
	 
	move.l a1,rbuf_current-_c_len(A5)
;	st		(bDepacking).w	 
	 
count_loop:

;	 move.l a1,rbuf_current-_c_len(A5)					; slow depacking

MFMDecoderPatch:	nop						; DO NOT REMOVE THIS NOP
arjCrcStart:							; NOTE: previous NOP is patched by trackloader, so crc check start right after

     move.w  D6,D2           ; bitbuf in d2
     dbra    D3,.bnz_cont    ; Hufmann block size > 0?


.blocksize_zero:             ; load a new Hufmann table
     move.w  D2,D3           ; blocksize
     beq.s   .decode_einde   ; blocksize zero -> decoding is done
     subq.w  #1,D3           ; adapt blocksize for dbra
     movem.l D3/A0/A2/A4,-(a7)
     moveq   #$10,D0         ; pop 16 bits
     bsr     fillbits
     moveq   #$03,D2         ; call-values for read_pt_len()
     moveq   #$13,D0         ;
     bsr     read_pt_len     ; call read_pt_len
     movea.l rbuf_current-_c_len(A5),A1
     bsr.s   .get_them2
     move.w  D2,D0
     bne.s   .n_niet_nul     ;
     bsr.s   .get_them2
     lea     (A5),A0         ;
     moveq   #$7F,D1         ;
.loop_1:
     clr.l   (A0)+           ; clear table
     dbra    D1,.loop_1
     lea     _c_table-pointer(A3),A0
     move.w  #$0FFF,D1
.loop_2:
     move.w  D2,(A0)+
     dbra    D1,.loop_2
     bra     .einde

.decode_einde:
;     lea     workspacesize(a7),a7; remove if alternative workspace supplied
.noArj7:
     movem.l (a7)+,D3-D7/A2-A6 ;
	 
	
;	sf		(bDepacking).w
	 
     rts                     ;

.get_them2:
     moveq   #9,D0           ;
     move.w  D6,D2           ; bitbuf
     lsr.w   #7,D2           ; shift 'old' bits
     bra     fillbits

.n_niet_nul:                 ; *******************************
;
; Register usage:
;
; d0
; d1
; d2
; d3
; d4
; d5 = $13
; d6 = .l (sub) bitbuf
; d7 = .b bits in bitbuf
;
; a0 = temporary usage
; a1 = rbuf_current
; a2 = _right
; a3 = rbuf_tail
; a4 = _pt_table
; a5 = _c_len
; a6 = _left
; a7 = a7
;
     lea     _pt_table-_c_len(A5),A4 ; _pt_table
     lea     _right-_c_len(A5),A2 ; _right
     lea     _left-_c_len(A5),A6 ; _left
     move.w  D0,D3           ; count
     moveq   #0,D4           ;
     moveq   #$13,D5         ;
     moveq   #0,D0           ;
.loop_3:
     move.w  D6,D0           ; sub bitbuf
     lsr.w   #8,D0           ; upper 8 bits
     add.w   D0,D0           ;
     move.w  0(A4,D0.w),D2   ; check _pt_table
     bge.s   .c_kleiner_NT   ;
     neg.w   D2
     moveq   #7,D0           ;
     move.w  D6,D1           ; bitbuf
.loop_4:                     ;
     add.w   D2,D2           ;
     btst    D0,D1           ;
     beq.s   .links          ;
     move.w  0(A2,D2.w),D2   ;
     cmp.w   D5,D2           ;
     dbcs    D0,.loop_4      ;
     bra.s   .c_kleiner_NT   ;
.links:                      ;
     move.w  0(A6,D2.w),D2   ;
     cmp.w   D5,D2           ;
     dbcs    D0,.loop_4      ;

.c_kleiner_NT:               ;
     move.b  _pt_len-_pt_table(A4,D2.w),D0 ;
     bsr     fillbits
     cmp.w   #2,D2           ;
     bgt.s   .c_groter_2     ;
     beq.s   .c_niet_1       ;
     tst.w   D2              ;
     beq.s   .loop_5_init    ;
     moveq   #4,D0
     bsr     getbits
     addq.w  #2,D2           ;
     bra.s   .loop_5_init    ;
.c_niet_1:
     bsr.s   .get_them2
     add.w   D5,D2           ;
.loop_5_init:
     moveq   #0,D0           ;
     lea     0(A5,D4.w),A0   ;
     add.w   D2,D4           ;
.loop_5:
     move.b  D0,(A0)+        ;
     dbra    D2,.loop_5      ;
     bra.s   .loop_3_test    ;
.c_groter_2:
     moveq   #0,D0           ;
     subq.w  #2,D2           ;
     move.b  D2,0(A5,D4.w)   ;
.loop_3_test:
     addq.w  #1,D4           ;
     cmp.w   D4,D3           ;
     bgt.s   .loop_3         ;
     move.w  #$01FE,D1       ;
     sub.w   D4,D1           ;
     lea     0(A5,D4.w),A0   ;
     bra.s   .loop_6_test    ;
.loop_6:
     move.b  D0,(A0)+        ;
.loop_6_test:
     dbra    D1,.loop_6      ;
     move.l  A1,rbuf_current-_c_len(A5)
     lea     _c_table-_c_len(A5),A1 ;
     moveq   #$0C,D1         ;
     movea.l A5,A0           ;
     move.w  #$01FE,D0       ;
     bsr     make_table      ;
     movea.l rbuf_current-_c_len(A5),A1
.einde:
     moveq   #-1,D2          ;
     moveq   #$11,D0         ;
     bsr     read_pt_len     ;
     movea.l rbuf_current-_c_len(A5),A1
     movem.l (a7)+,D3/A0/A2/A4
     move.w  #$0100,D5       ; constant
     move.w  D6,D2

;***********************
;
; Register usage:
;
; d0 = temporary usage
; d1 = temporary usage
; d2 = temporary usage
; d3 = loopcount
; d4 = command byte
; d5 = const: $100
; d6 = (sub)bitbuf
; d7 = .h: command count, .b byte count
;
; a0 = _pt_table
; a1 = rbuf_current
; a2 = _c_table
; a3 = rbuf_tail
; a4 = text
; a5 = _c_len
; a6 = source pointer
; a7 = (a7)

.bnz_cont:
     lsr.w   #4,D2           ; charactertable is 4096 bytes (=12 bits)
     add.w   D2,D2
     move.w  0(A2,D2.w),D2   ; pop character
     bpl.s   .decode_c_cont  ;
.j_grotergelijk_nc:
     moveq   #$03,D1         ;
     move.w  #$01FE,D0
     bsr.s   .fidel_no
.decode_c_cont:              ;
     move.b  0(A5,D2.w),D0   ; pop 'charactersize' bits from buffer
     bsr.s   fillbits
     sub.w   D5,D2           ;
     bcc.s   .sliding_dic    ;
     move.b  D2,(A4)+        ; push character into buffer
.count_test:
     bra     count_loop

.fidel_no:
     neg.w   D2
     lea     _left-_c_len(A5),A0 ;
     lea     _right-_left(A0),A6 ;
.mask_loop:
     add.w   D2,D2           ;
     btst    D1,D6           ;
     bne.s   .bitbuf_en_mask ;
     move.w  0(A0,D2.w),D2   ;
     bra.s   .mask_cont
.bitbuf_en_mask:
     move.w  0(A6,D2.w),D2   ;
.mask_cont:
     cmp.w   D0,D2           ;
     dbcs    D1,.mask_loop   ;
     lea     _pt_table-_c_len(A5),A0 ;
     rts

.sliding_dic:
     move.w  D2,D4
     addq.w  #2,D4           ;
     move.w  D6,D2           ;
     lsr.w   #8,D2           ;
     add.w   D2,D2           ;
     move.w  0(A0,D2.w),D2   ;
     bpl.s   .p_cont         ;
.p_j_grotergelijk_np:
     moveq   #$07,D1         ;
     moveq   #$11,D0
     bsr.s   .fidel_no
.p_cont:
     move.b  _pt_len-_pt_table(A0,D2.w),D0 ;
     bsr.s   fillbits
     move.w  D2,D0           ;
     beq.s   .p_einde        ;
     subq.w  #1,D0           ;
     move.w  D6,D2           ; subbitbuf
     swap    D2
     move.w  #1,D2           ;
     rol.l   D0,D2           ; shift 'old' bits
     bsr.s   fillbits
.p_einde:
     moveq   #-1,D1          ;
     sub.w   D2,D1           ; pointer offset negatief
     lea     0(A4,D1.l),A6   ; pointer in dictionary
.copy_loop_0:
     move.b  (A6)+,(A4)+     ;
     dbra    D4,.copy_loop_0
     bra     count_loop

;d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6,a7,a7
;********************************************************************************

getbits:
     move.l  D6,D2
     swap    D2
     clr.w   D2
     rol.l   D0,D2
fillbits:
     sub.b   D0,D7
     bcc.s   no_fill
     move.b  D7,D1
     add.b   D0,D1
     sub.b   D1,D0
     rol.l   D1,D6
     swap    D6
	cmp.l	(SVAR_LOAD_PTR).w,a1
	bhs.s	needMoreData			; op2>=op1     
readOk:
     move.w  (A1)+,D6
     swap    D6
     add.b   #16,D7
no_fill:
     rol.l   D0,D6
     rts

needMoreData:
		bsr		MFMDecodeTrackCallback
		bra.s	readOk
	 
	 
;d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6,a7,a7
;*******************************************************************************

read_pt_len:
     move.w  D0,D5
     move.w  D2,-(a7)
     moveq   #$05,D0
     bsr.s   getbits
     lea     _pt_len-_c_len(A5),A0
     lea     _pt_table-_pt_len(A0),A2
     move.w  D2,D4
     bne.s   .n_niet_nula
     moveq   #$05,D0
     bsr.s   getbits
     subq.w  #1,D5
._11:
     clr.b   (A0)+
     dbra    D5,._11
     moveq   #$7F,D0
.loop_2a:
     move.w  D2,(A2)+
     move.w  D2,(A2)+
     dbra    D0,.loop_2a
     addq.l  #2,a7
     move.l  A1,rbuf_current-_c_len(A5)
     rts
.n_niet_nula:
     clr.w   D3
.loop_3a:
     move.l  D6,D2
     swap    D2
     clr.w   D2
     rol.l   #3,D2
     cmp.w   #7,D2
     bne.s   .c_niet_7
     moveq   #12,D0
     bra.s   .loop_4a_test
.loop_4a:
     addq.w  #1,D2
.loop_4a_test:
     btst    D0,D6
     dbeq    D0,.loop_4a
.c_niet_7:
     moveq   #3,D0
     cmp.w   #7,D2
     bcs.s   .endif
     moveq   #-3,D0
     add.w   D2,D0
.endif:
     move.b  D2,0(A0,D3.w)
     bsr	   fillbits
     addq.w  #1,D3
     cmp.w   (a7),D3
     bne.s   .loop_3a_test
     moveq   #2,D0
     bsr     getbits
     moveq   #0,D0
     lea     0(A0,D3.w),A6
     add.w   D2,D3
     bra.s   .loop_5a_test
.loop_5a:
     move.b  D0,(A6)+
.loop_5a_test:
     dbra    D2,.loop_5a
.loop_3a_test:
     cmp.w   D3,D4
     bgt.s   .loop_3a
     moveq   #0,D0
     lea     0(A0,D3.w),A6
     bra.s   .loop_6a_test
.loop_6a:
     move.b  D0,(A6)+
     addq.w  #1,D3
.loop_6a_test:
     cmp.w   D3,D5
     bgt.s   .loop_6a
     move.w  D5,D0
     move.l  A1,rbuf_current-_c_len(A5)
     movea.l A2,A1
     moveq   #8,D1
     addq.l  #2,a7
make_table:
     movem.l D6-D7/A3/A5,-(a7)
     lea     -$6C(a7),a7
     movea.w D0,A6
     movea.l A0,A2
     move.w  D1,D4
     add.w   D4,D4
     move.w  D1,D3
     movea.l A1,A4
     lea     $48(a7),A1
     movea.l A1,A0
     moveq   #7,D0
.j_loop_0:
     clr.l   (A0)+
     dbra    D0,.j_loop_0
     movea.l A2,A0
     move.w  A6,D0
     subq.w  #1,D0
.loop_0:
     clr.w   D1
     move.b  (A0)+,D1
     add.w   D1,D1
     addq.w  #1,-2(A1,D1.w)
     dbra    D0,.loop_0
     lea     2(a7),A0
     moveq   #0,D1
     move.w  D1,(A0)+
     moveq   #15,D2
.j_loop_1:
     move.w  (A1)+,D0
     lsl.w   D2,D0
     add.w   D0,D1
     move.w  D1,(A0)+
     dbra    D2,.j_loop_1
     moveq   #$10,D0
     sub.w   D3,D0
     lea     2(a7),A1
     lea     $26(a7),A0
     moveq   #1,D1
     moveq   #-1,D2
     add.b   D3,D2
     lsl.w   D2,D1
.loop_1a:
     move.w  (A1),D2
     lsr.w   D0,D2
     move.w  D2,(A1)+
     move.w  D1,(A0)+
     lsr.w   #1,D1
     bne.s   .loop_1a
     moveq   #1,D1
     moveq   #-1,D2
     add.w   D0,D2
     lsl.w   D2,D1
.loop_2b:
     move.w  D1,(A0)+
     lsr.w   #1,D1
     bne.s   .loop_2b
     move.w  2(a7,D4.w),D2
     lsr.w   D0,D2
     beq.s   .endif0
     moveq   #1,D5
     lsl.w   D3,D5
     sub.w   D2,D5
     subq.w  #1,D5
     add.w   D2,D2
     lea     0(A4,D2.w),A0
.loop_3b:
     move.w  D1,(A0)+
     dbra    D5,.loop_3b
.endif0:
     moveq   #1,D1
     moveq   #-1,D2
     add.b   D0,D2
     lsl.w   D2,D1
     lea     avail-_c_len(A5),A1
     lea     _right-avail(A1),A3
     lea     $6A(a7),A5
     move.w  A6,(A1)
     moveq   #0,D5
.loop_4b:
     clr.w   D3
     move.b  0(A2,D5.w),D3
     beq.s   .loop_4b_inc_0
     add.w   D3,D3
     lea     0(a7,D3.w),A0
     move.w  (A0),D2
     move.w  D2,D6
     add.w   $24(A0),D6
     move.w  D6,(A0)
     cmp.w   D3,D4
     blt.s   .len_groter_tablebits_j
     sub.w   D2,D6
     add.w   D2,D2
     lea     0(A4,D2.w),A0
     subq.w  #1,D6
.j_loop_2:
     move.w  D5,(A0)+
     dbra    D6,.j_loop_2
.loop_4b_inc_0:
     addq.w  #1,D5
     cmp.w   A6,D5
     blt.s   .loop_4b
     bra.s   .loop_4b_end
.len_groter_tablebits_j:
     move.w  D2,D7
     lsr.w   D0,D7
     add.w   D7,D7
     lea     0(A4,D7.w),A0
     move.l  A0,pointer-avail(A1)
     neg.w   (A0)
     move.w  D3,D6
     sub.w   D4,D6
     beq.s   .loop_6b_end
     move.w  D6,(A5)
.loop_6b:
     move.w  (A0),D7
     add.w   D7,D7
     bne.s   .p_is_niet_nul
     move.w  (A1),D6
     move.w  D6,(A0)
     add.w   D6,D6
     move.w  D7,2(A1,D6.w)
     move.w  D7,0(A3,D6.w)
     addq.w  #1,(A1)
     move.w  D6,D7
.p_is_niet_nul:
     lea     2(A1,D7.w),A0
     move.w  D2,D6
     and.w   D1,D6
     beq.s   ._left
     lea     _right-_left(A0),A0
._left:
     add.w   D2,D2
     subq.w  #2,(A5)
     bhi.s   .loop_6b
.loop_6b_end:
     move.w  D5,(A0)
     movea.l pointer-avail(A1),A0
     neg.w   (A0)
.loop_4b_inc:
     addq.w  #1,D5
     cmp.w   A6,D5
     blt     .loop_4b
.loop_4b_end:
     lea     $6C(a7),a7
     movem.l (a7)+,D6-D7/A3/A5
     rts

;d0,d1,d2,d3,d4,d5,d6,d7,a0,a1,a2,a3,a4,a5,a6,a7,a7
;********************************************************************************
arjCrcEnd:

