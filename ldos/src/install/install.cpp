// Install AMIGA Demo
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <conio.h>
#include <assert.h>

//ARJ-7..: 837370
//Paq8x..: 593102

#define		ARJ_SUPPORT			1


typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned long	u32;

static	const	int		MAX_DIR_ENTRY	=	128;
static	const	int		CYLINDER_MAX = 80;
static	const	int		DISKSIZE_MAX	=	(CYLINDER_MAX * 2 * 512 * 11);


struct FileEntry
{
	u32	diskOffset;
	u32 packedSize;
	u32 originalSize;
	u16 flags;
	u16 arg;
};

enum
{
	ARJ7_METHOD		= 1<<1,
	PACK_ARJ4		= 1<<6,
};

typedef struct
{
	unsigned char *pData;
	unsigned int size;
} mfile_t;

static	char	sInstallPath[ _MAX_PATH ];
static	char	sArjPath[_MAX_PATH];
static	char	sLZ4Path[_MAX_PATH];

bool	g_bPack = true;
int		g_iCurrentAlign = 2;
int		g_iDefaultPacker = ARJ7_METHOD;
bool	g_bUsePad = false;

class CScreen
{
public:

	enum Type
	{
		BOOT,
		KERNEL,
		SCREEN,
		SECOND_BOOT,
	};

					CScreen();

	bool			LoadScreen(const char *pFilename,Type type, u16 arg = 0, char* sRoot = NULL);
	void			SetNext(CScreen *pScreen)							{ m_pNext = pScreen; }
	void			SetAlign(int iAlign)								{ m_iAlign = iAlign; }
	CScreen		*	GetNext()	const									{ return m_pNext; }
	Type			GetType() const										{ return m_type; }
	void			SetType( Type eType )								{ m_type = eType; }

	void			Display(int offset);
	u8*				PatchNextBootValue(u8* pWrite, u16 iValue);

public:
	int				m_packedSize;
	int				m_originalSize;
	u8			*	m_pBuffer;
	char		*	m_pName;
	int				m_iAlign;

	CScreen		*	m_pNext;
	Type			m_type;
	u16				m_arg;
	u16				m_flags;

	int				m_chipSize;
	int				m_fakeSize;

	bool			m_bLastScreenOfTheDisk;

private:
	void			amigaSectionGetInfo(mfile_t* f, const char* fName);

};

class CDisk
{
public:

	CDisk(int cylinderCount,int nbSide,int nbSector);

	bool	AddBoot(CScreen *pScreen);
	bool	AddScreen(CScreen *pScreen);
	bool	Save(const char *pOutFile, CScreen* pFirst );	
	bool	DirAndKernelPack(CScreen* pBoot, CScreen *pKernel);

private:
	void		PatchNextBootValue(u16 iValue);
	u8		*	m_pBuffer;
	int			m_writePos;
	int			m_nbCylinder;
	int			m_nbSide;
	int			m_nbSectorPerTrack;
	int			m_maxSize;
	int			m_nbDirEntry;

	u8*			m_pCurrentBootPatch;
};

mfile_t *fileLoad(const char *name, int alignSize = 2)
{

	mfile_t *pRet = NULL;
	FILE *in = NULL;
	fopen_s(&in, name, "rb");
	if (NULL != in)
	{
		fseek(in, 0, SEEK_END);
		int size = ftell(in);
		fseek(in, 0, SEEK_SET);
		if (alignSize > 0)
		{
			size += (alignSize - 1);
			size = (size / alignSize) * alignSize;
		}

		unsigned char* pData = (unsigned char*)malloc(size);
		if (pData)
		{
			fread(pData, 1, size, in);
			pRet = (mfile_t*)malloc(sizeof(mfile_t));
			if (pRet)
			{
				pRet->size = size;
				pRet->pData = pData;
			}
			else
			{
				free(pData);
			}
		}
		fclose(in);
	}
	return pRet;
}

void	fileFree(mfile_t *f)
{
	free(f->pData);
	free(f);
}


