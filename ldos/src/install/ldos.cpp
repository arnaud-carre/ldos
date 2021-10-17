#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "ldos.h"

static	char	sInstallPath[_MAX_PATH];
static	char	sArjPath[_MAX_PATH];

static	const	int	kMaxLdosFiles = 128;
static	ldosFile		gFileList[kMaxLdosFiles];
static	ldosFatEntry	gFat[kMaxLdosFiles];

static	const	int		kMaxAdfSize = 80 * 2 * 512 * 11;

u32 bswap32(u32 v)
{
	return (((v & 0xff000000) >> 24) |
		((v & 0x00ff0000) >> 8) |
		((v & 0x0000ff00) << 8) |
		((v & 0x000000ff) << 24));
}

u16 bswap16(u16 v)
{
	return (v >> 8) | (v << 8);
}

static u8*	rawFileLoad(const char* sFilename, u32& outSize)
{
	u8* data = NULL;
	FILE* h;
	fopen_s(&h, sFilename, "rb");
	if (h)
	{
		fseek(h, 0, SEEK_END);
		outSize = ftell(h);
		fseek(h, 0, SEEK_SET);
		data = (u8*)malloc(outSize);
		if (data)
			fread(data, 1, outSize, h);
		fclose(h);
	}
	return data;
}

static const u8* arjSkipHeader(const u8* pData)
{
	const u8* ret = NULL;
	if ((0x60 == pData[0]) && (0xea == pData[1]))
	{
		u16 offset = *(u16*)(pData + 2);
		offset += 4 + 4;		// 4 bytes at first, 4 bytes at end for basic header crc
		u16 extHead = *(u16*)(pData + offset);
		offset += 2;
		if (extHead)
			offset += extHead + 4;
		ret = pData + offset;
	}
	return ret;
}


// arj file ( http://datacompression.info/ArchiveFormats/arj.txt )
static u8*	ArjDataExtract(const u8* arj, int method, u32& outSize)
{

	u8* ret = NULL;
	const u8 *pData = arjSkipHeader(arj);
	const u8 *pData2 = NULL;
	if (pData)
		pData2 = arjSkipHeader(pData);

	if ((pData) && (pData2))
	{
		const u32* r = (const u32*)pData;
		u32 rawPackedSize = r[4];
		u32 originalSize = r[5];
		if (7 == method)
		{
			// arjm7 68k code use 2x$00 bytes at the end of the file
			// always align on 2 bytes for LDOS floppy FAT
			outSize = (rawPackedSize + 2 + 1)&(-2);
			ret = (u8*)malloc(outSize);
			memset(ret, 0, outSize);		// be sure two last bytes are 0
			memcpy(ret, pData2, rawPackedSize);
		}
		else if (4 == method)
		{
			// arjm4 68k code need original size to detect end of the file
			outSize = (rawPackedSize + 4 + 1)&(-2);
			ret = (u8*)malloc(outSize);
			memset(ret, 0, outSize);		// be sure two last bytes are 0
			u32* w = (u32*)ret;
			w[0] = bswap32(originalSize);
			memcpy(ret + 4, pData2, rawPackedSize);
		}
	}
	return ret;
}

bool	ldosFile::ArjPack(int method)
{
	bool ret = false;
	if (0 == method)
	{
		// no packing
		m_packedData = (u8*)malloc(m_originalSize);
		memcpy(m_packedData, m_data, m_originalSize);
		m_packedSize = m_originalSize;
		m_packingRatio = 100;
		ret = true;
	}
	else
	{
		const char* sTmpSrcFile = "tmpSrc.bin";
		const char* sTmpDstFile = "tmpDst.pack";
		// first, save original data as tmp file
		FILE* h;
		if (0 == fopen_s(&h, sTmpSrcFile, "wb"))
		{
			fwrite(m_data, 1, m_originalSize, h);
			fclose(h);

			// now run ARJ packer
			remove(sTmpDstFile);

			char cmd[256];
			sprintf_s(cmd, sizeof(cmd), "%s a -m%d -jm %s %s", sArjPath, method, sTmpDstFile, sTmpSrcFile);
			int err = system(cmd);
			if (0 == err)
			{
				u32 packedSize;
				u8* arjData = rawFileLoad(sTmpDstFile, packedSize);
				if (arjData)
				{
					m_packedData = ArjDataExtract(arjData, method, m_packedSize);
					if (m_packedData)
					{
						m_packingRatio = (m_packedSize * 100) / m_originalSize;
						ret = true;
					}
					free(arjData);
				}
			}
			else
			{
				printf("FATAL ERROR: When executing command line:\n\"%s\"\n", cmd);
			}
			remove(sTmpSrcFile);
			remove(sTmpDstFile);
		}
	}
	if (!ret)
		printf("ERROR: Unable to ARJm%d pack file!\n", method);

	return ret;
}

