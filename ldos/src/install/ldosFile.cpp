#include <stdio.h>
#include <assert.h>
#include "ldosFile.h"
#include "external/zopfli/deflate.h"
#include "external/salvador/libsalvador.h"


uint32_t bswap32(uint32_t v)
{
	return (((v & 0xff000000) >> 24) |
		((v & 0x00ff0000) >> 8) |
		((v & 0x0000ff00) << 8) |
		((v & 0x000000ff) << 24));
}

uint16_t bswap16(uint16_t v)
{
	return (v >> 8) | (v << 8);
}

static uint16_t* PatchNext4afc(uint16_t* patch, uint16_t* end, uint16_t value)
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
	printf("ERROR: Unable to patch value #$%04x!\n", value);
	return NULL;
}

static void	amigaExeGetMemoryLayout(const uint32_t* data, int& outChip, int& outFake)
{

	outChip = 0;
	outFake = 0;
	assert(bswap32(data[0]) == 0x3f3);
	if (0 == bswap32(data[1]))
	{
		int hunkCount = bswap32(data[2]);
		data += 5;		// skip first and last hunk
		bool chip[16] = {};
		for (int i = 0; i < hunkCount; i++)
		{
			uint32_t v = bswap32(data[0]);
			int size = (v & 0x00ffffff) << 2;		// size in bytes
			if (v & (1 << 30))
			outChip += size;
			else
			outFake += size;
			chip[i] = (v & (1 << 30)) != 0;
			data++;
		}

		int type[16] = {};
		static const char* sType[3] = { "CODE", "DATA", "BSS " };
		for (int i = 0; i < hunkCount; i++)
		{
			uint32_t hunkId = bswap32(*data++) & 0x00ffffff;
			uint32_t sizeInDword = bswap32(*data++);
			switch (hunkId)
			{
				case 0x3e9:		// code
//					printf("  %s: Section CODE of %d KiB\n", chip[i]?"CHIP":"ANY ",(sizeInDword << 2) >> 10);
					type[i] = 0;
					data += sizeInDword;
					break;
				case 0x3ea:		// data
//					printf("  %s: Section DATA of %d KiB\n", chip[i]?"CHIP":"ANY ", (sizeInDword << 2) >> 10);
					data += sizeInDword;
					type[i] = 1;
					break;
				case 0x3eb:		// bss
//					printf("  %s: Section BSS of %d KiB\n", chip[i]?"CHIP":"ANY ", (sizeInDword << 2) >> 10);
					type[i] = 2;
					break;
				default:
//					printf("Unknown hunk $%08x\n", hunkId);
					break;
			}

			uint32_t endMarker = bswap32(*data++);
			if ( endMarker == 0x3ec)		// relocation table
			{
				for (;;)
				{
					uint32_t offCount = bswap32(*data++);
					if (0 == offCount)
						break;
					uint32_t targetId = bswap32(*data++);
					assert(targetId < uint32_t(hunkCount));
//					printf("    %d offset to patch refering hunk #%d\n", offCount, targetId);
					data += offCount;	// skip all offsets
				}
				endMarker = bswap32(*data++);
			}
			if ( endMarker != 0x3f2)
			{
				printf("Error in hunk parsing\n");
			}
		}
//		printf("--------- Amiga EXE: %d hunks\n", hunkCount);
	}
}



void* zx0_pack(const void* dataIn, int inSize, int* outSize, int* safeDist)
{
	*outSize = 0;
	*safeDist = 0;
	size_t outBufferSize = salvador_get_max_compressed_size(inSize) + 1; // always 1 more in case of even size align
	void* outBuffer = malloc(outBufferSize);
	if (outBuffer)
	{
		salvador_stats stats;
		size_t rc = salvador_compress((const unsigned char*)dataIn, (unsigned char*)outBuffer, inSize, outBufferSize, FLG_IS_INVERTED, 0, 0, nullptr, &stats);
		if (rc != -1)
		{
			rc = (rc + 1) & (-2);			// always align file size on 2 bytes in LDOS
			*outSize = int(rc);
			*safeDist = stats.safe_dist;
		}
		else
		{
			free(outBuffer);
			outBuffer = nullptr;
		}
	}
	return outBuffer;
}