CDisk::CDisk(int cylinderCount,int nbSide,int nbSector)
{

	m_maxSize = cylinderCount*nbSide*nbSector*512;
	m_pBuffer = (u8*)malloc(m_maxSize);

	static const char* filler = " ATARI Rules :) "
								" AMIGA Rules :) ";
	for (int i= 0;i<m_maxSize;i++)
		m_pBuffer[i] = u8(filler[i & 31]);

	m_nbSectorPerTrack = nbSector;
	m_writePos = 0;

	m_nbSide = nbSide;
	m_nbSectorPerTrack = nbSector;

	m_nbCylinder = 0;
	m_pCurrentBootPatch = m_pBuffer + 32;
}

void	bigeWrite(u32 *p32,int n)
{
	u8* p = (u8*)p32;
	p[0] = u8(n>>24);
	p[1] = u8(n>>16);
	p[2] = u8(n>>8);
	p[3] = u8(n>>0);
}

void	bigeWrite16(u16 *p16, u16 n)
{
	u8* p = (u8*)p16;
	p[0] = u8(n >> 8);
	p[1] = u8(n >> 0);
}


u8*	CScreen::PatchNextBootValue(u8* pWrite, u16 iValue)
{

	while (pWrite < m_pBuffer + m_packedSize)
	{
		if ((0x4a == pWrite[0]) &&
			(0xfc == pWrite[1]))
		{

			printf("Patch next boot value: $%04x\n", iValue);

			*pWrite++ = iValue >> 8;
			*pWrite++ = iValue & 255;
			return pWrite;
		}
		pWrite += 2;
	}
	printf("Warning: Boot sector not compatible for patching ($4AFC opcode)\n");
	exit(-2);
}

void	bigeWriteW(u8 *p,int n)
{
	p[0] = u8(n>>8);
	p[1] = u8(n>>0);
}


bool	CDisk::AddBoot(CScreen *pScreen)
{
	assert(0 == m_writePos);
	if (pScreen->m_originalSize > (1024-8))
	{
		printf("Boot sector to big.\n");
		exit(1);
	}

	memset( m_pBuffer, 0, 1024 );
	memcpy( m_pBuffer ,pScreen->m_pBuffer,pScreen->m_originalSize );

	pScreen->Display(0);

	m_writePos += pScreen->m_originalSize;

	return true;
}

FileEntry directory[MAX_DIR_ENTRY];

bool	CDisk::DirAndKernelPack(CScreen* pBoot, CScreen *pKernel)
{


	memset(directory,0,sizeof(directory));
	int nbScreen = 0;
	int offset = 0;
	FileEntry *pOut = directory;
	CScreen *pIterator = pKernel->GetNext();
	while (pIterator)
	{
		if (nbScreen >= MAX_DIR_ENTRY)
		{
			printf("ERROR: Too much screens for directory (>%d)\n",MAX_DIR_ENTRY);
			exit(1);
		}

		if ( pIterator->GetType() != CScreen::SECOND_BOOT )
		{
			bigeWrite(&pOut->diskOffset,offset);
			bigeWrite(&pOut->packedSize,pIterator->m_packedSize);
			bigeWrite(&pOut->originalSize,pIterator->m_originalSize);
			bigeWrite16(&pOut->flags, pIterator->m_flags);
			bigeWrite16(&pOut->arg, pIterator->m_arg);
			pOut++;
		}
		else
		{
			offset = 0;
		}

		nbScreen++;
		offset += pIterator->m_packedSize;
		pIterator = pIterator->GetNext();
	}

	//---------------------------------------------
	FILE *h = NULL;
	fopen_s(&h, pKernel->m_pName, "rb");
	if (h)
	{
		fseek(h,0,SEEK_END);
		int size = ftell(h);
		size = (size+1)&(-2);
		fseek(h,0,SEEK_SET);

		u8 *pBuffer = (u8*)malloc(size+nbScreen*sizeof(FileEntry));
		fread(pBuffer,1,size,h);
		memcpy(pBuffer+size,directory,nbScreen* sizeof(FileEntry));
		fclose(h);

		fopen_s(&h,"dirkernel.tmp","wb");
		if (NULL != h)
		{
			fwrite(pBuffer,1,size+nbScreen* sizeof(FileEntry),h);
			fclose(h);
		}
		free(pBuffer);
	}

	// pack and load the new dir+kernel
	CScreen *pNew = new CScreen;
	if (!pNew->LoadScreen("dirkernel.tmp",CScreen::KERNEL))
		return false;

	remove( "dirkernel.tmp" );

	//---------------------------------------------

	int kernelNbSector = (pBoot->m_originalSize + pNew->m_packedSize+511)/512;
	assert(kernelNbSector >= 2);		// at least two sectors (boot sector + rest)
	
//	pNew->Display(m_writePos);

	int dataOffset = pBoot->m_packedSize + pNew->m_packedSize;			// boot sector (512) + dir + kernel

//	PatchNextBootValue((u16)pNew->m_originalSize);	// original kernel size not needed anymore with new bootsector
	u8* pPatch = pBoot->m_pBuffer;
	pPatch = pBoot->PatchNextBootValue( pPatch,u16(kernelNbSector) );
	pPatch = pBoot->PatchNextBootValue(pPatch, (u16)dataOffset);
	pPatch = pBoot->PatchNextBootValue(pPatch, u16(nbScreen * sizeof(FileEntry)));

	CScreen*	pOriginalNext = pKernel->m_pNext;
	*pKernel = *pNew;
	pKernel->m_pNext = pOriginalNext;

// 	memcpy(m_pBuffer+m_writePos,pNew->m_pBuffer,pNew->m_packedSize);
// 	m_writePos += pNew->m_packedSize;

	return true;
}