void	ldosFile::Release()
{
	m_diskId = -1;
	free(m_data);
	free(m_packedData);
	m_data = NULL;
	m_packedData = NULL;
	m_originalSize = 0;
	m_packedSize = 0;
	m_type = kUnknownRawBinary;
}

ldosFileType	ldosFile::DetermineFileType(const char* sFilename)
{
	ldosFileType ret = kUnknownRawBinary;
	if ((m_data) && (m_originalSize >= 4))
	{
		const u32* r = (const u32*)m_data;
		if (0x3f3 == bswap32(r[0]))
			ret = kAmigaExeFile;
		else if ('LSP1' == bswap32(r[0]))
			ret = kLSPMusicScore;
		else
		{
			char fExt[_MAX_EXT];
			_splitpath_s(sFilename, NULL, 0, NULL, 0, NULL, 0, fExt, _MAX_EXT);
			if (0 == _stricmp(fExt, ".lsbank"))
			{
				ret = kLSPMusicBank;
			}
		}
	}
	return ret;
}

static u16* PatchNext4afc(u16* patch, u16* end, u16 value)
{
	while ( patch < end)
	{
		if (bswap16(*patch) == 0x4afc)
		{
			*patch = bswap16(value);
			return patch + 1;
		}
		patch++;
	}
	printf("ERROR: Unable to patch boot sector!\n");
	return NULL;
}

bool	ldosFile::LoadBoot(const ldosFile& kernel, int count)
{
	char sFilename[_MAX_PATH];
	strcpy_s(sFilename, _MAX_PATH, sInstallPath);
	strcat_s(sFilename, _MAX_PATH, "boot.bin");
	bool ret = false;

	m_data = rawFileLoad(sFilename, m_originalSize);
	if (m_data)
	{
		u16* patch = (u16*)m_data;
		u16* end = (u16*)(m_data + m_originalSize);

		int dataOffset = m_originalSize + kernel.m_packedSize;
		assert(0 == (dataOffset & 1));
		int bootAndKernelSectorCount = (dataOffset + 511) / 512;

		patch = PatchNext4afc(patch, end, u16(bootAndKernelSectorCount));
		patch = PatchNext4afc(patch, end, u16(dataOffset));
		patch = PatchNext4afc(patch, end, u16(count * sizeof(ldosFatEntry)));
		m_sName = _strdup("boot.bin");
		ret = ArjPack(0);
	}
	return ret;
}

bool	ldosFile::LoadKernel(const ldosFatEntry* fat, int count)
{

	char sFilename[_MAX_PATH];
	strcpy_s(sFilename, _MAX_PATH, sInstallPath);
	strcat_s(sFilename, _MAX_PATH, "kernel.bin");
	bool ret = false;

	u32 kernelSize = 0;
	m_data = rawFileLoad(sFilename, kernelSize);
	if (m_data)
	{
		assert(0 == (kernelSize & 1));
		m_originalSize = kernelSize + count * sizeof(ldosFatEntry);
		m_data = (u8*)realloc(m_data, m_originalSize);
		memcpy(m_data + kernelSize, fat, count * sizeof(ldosFatEntry));
		ret = ArjPack(4);		// LDOS kernel is packed using arj m4
		m_sName = _strdup("kernel.bin");
	}
	return ret;
}

bool	ldosFile::LoadUserFile(const char* sFilename, int diskId, bool packing)
{
	Release();
	bool bRet = false;
	m_data = rawFileLoad(sFilename, m_originalSize);
	if ((m_data) && ( m_originalSize > 0))
	{
		m_diskId = diskId;
		m_sName = _strdup(sFilename);
		m_type = DetermineFileType(sFilename);
		bRet = ArjPack( packing ? 7 : 0);		// if packed, user file is always packed using arjm7
	}
	else
	{
		printf("ERROR: Unable to read file \"%s\"\n", sFilename);
	}
	return bRet;
}

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
				if (out[count].LoadUserFile(ptr, diskId, packing))
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
	printf("Usage: ldos <script text> <adf disk1> [adf disk2]\n");
	printf("\n");
}

