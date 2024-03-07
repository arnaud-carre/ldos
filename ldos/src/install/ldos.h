#pragma once

typedef unsigned char	u8;
typedef unsigned short	u16;
typedef unsigned int	u32;
typedef signed char		s8;
typedef signed short	s16;
typedef signed int		s32;

enum ldosFileType
{
	kUnknownRawBinary = 0,
	kAmigaExeFile,
	kLSPMusicScore,
	kLSPMusicBank,
	kLSPMaxFileType
};

enum ldosPackType
{
	kNone,
	kArjm4,
	kArjm7,
};

struct ldosFatEntry 
{
	u32	diskOffset;
	u32 packedSize;
	u32 originalSize;
	u16	flags;
	u16 pad;
};

struct  ldosFile
{
	ldosFile()
	{
		m_data = NULL;
		m_packedData = NULL;
		m_sName = NULL;
		m_type = kUnknownRawBinary;
		memset(m_sectionSizes, 0, sizeof(m_sectionSizes));
	}

	bool	LoadUserFile(const char* sFilename, int diskId, bool packing);
	bool	LoadKernel(const ldosFatEntry* fat, int count);
	bool	LoadBoot(const ldosFile& kernel, int count);
	void	DisplayInfo(u32 diskOffset) const;
	u32		OutToDisk(u8* adfBuffer, u32 diskOffset) const;
	u8*		ArjDataExtract(const u8* arj, int method, u32& outSize);

	void amigaExeGetMemoryLayout(const u32* data);
	ldosFileType	DetermineFileType(const char* sFilename);
	void			Release();
	bool			ArjPack(int method);

	int		m_diskId;
	u8*		m_data;
	u32		m_originalSize;
	u8*		m_packedData;
	char*	m_sName;
	u32		m_packedSize;
	int		m_packingRatio;
	int		m_packingMethod;
	
	struct sectionSize
	{
		int m_code;
		int m_data;
		int m_bss;
	};

	sectionSize m_sectionSizes[2];		// chip & fake
	ldosFileType	m_type;
};