bool	CDisk::AddScreen(CScreen *pScreen)
{

//	assert(CScreen::SCREEN == pScreen->m_type);

	assert(0 == (m_writePos % pScreen->m_iAlign));
	pScreen->Display(m_writePos);	

	if ((m_writePos + pScreen->m_packedSize) > m_maxSize)
	{
		printf("ERROR: Don't fit on the disk.\n");
		exit(1);
	}


	assert(0 == (pScreen->m_originalSize&1));

	memcpy(m_pBuffer+m_writePos,pScreen->m_pBuffer,pScreen->m_packedSize);

	m_writePos += pScreen->m_packedSize;

	m_writePos += pScreen->m_iAlign - 1;
	m_writePos &= -pScreen->m_iAlign;


	return true;
}

u32 bswap(u32 v)
{
	return ((( v&0xff000000 ) >> 24 ) |
			(( v&0x00ff0000 ) >> 8 ) |
			(( v&0x0000ff00 ) << 8 ) |
			(( v&0x000000ff ) << 24 ));
}

void	ADFSave(const char *pName, unsigned char *pDisk, u32 iRawSize)
{
	FILE	*out = NULL;

	fopen_s(&out, pName,"wb");
	if (NULL != out)
	{
		fwrite(pDisk,1,iRawSize,out);
		fclose(out);
	}
	else
	{
		printf("ERROR! Unable to create file \"%s\"\n(maybe in use?)\n",pName);
	}
}

static	int	B2K(int n)
{
	return ((n + 1023) >> 10);
}

static	int	R2P(int unpacked, int packed)
{
	return (packed * 100) / unpacked;
}

