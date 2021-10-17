#pragma once

typedef unsigned char	u8;
typedef unsigned short	u16;
typedef unsigned int	u32;
typedef signed char		s8;
typedef signed short	s16;
typedef signed int		s32;


enum ldosFileType
{
	kUnknownRawBinary,
	kBootSector,
	kLDOSKernel,
	kAmigaExeFile,
	kLSPMusicScore,
	kLSPMusicBank,
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
	ldosFile::ldosFile()
	{
		m_data = NULL;
		m_packedData = NULL;
		m_sName = NULL;
	}

	bool	LoadUserFile(const char* sFilename, int diskId, bool packing);
	bool	LoadKernel(const ldosFatEntry* fat, int count);
	bool	LoadBoot(const ldosFile& kernel, int count);
	void	DisplayInfo(u32 diskOffset, int diskId) const;
	u32		OutToDisk(u8* adfBuffer, u32 diskOffset, int diskId) const;

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
	ldosFileType	m_type;
};
