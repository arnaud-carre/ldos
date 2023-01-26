;---------------------------------------------------------
;
;	LDOS (Leonard Demo Operating System)
;	AMIGA version
;	Written by Leonard/Oxygene
;	https://github.com/arnaud-carre/ldos
;
;	Private vars
;
;---------------------------------------------------------


_DEBUG					=	1
		
MEMLABEL_SYSTEM			=	$7f
MEMLABEL_TRACKLOAD		=	$7e
MEMLABEL_PRECACHED_FX	=	$7d
MEMLABEL_MUSIC_LSM		=	$7c
MEMLABEL_MUSIC_LSB		=	$7b
MEMLABEL_DEBUG_SCREEN	=	$7a
MEMLABEL_BOOTREAD		=	$79
MEMLABEL_USER_FX		=	$78
MEMLABEL_PERSISTENT_CHIP=	$77
MEMLABEL_PERSISTENT_FAKE=	$76

kLDOSRawFile			=	0
kLDOSExeFile			=	1
kLDOSLsMusicFile		=	2
kLDOSLsBankFile			=	3

SVAR_LOW				=	$f0
SVAR_ROM_VERSION		=	$f0
SVAR_CURRENT_MEMLABEL	=	$f1
SVAR_HDD_BUFFER			=	$f2
SVAR_HDD_BUFFER2		=	$f6
SVAR_VBL_COUNT			=	$fa
SVAR_LOAD_PTR			=	$fc

DEBUG_SCREEN_SIZE		=	(40*256)
DEBUG_SCREEN_AD			=	$78000
DEBUG_REGS_ZONE			=	DEBUG_SCREEN_AD+DEBUG_SCREEN_SIZE		; 8 dn + 9an + pc + sr
DEBUG_BSS_ZONE			=	DEBUG_REGS_ZONE+256

DEPACK_IN_PLACE_MARGIN	=	24*1024;

MEM_ALLOCATOR_DEBUG		=	0				; fill up memory blocks with CDCDCDCD when FREE
MEM_SIZE_MASK			=	$00fffff8		; size always 8 bytes aligned 

LDOS_MEM_ANY_RAM_BIT	=	30				; Warning: change LDOS_MEM_CHIP in kernel.inc too
LDOS_MEM_CLEAR_BIT		=	29

MFM_DMA_SIZE			=	(512*11+768)*2+1024+64	; weird bug, track could be shifted in some case ( http://eab.abime.net/showthread.php?p=1163403 )

LDOS_USERSTACK_SIZE		=	1024
LDOS_SUPERSTACK_SIZE	=	512

MEMPAGE_SIZE_BIT		=	12								; 4KiB page
MEMBANK_SIZE			=	512*1024						; 512KiB per bank (chip or fast)
MEMPAGE_SIZE			=	(1<<MEMPAGE_SIZE_BIT)
MEMPAGE_COUNT			=	MEMBANK_SIZE/MEMPAGE_SIZE


	; temp struct to pass data between system & LDOS
m_chipStart:	=	0
m_chipSize:		=	4
m_fakeStart:	=	8
m_fakeSize:		=	12
m_originalA1:	=	16
m_buffer:		=	20
m_hddBuffer1:	=	24
m_hddBuffer2:	=	28
m_entropyValue:	=	32
m_sizeOf:		=	34