bool	CDisk::Save(const char *pOutFile, CScreen* pFirst)
{

	printf("\n----------------------------------------------------------------\n");
	printf("Saving %s:\n", pOutFile);

//	int cylSize = m_nbSectorPerTrack * m_nbSide * 512;
//	int nbCylinder = (m_writePos + cylSize - 1) / (cylSize);
//	int rawSize = nbCylinder * cylSize;


// finalize boot sector
	if ( pFirst->GetType() == CScreen::BOOT)
	{
		u32 crc = 0;
		u32* pW = (u32*)m_pBuffer;

		for (int i=0;i<256;i++)
		{
			u32 iData = bswap( pW[ i ] );
			if ( crc + iData < crc )
				crc++;
			crc += iData;
		}
		crc ^= 0xffffffff;
		pW[1] = bswap(crc);				// note: write checksum at begin!
	}

	int iDepackedSize = 0;
	int dirCount = 0;
	while (pFirst)
	{
		iDepackedSize += pFirst->m_originalSize;
		dirCount++;
		if (pFirst->m_bLastScreenOfTheDisk)
			break;
		pFirst = pFirst->GetNext();
	}

	// Pad the end of data with optional file
	mfile_t* pad = fileLoad("pad.bin");
	if (pad)
	{
		const unsigned int freeSpace = m_maxSize - m_writePos;
		int copyCount = (pad->size <= freeSpace) ? pad->size : freeSpace;
		memcpy(m_pBuffer + m_writePos, pad->pData, copyCount);
		m_writePos += copyCount;
		fileFree(pad);
	}

	if (g_bUsePad)
		m_writePos = m_maxSize;

	printf("\nDisk contains %d files, packing ratio: %d%%\n",dirCount, R2P(iDepackedSize,m_writePos));
	printf("%dKiB packed to %dKiB ( %d to %d bytes )\n", B2K(iDepackedSize), B2K(m_writePos), iDepackedSize, m_writePos);
	printf("%dKiB left ( %d bytes )\n", B2K(m_maxSize - m_writePos), m_maxSize - m_writePos);

//	ADFSave(pOutFile, m_pBuffer, m_maxSize);

	int cylinderCount = (m_writePos + 11 * 1024 - 1) / (11 * 1024);
	ADFSave(pOutFile, m_pBuffer, cylinderCount * 11*1024);

	return true;
}





CScreen::CScreen()
{
	m_pBuffer = NULL;
	m_pNext = NULL;
	m_pName = NULL;
	m_iAlign = 2;
	m_bLastScreenOfTheDisk = false;
	m_chipSize = -1;
	m_fakeSize = -1;
}

static	const char*	typeToPackerName(CScreen::Type t)
{
	switch (t)
	{
	case CScreen::BOOT:
	case CScreen::SECOND_BOOT:
		return "---";
		break;
	case CScreen::KERNEL:
		return "AR4";
		break;
	case CScreen::SCREEN:
		return "AR7";
		break;
	default:
		return "???";
	}
}

void	CScreen::Display(int offset)
{

	char fName[_MAX_FNAME];
	char fExt[_MAX_EXT];
	_splitpath_s(m_pName, NULL, 0, NULL, 0, fName, _MAX_FNAME, fExt, _MAX_EXT);

	int iCyl = offset / (512*11*2);
	int iSide = (offset % (512*11*2)) / (512*11);
	int iSector = ((offset % (512*11*2)) % (512*11)) / 512 + 1;


	printf("%16s%3s %6d %6d (%3d%%) [%s] Off:$%06x (%02d/%d/%02d:$%03x) (user arg=%d)%s", fName, fExt,
		m_originalSize & 0x7fffffff,
		m_packedSize,
		(m_packedSize * 100) / (m_originalSize & 0x7fffffff),
		typeToPackerName(GetType()),
		offset,
		iCyl, iSide, iSector, offset & 511, m_arg, (m_flags & 1) ? " (chip load)":"");

	if ((m_fakeSize > 0) || (m_chipSize > 0))
	{
		printf("(C:%3dKiB F:%3dKiB)", (m_chipSize + 1023) >> 10, (m_fakeSize + 1023) >> 10);
	}
	printf("\n");
}



bool	arjValidHeader(const u8 *pData)
{
		return ((0x60 == pData[0]) && (0xea == pData[1]));
}

u8	*arjSkipHeader(u8 *pData)
{

		if (!arjValidHeader(pData))
			return NULL;

		u16 offset = *(u16*)(pData+2);
		offset += 4 + 4;		// 4 bytes at first, 4 bytes at end for basic header crc
			
		u16 extHead = *(u16*)(pData + offset);
		offset += 2;
		if (extHead)
		{
			offset += extHead + 4;
		}
		
		return pData + offset;

}