void	ldosFatCreate(const ldosFile* files, int count, ldosFatEntry* out)
{
	u32 diskOffset = 0;
	for (int i = 0; i < count; i++)
	{
		assert(0 == files->m_diskId);

		out->diskOffset = bswap32(diskOffset);
		out->originalSize = bswap32(files->m_originalSize);
		out->packedSize = bswap32(files->m_packedSize);

		u16 flags = 0;
		if (files->m_type == kLSPMusicBank)
			flags |= 1;

		out->flags = bswap16(flags);
		out->pad = 0;

		diskOffset += files->m_packedSize;
		out++;
		files++;
	}
}

void	ldosFile::DisplayInfo(u32 diskOffset, int diskId) const
{
	// display infos
	printf("%6d->%6d (%3d%%) [%d]:$%06x (%s)\n", m_originalSize, m_packedSize, m_packingRatio, diskId, diskOffset, m_sName);
}

u32	ldosFile::OutToDisk(u8* adfBuffer, u32 diskOffset, int diskId) const
{
	DisplayInfo(diskOffset, diskId);
	memcpy(adfBuffer + diskOffset, m_packedData, m_packedSize);
	return m_packedSize;
}

static void	BootSectorExec(u32* pW)
{
	u32 crc = 0;
	for (int i = 0; i < 256; i++)
	{
		u32 iData = bswap32(pW[i]);
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
	int diskId = 0;
	u8* adfBuffer = (u8*)malloc(kMaxAdfSize);
	memset(adfBuffer, 0, kMaxAdfSize);

	u32 diskOffset = 0;
	diskOffset += boot.OutToDisk(adfBuffer, diskOffset, 0);
	diskOffset += kernel.OutToDisk(adfBuffer, diskOffset, 0);
	for (int i = 0; i < count; i++)
	{
		if (files[i].m_packedSize + diskOffset <= kMaxAdfSize)
		{
			diskOffset += files[i].OutToDisk(adfBuffer, diskOffset, diskId);
		}
		else
		{
			files[i].DisplayInfo(diskOffset, diskId);
			printf("FATAL ERROR: Does not fit on the DISK!\n");
			return false;
		}
	}

	// round up to a floppy cylinder size
	diskOffset = (diskOffset + 2 * 11 * 512 - 1)&(-2 * 11 * 512);
	BootSectorExec((u32*)adfBuffer);

	FILE* h;
	if (0 == fopen_s(&h, argv[0], "wb"))
	{
		fwrite(adfBuffer, 1, diskOffset, h);
		fclose(h);
		printf("Total disk size: %d bytes (%dKiB)\n", diskOffset, (diskOffset + 1023) >> 10);
		ret = true;
	}
	else
	{
		printf("ERROR: Unable to create ADF file \"%s\"\n", argv[0]);
	}
	return ret;
}

int	ldosMain(int _argc, char *_argv[])
{
	printf("LDOS Installer v1.30\n");
	printf("Written by Arnaud Carr%c.\n\n", 0x82);

	assert(16 == sizeof(ldosFatEntry));

	int argc = 0;
	char* argv[8] = {};
	for (int i = 0; i < _argc; i++)
	{
		if ('-' == _argv[i][0])
		{
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
	_splitpath_s(argv[0], sDrive, _MAX_DRIVE, sDir, _MAX_DIR, NULL, 0, NULL, 0);
	_makepath_s(sInstallPath, _MAX_PATH, sDrive, sDir, NULL, NULL);
	_makepath_s(sArjPath, _MAX_PATH, sDrive, sDir, "arjbeta", "exe");

	int count = ldosScriptParsing(argv[1], gFileList);
	if (count > 0)
	{
		ldosFatCreate(gFileList, count, gFat);
		ldosFile kernel;
		if (kernel.LoadKernel(gFat, count))
		{
			ldosFile boot;
			if (boot.LoadBoot(kernel, count))
			{
				AdfExport(argv + 2, gFileList, count, boot, kernel);
			}
		}
	}

	return 0;
}