void* deflate_pack(const void* dataIn, int inSize, int* outSize, int* safeDist)
{
	ZopfliOptions options;
	ZopfliFormat output_type = ZOPFLI_FORMAT_DEFLATE;

	*safeDist = 0;
	*outSize = 0;

	extern bool gQuickMode;
	ZopfliInitOptions(&options, gQuickMode?1:0);

	size_t packedSize = 0;
	unsigned char* packedBuffer = nullptr;
	ZopfliCompress(&options, output_type, (const unsigned char*)dataIn, size_t(inSize), &packedBuffer, &packedSize);

	if (packedBuffer)
		*outSize = int(packedSize);

	return packedBuffer;
}


bool ldosFile::LoadRawFile(const char* sFilename)
{
	bool ret = false;
	Release();
	FILE* h;
	fopen_s(&h, sFilename, "rb");
	if (h)
	{
		fseek(h, 0, SEEK_END);
		int fsize = ftell(h);
		m_infos.m_originalSize = (fsize + 1) & (-2);			// always 2 bytes align input file
		fseek(h, 0, SEEK_SET);
		m_data = (uint8_t*)malloc(m_infos.m_originalSize);
		if (m_data)
		{
			memset(m_data, 0, m_infos.m_originalSize);	// (in case of odd size, clear till last aligned byte)
			fread(m_data, 1, fsize, h);
			m_infos.m_sName = _strdup(sFilename);
			ret = true;
		}
		fclose(h);
	}
	return ret;
}

bool ldosFile::LoadUserFile(const char* sFilename, bool packing)
{
	if (!LoadRawFile(sFilename))
		return false;

	DetermineFileType(sFilename);

	m_targetPackType = packing ? ldosPackType::kDeflate : ldosPackType::kNone;
	return true;
}

bool	ldosFile::LoadKernel(const char* sFilename, const ldosFatEntry* fat, int count)
{
	if (!LoadRawFile(sFilename))
		return false;

	m_targetPackType = ldosPackType::kZx0;
	m_infos.m_chipSize = 0;
	m_infos.m_fakeSize = m_infos.m_originalSize;
	assert(0 == (m_infos.m_originalSize&1));
	int kernelSize = m_infos.m_originalSize;
	m_infos.m_originalSize += count * sizeof(ldosFatEntry);				// happen the FAT at the end of kernel.bin file
	m_data = (uint8_t*)realloc(m_data, m_infos.m_originalSize);
	memcpy(m_data + kernelSize, fat, count * sizeof(ldosFatEntry));

	uint16_t* patch = (uint16_t*)m_data;
	patch = PatchNext4afc(patch, patch+64, uint16_t(count * sizeof(ldosFatEntry)));

	printf("Packing (ZX0) LDOS kernel.bin & FAT\n");
	return Compress();
}

bool	ldosFile::LoadBoot(const char* sFilename, const ldosFile::Info& kernelInfos, int count)
{
	if (!LoadRawFile(sFilename))
		return false;

	m_targetPackType = ldosPackType::kNone;

	uint16_t* patch = (uint16_t*)m_data;
	uint16_t* end = (uint16_t*)(m_data + m_infos.m_originalSize);

	int dataOffset = m_infos.m_originalSize + kernelInfos.m_packedSize;
	assert(0 == (dataOffset & 1));
	assert(dataOffset < 0xffff);

	patch = PatchNext4afc(patch, end, uint16_t((dataOffset+511)&(-512)));
	patch = PatchNext4afc(patch, end, uint16_t(dataOffset));

	return Compress();
}