mfile_t*	PackFile( const char* pSource, int iPackingMethod )
{
	char sArchive[ _MAX_PATH ];

	// create the packed file
	*sArchive = 0;
	sprintf_s( sArchive, _MAX_PATH, "temp.archive" );
	remove( sArchive );
	const int CMDLEN = 1024;
	char cmd[CMDLEN];
	*cmd = 0;
	// try to pack with ARJ-7
	switch (iPackingMethod)
	{
		case ARJ7_METHOD:
			sprintf_s(cmd, CMDLEN, "%s a -m7 -jm %s %s", sArjPath, sArchive, pSource);
			break;
		case PACK_ARJ4:
			sprintf_s(cmd, CMDLEN, "%s a -m4 %s %s", sArjPath, sArchive, pSource);
			break;
		default:
				printf("ERROR: Unsupported compression method\n");
				return NULL;
	}

	mfile_t* pFile = NULL;
	int err = system(cmd);
	if ( 0 == err )
	{
		pFile = fileLoad( sArchive );
	}
	else
	{
		printf("WARNING: ERROR %d when running command\n\"%s\"\n", err, cmd );
	}

	remove( sArchive );
	return pFile;
}

u32	GetARJSize( u8* pRaw )
{

	assert((0x60 == pRaw[0]) && (0xea == pRaw[1]));
	// arj file ( http://datacompression.info/ArchiveFormats/arj.txt )
	u8 *pData = arjSkipHeader(pRaw);
	u8 *pData2 = NULL;
	if (pData)
		pData2 = arjSkipHeader(pData);

	if ((pData) && (pData2))
	{
		unsigned long* pD = (unsigned long*)(pData+16);
		int arjSize = *pD;								// Taille
		u32 iPackedSize = (arjSize + 2);				// packed stream + 2 NULL bytes
		iPackedSize = (iPackedSize+1)&(-2);
		return iPackedSize;
	}

	return 0xffffffff;
}


static	u32	Read32(const u32* p)
{
	return bswap(*p);
}

static	u16	Read16(const u16* p)
{
	u16 v = *p;
	return (v >> 8) | (v << 8);
}


void	CScreen::amigaSectionGetInfo(mfile_t* f, const char* fName)
{

	const u32* p = (const u32*)f->pData;

	if (Read32(p) == 0x3f3)
	{
		if (0 == Read32(p + 1))
		{
			int hunkCount = Read32(p + 2);
			p += 5;		// skip first and last hunk

			for (int i = 0; i < hunkCount; i++)
			{
				u32 v = Read32(p);
				int size = (v & 0x00ffffff) << 2;		// size in bytes
				if (v & (1 << 30))
					m_chipSize += size;
				else
					m_fakeSize += size;
				p++;
			}
		}
	}
	else
	{
		if ((strstr(fName, "p61")) || (strstr(fName, "P61")))
		{
			m_fakeSize = Read16((const u16*)f->pData);
			m_chipSize = f->size - m_fakeSize;
		}
	}
}

