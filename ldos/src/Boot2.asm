;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Boot sector of second disk
;
;---------------------------------------------------------

bootStart:
	dc.b 'DOS',0
	dc.b 'DP.1'			; 4
	dc.l 880			; 8
