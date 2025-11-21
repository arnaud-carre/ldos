#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "platform_compat.h"
#include "ldos.h"
#include "ldosFile.h"
#include "jobSystem.h"

/* TODO

	[ ] add proper support for safe depack distance
	[x] add multi-thread packing support
	[x] final mode by default, add a "-quick" option

*/

#define D_FANCY_PROGRESS 1

static	const	int	kMaxLdosFiles = 128;
static	ldosFile		gFileList[kMaxLdosFiles];
static	ldosFatEntry	gFat[kMaxLdosFiles];

static	const	int		kMaxAdfSize = 80 * 2 * 512 * 11;
bool gQuickMode = false;



void	removeAnyEOL(char *ptr)
{
	while (*ptr)
	{
		if (*ptr == '\n')
			*ptr = 0;
		ptr++;
	}
}

int		ldosScriptParsing(const char* sScriptName, ldosFile* out)
{
	int count = 0;
	int diskId = 0;

	FILE* in = NULL;
	fopen_s(&in, sScriptName, "r");
	if (!in)
	{
		printf("ERROR: Unable to read SCRIPT file \"%s\"!\n", sScriptName);
		return 0;
	}

	char tmpString[1024];
	bool packing = true;
	for (;;)
	{

		char* ptr = fgets(tmpString, 256, in);
		if (NULL == ptr)
			break;

		removeAnyEOL(ptr);
		if (!_stricmp(tmpString, "end")) break;

		if (!_stricmp(tmpString, "pack(off)"))
		{
			packing = false;
			continue;
		}
		if (!_stricmp(tmpString, "pack(on)"))
		{
			packing = true;
			continue;
		}

		if (!_stricmp(tmpString, "change(disk)"))
		{
			diskId++;
			continue;
		}

		if ((ptr[0] != ';') && (strlen(ptr) > 0))
		{
			if (count < kMaxLdosFiles)
			{
				if (out[count].LoadUserFile(ptr, packing))
				{
					count++;
				}
				else
				{
					printf("ERROR: Unable to load file \"%s\"\n", ptr);
				}
			}
			else
			{
				printf("ERROR: Too many files in the script!\n");
				return 0;
			}
		}
	}
	return count;
}

void	Usage()
{
	printf("Usage: ldos [options] <script text> <adf file>\n");
	printf("\n");
	printf("Options:\n");
	printf("\t-quick: faster compression during dev\n");
	printf("\n");
}

void	ldosFatCreate(const ldosFile* files, int count, ldosFatEntry* out)
{
	uint32_t diskOffset = 0;
	for (int i = 0; i < count; i++)
	{

		const ldosFile::Info& info = files[i].GetInfo();
		assert(0 == (info.m_originalSize & 1));
		assert(0 == (info.m_packedSize & 1));

		out->diskOffset = bswap32(diskOffset);
		out->originalSize = bswap32(info.m_originalSize);
		out->packedSize = bswap32(info.m_packedSize);

		uint16_t flags = 1 << info.m_type;
		if (kNone == info.m_packType)
			flags |= 0x8000;			// unpacked stored file
		out->flags = bswap16(flags);
		out->pad = 0;

		diskOffset += info.m_packedSize;
		out++;
	}
}


static void	BootSectorExec(uint32_t* pW)
{
	uint32_t crc = 0;
	for (int i = 0; i < 256; i++)
	{
		uint32_t iData = bswap32(pW[i]);
		if (crc + iData < crc)		// simulate add with carry
			crc++;
		crc += iData;
	}
	crc ^= 0xffffffff;
	pW[1] = bswap32(crc);				// note: write checksum at begin!
}