bool	CScreen::LoadScreen(const char *sFname,Type type, u16 arg, char* sRoot)
{

	m_type = type;
	m_arg = arg;
	m_flags = 0;

	if ((strstr(sFname, "p61")) || (strstr(sFname, "P61")))
		m_flags |= 1;			// bit 0 means directly load in chip memory

	char pFilename[ _MAX_PATH ];
	if (sRoot)
	{
		strcpy_s(pFilename, _MAX_PATH, sRoot);
		strcat_s(pFilename, _MAX_PATH, sFname);
	}
	else
		strcpy_s( pFilename, _MAX_PATH, sFname );

	m_pName = _strdup(pFilename);

	int	packingMethod = g_iDefaultPacker;

	if ((!g_bPack) || (BOOT == type) || (SECOND_BOOT == type))
		packingMethod = 0;

	if (KERNEL == type)
		packingMethod = PACK_ARJ4;

	mfile_t* pOriginal = fileLoad( pFilename );
	if (NULL == pOriginal)
	{
		printf("ERROR: Unable to read \"%s\"\n", sFname );
		return false;
	}

	amigaSectionGetInfo(pOriginal,pFilename);

	m_originalSize = pOriginal->size;

	if (0 == packingMethod)
	{
		int iSize = pOriginal->size;
		m_packedSize = m_originalSize = iSize;
		m_pBuffer = (u8*)malloc( iSize );
		memcpy(m_pBuffer, pOriginal->pData, pOriginal->size );
		fileFree( pOriginal );
	}
	else
	{
		mfile_t* pArj7 = NULL;
		fileFree( pOriginal );

		pArj7 = PackFile(pFilename, packingMethod);

		if ( NULL == pArj7 )
		{
			printf("ERROR: Unable to get result from \"%s\"\n", sFname );
			return false;
		}

		if ((0x60 == pArj7->pData[0]) && (0xea == pArj7->pData[1]))
		{
			// arj file ( http://datacompression.info/ArchiveFormats/arj.txt )
			u8 *pData = arjSkipHeader(pArj7->pData);
			u8 *pData2 = NULL;
			if (pData)
				pData2 = arjSkipHeader(pData);

			if ((pData) && (pData2))
			{
				
				unsigned long* pD = (unsigned long*)(pData+20);
				m_originalSize = *pD;
				m_originalSize = (m_originalSize+1)&(-2);
				pD = (unsigned long*)(pData+16);
				int arjSize = *pD;				// Taille

				m_packedSize = (arjSize + 2);				// packed stream + 2 NULL bytes
				m_packedSize = (m_packedSize+1)&(-2);

				if (PACK_ARJ4 == packingMethod)
				{
					m_pBuffer = (u8*)malloc(m_packedSize + 4);
					memset(m_pBuffer, 0, m_packedSize+4);
					*((int*)m_pBuffer) = bswap(m_originalSize);
					memcpy(m_pBuffer+4, pData2, arjSize);		// taille + crc16
					m_packedSize += 4;
				}
				else
				{
					m_pBuffer = (u8*)malloc(m_packedSize);
					memset(m_pBuffer, 0, m_packedSize);
					memcpy(m_pBuffer, pData2, arjSize);		// taille + crc16
				}

			}
		}
		else
		{
			printf("FATAL: Bad ARJ7 packed file\n");
			assert( false );
			exit(1);
		}

		if (pArj7)
			fileFree( pArj7 );
	}

	return true;
}


void	buteSlacheN(char *ptr)
{
		while (*ptr)
		{
			if (*ptr=='\n') *ptr=0;
			ptr++;
		}
}



CScreen	*parseScript(char *pName)
{
char	*ptr;



		CScreen *pFirst = NULL;
		CScreen *pLast = NULL;

		FILE	*in = NULL;
		fopen_s(&in, pName,"r");
		if (!in)
		{
			printf("SCRIPT file \"%s\" not found.\n",pName);
			exit(1);
		}
		else
		{

		// load boot & kernel 
		CScreen* pBoot = new CScreen;
		CScreen* pKernel = new CScreen;
		pBoot->LoadScreen("boot.bin", CScreen::BOOT, 0, sInstallPath);
		pKernel->LoadScreen("kernel.bin", CScreen::KERNEL, 0, sInstallPath);	//NOTE: BOOT specify NO compression (the compression is done after, using kerneltemp.bin
		pFirst = pBoot;
		pLast = pKernel;
		pBoot->SetNext(pKernel);

		char tmpString[1024];
		for (;;)
		{
			ptr = fgets(tmpString, 256, in);
			if (NULL == ptr)
				break;

			buteSlacheN(ptr);
			if (!_stricmp(tmpString, "end")) break;

			if (!_stricmp(tmpString, "pack(off)"))
			{
				g_bPack = false;
				continue;
			}
			if (!_stricmp(tmpString, "pack(on)"))
			{
				g_bPack = true;
				continue;
			}

			if (!_stricmp(tmpString, "change(disk)"))
			{
				assert(pLast);
				pLast->m_bLastScreenOfTheDisk = true;

				CScreen *pBoot2 = new CScreen;
				pBoot2->LoadScreen("boot2.bin", CScreen::SECOND_BOOT, 0, sInstallPath);
				assert(pFirst);
				pLast->SetNext(pBoot2);
				pLast = pBoot2;
				continue;
			}


			if ((ptr[0] != ';') && (strlen(ptr) > 0))
			{

				CScreen *pScreen = new CScreen;

				bool chipLoad = false;
				u16 arg = 0;
				char* pArg = strstr(ptr, ",");
				if (pArg)
				{
					if (0 == _stricmp(pArg + 1, "chip"))
					{
						chipLoad = true;
					}
					else
					{
						arg = u16(atoi(pArg + 1));
					}
					pArg[0] = 0;
				}

				if (!pScreen->LoadScreen(ptr, CScreen::SCREEN, arg))
				{
					printf("ERROR: Could not load screen \"%s\"\n", ptr);
					exit(-1);
				}

				if (chipLoad)
					pScreen->m_flags |= (1 << 0);			// chip load

				if (NULL == pFirst)
				{
					pFirst = pScreen;
				}
				else
				{
					pLast->SetNext(pScreen);
				}
				pLast = pScreen;
			}
		}
		}

		return pFirst;
}