bool	ldosFile::Compress()
{
	bool ret = false;

	int packedSize = 0;
	int safeDist = 0;
	switch ( m_targetPackType )
	{
		case ldosPackType::kNone:
		{
			// no packing
			packedSize = m_infos.m_originalSize;
			m_packedData = (uint8_t*)malloc(packedSize);
			memcpy(m_packedData, m_data, packedSize);
		}
		break;

		case ldosPackType::kZx0:
		{
			m_packedData = (uint8_t*)zx0_pack(m_data, m_infos.m_originalSize, &packedSize, &safeDist);
		}
		break;

		case ldosPackType::kDeflate:
		{
			m_packedData = (uint8_t*)deflate_pack(m_data, m_infos.m_originalSize, &packedSize, &safeDist);
		}
		break;
		default:
			assert(false);
			break;
	}

	if (m_packedData)
	{
		if ( packedSize & 1 )
		{
			// always align on 2 bytes
			m_packedData = (uint8_t *)realloc(m_packedData, packedSize + 1);
			m_packedData[packedSize] = 0;
			packedSize++;
		}

		assert(0 == (packedSize&1));
		m_infos.m_packedSize = packedSize;
		m_infos.m_packingRatio = (m_infos.m_packedSize * 100) / m_infos.m_originalSize;
		ret = true;
	}

	if (ret)
		m_infos.m_packType = m_targetPackType;

	return ret;
}

void	ldosFile::Release()
{
	free(m_data);
	free(m_packedData);
	free(m_infos.m_sName);
	m_data = nullptr;
	m_packedData = nullptr;
	m_infos.m_originalSize = 0;
	m_infos.m_packedSize = 0;
	m_infos.m_type = kUnknownRawBinary;
	m_infos.m_sName = nullptr;
}

const char* getFileExt(const char* sFilename)
{
	const char* s0 = sFilename;
	const char* s = s0 + strlen(sFilename);
	while ( s > s0 )
	{
		if (*s == '.')
			return s;
		s--;
	}
	return nullptr;
}

void	ldosFile::DetermineFileType(const char* sFilename)
{
	m_infos.m_type = kUnknownRawBinary;
	if ((m_data) && (m_infos.m_originalSize >= 4))
	{
		const uint32_t* r = (const uint32_t*)m_data;
		if (0x3f3 == bswap32(r[0]))
		{
			amigaExeGetMemoryLayout(r, m_infos.m_chipSize, m_infos.m_fakeSize);
			m_infos.m_type = kAmigaExeFile;
		}
		else if ('LSP1' == bswap32(r[0]))
		{
			m_infos.m_type = kLSPMusicScore;
			m_infos.m_fakeSize = m_infos.m_originalSize;
		}
		else
		{
			const char* fExt = getFileExt(sFilename);
			if ( (fExt) && (0 == _stricmp(fExt, ".lsbank")))
			{
				m_infos.m_type = kLSPMusicBank;
				m_infos.m_chipSize = m_infos.m_originalSize;
			}
		}
	}
}

void	ldosFile::DisplayInfo(uint32_t diskOffset) const
{
	// display infos
	static const char* sTypes[kLSPMaxFileType] = 
	{
		"Bin",
		"Exe",
		"LSM",
		"LSB",
	};
	printf("  $%06x [%s] Packing %6d->%6d (%3d%%) Chip:%3dKiB Fake:%3dKiB  (%s)\n", diskOffset, sTypes[int(m_infos.m_type)], m_infos.m_originalSize, m_infos.m_packedSize, m_infos.m_packingRatio, (m_infos.m_chipSize + 1023) >> 10, (m_infos.m_fakeSize + 1023) >> 10, m_infos.m_sName);
}

uint32_t	ldosFile::OutToDisk(uint8_t* adfBuffer, uint32_t diskOffset, uint32_t maxDiskSize) const
{
	DisplayInfo(diskOffset);

	// files in final disk are always aligned to 2 bytes
	int alignedSize = (m_infos.m_packedSize + 1) & (-2);

	if ( diskOffset + alignedSize <= maxDiskSize )
		memcpy(adfBuffer + diskOffset,m_packedData, m_infos.m_packedSize);

	return diskOffset + alignedSize;
}