static	bool	AdfExport(char* argv[], const ldosFile* files, int count, const ldosFile& boot, const ldosFile& kernel)
{
	bool ret = false;
	uint8_t* adfBuffer = (uint8_t*)malloc(kMaxAdfSize);
	memset(adfBuffer, 0, kMaxAdfSize);

	printf("LDOS Floppy disk layout:\n");
	uint32_t diskOffset = 0;
	diskOffset = boot.OutToDisk(adfBuffer, diskOffset, kMaxAdfSize);
	diskOffset = kernel.OutToDisk(adfBuffer, diskOffset, kMaxAdfSize);
	for (int i = 0; i < count; i++)
		diskOffset = files[i].OutToDisk(adfBuffer, diskOffset, kMaxAdfSize);

	printf("\n");
	if (diskOffset <= kMaxAdfSize)
	{
		printf("Saving final ADF file \"%s\"...\n", argv[0]);
		printf("  Floppy compressed data: %3dKiB (%d bytes)\n",(diskOffset+1023)>>10 , diskOffset);
		printf("  Free space............: %3dKiB (%d bytes)\n", (kMaxAdfSize - diskOffset)>>10, (kMaxAdfSize - diskOffset));
		// round up to a floppy cylinder size
		BootSectorExec((uint32_t*)adfBuffer);

		FILE* h;
		if (0 == fopen_s(&h, argv[0], "wb"))
		{
			fwrite(adfBuffer, 1, kMaxAdfSize, h);
			fclose(h);
			ret = true;
		}
		else
		{
			printf("ERROR: Unable to create ADF file \"%s\"\n", argv[0]);
		}
	}
	else
	{
		const uint32_t overrun = diskOffset - kMaxAdfSize;
		printf("FATAL ERROR: %d bytes does not fit on the DISK!\n( %d bytes overrun! )\n",diskOffset, overrun);
		return false;
	}


	return ret;
}


static bool jobCompress(void* base, int index)
{
	ldosFile* lf = (ldosFile*)base;
	return lf[index].Compress();
}


int	main(int _argc, char *_argv[])
{
	printf("LDOS Installer v1.50\n");
	printf("Written by Arnaud Carr%c.\n\n", 0x82);

	assert(16 == sizeof(ldosFatEntry));

	int argc = 0;
	char* argv[8] = {};
	for (int i = 0; i < _argc; i++)
	{
		if ('-' == _argv[i][0])
		{
			if (0 == _stricmp(_argv[i], "-quick"))
				gQuickMode = true;
		}
		else
		{
			argv[argc++] = _argv[i];
			if (argc >= 8)
				break;
		}
	}

	if (argc < 3)
	{
		Usage();
		return -1;
	}

	char sDrive[_MAX_DRIVE];
	char sDir[_MAX_DIR];
	char sKernelFilename[_MAX_PATH];
	char sBootFilename[_MAX_PATH];
	_splitpath_s(argv[0], sDrive, _MAX_DRIVE, sDir, _MAX_DIR, NULL, 0, NULL, 0);
	_makepath_s(sKernelFilename, _MAX_PATH, sDrive, sDir, "kernel", "bin");
	_makepath_s(sBootFilename, _MAX_PATH, sDrive, sDir, "boot", "bin");

	int count = ldosScriptParsing(argv[1], gFileList);
	if (count > 0)
	{
		// pack all user files using multi-threading
		JobSystem js;
		int nWorkers = js.RunJobs(gFileList, count, jobCompress);

		if (gQuickMode)
			printf("(compression ratio warning: quick mode active)\n");
		else
			printf("(you can use -quick for faster compression during dev)\n");
		printf("Packing (ZOPFLI deflate) %d files using %d threads...\n", count, nWorkers);

#if D_FANCY_PROGRESS
		using namespace std::chrono_literals;
		int ii = 0;
		for (;;)
		{
			int doneCount = 0;
			const char c = "|/-\\"[(ii++)&3];
			printf("[");
			for (int i=0;i<count;i++)
			{
				if ( 0 == gFileList[i].m_reportState)
				{
					printf(" ");
				}
				else if (1 == gFileList[i].m_reportState)
				{
					printf("%c",c);
				}
				else if (2 == gFileList[i].m_reportState)
				{
					printf("X");
					doneCount++;
				}
			}
			printf("]\r");
			std::this_thread::sleep_for(100ms);
			if (doneCount == count)
			{
				printf("\n");
				break;
			}
		}
#endif

		const int nSuccess = js.Complete();
		if (nSuccess == count)
		{

			// And now pack boot & kernel
			ldosFatCreate(gFileList, count, gFat);
			ldosFile kernel;
			if (kernel.LoadKernel(sKernelFilename, gFat, count))
			{
				ldosFile boot;
				if (boot.LoadBoot(sBootFilename, kernel.GetInfo(), count))
				{
					AdfExport(argv + 2, gFileList, count, boot, kernel);
				}
			}
		}
		else
		{
			printf("ERROR while packing (deflate) files!\n");
		}
	}

	return 0;
}