void	Usage()
{
	printf("Usage: install <script text> <adf disk1> [adf disk2]\n");
	printf("\n");
}

int	main(int _argc, char *_argv[])
{
	printf("AMIGA Demo Putting Together.\n");
	printf("Written by Arnaud Carr%c.\n", 0x82);
	printf("Leonard Demo Kernel v1.0\n");

	int argc = 0;
	char* argv[8];
	for (int i = 0; i < _argc; i++)
	{
		if ('-' == _argv[i][0])
		{
			if (0 == _stricmp(_argv[i], "-pad"))
			{
				g_bUsePad = true;
				printf("Use disk padding (-pad)\n");
			}
		}
		else
		{
			argv[argc++] = _argv[i];
		}
	}

	if (argc < 3)
	{
		Usage();
		return -1;
	}

	char sDrive[ _MAX_DRIVE ];
	char sDir[ _MAX_DIR ];
	_splitpath_s(argv[0], sDrive, _MAX_DRIVE, sDir, _MAX_DIR, NULL, 0, NULL, 0 );
	_makepath_s(sInstallPath, _MAX_PATH, sDrive, sDir, NULL, NULL);

	_makepath_s(sArjPath, _MAX_PATH, sDrive, sDir, "arjbeta", "exe");
	_makepath_s(sLZ4Path, _MAX_PATH, sDrive, sDir, "lz4", "exe");

	static	const	char*	sDiskNames[2] = {"Demo_d1.adf","Demo_d2.adf"};
	static	const	char*	sSTDiskNames[2] = {NULL,NULL};

	CScreen *pBoot = parseScript(argv[1]);
	if (pBoot)
	{

		CDisk *pDisk = new CDisk(CYLINDER_MAX,2,11);		// 2 sides, 11 sectors per cylinder

		// Write boot sector
//			pDisk->AddBoot(pBoot);

		assert(pBoot->GetNext());
		CScreen* pKernel = pBoot->GetNext();

		pDisk->DirAndKernelPack(pBoot, pKernel);

		int iDiskId = 0;
		sDiskNames[ 0 ] = argv[ 2 ];

		if (argc >= 4 )
			sDiskNames[1] = argv[3];

		// Create the file
		CScreen *pIterator = pBoot;
		while (pIterator)
		{
			if ((CScreen::BOOT == pIterator->GetType()) ||
				(CScreen::SECOND_BOOT == pIterator->GetType()))
			{
				pDisk->AddBoot(pIterator);
			}
			else
			{
				pDisk->AddScreen(pIterator);
			}
			if (pIterator->m_bLastScreenOfTheDisk)
			{
				pDisk->Save(sDiskNames[iDiskId], pBoot);
				iDiskId++;
				delete pDisk;
				pDisk = new CDisk(CYLINDER_MAX, 2, 11);
				pBoot = pIterator->GetNext();
			}
			pIterator = pIterator->GetNext();
		}

		if ( pDisk )
		{
			pDisk->Save( sDiskNames[ iDiskId ], pBoot);
			iDiskId++;
		}
	}

		

}

