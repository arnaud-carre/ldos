#pragma once
#include <stdint.h>

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
	kUnknown,
	kNone,
	kZx0,
	kDeflate
};

struct ldosFatEntry 
{
	uint32_t	diskOffset;
	uint32_t packedSize;
	uint32_t originalSize;
	uint16_t	flags;
	uint16_t pad;
};

class  ldosFile
{
public:

	struct Info
	{
		char*		m_sName;
		uint32_t	m_originalSize;
		uint32_t	m_packedSize;
		int			m_packingRatio;
		int			m_chipSize;
		int			m_fakeSize;
		ldosFileType	m_type;
		ldosPackType m_packType;

		Info()
		{
			m_sName = nullptr;
			m_type = kUnknownRawBinary;
			m_packType = kUnknown;
			m_chipSize = 0;
			m_fakeSize = 0;
		};
	};

	ldosFile()
	{
		m_data = nullptr;
		m_packedData = nullptr;
		m_targetPackType = kUnknown;
	};

	bool		LoadUserFile(const char* sFilename, bool packing);
	bool		LoadKernel(const char* sFilename, const ldosFatEntry* fat, int count);
	bool		LoadBoot(const char* sFilename, const ldosFile::Info& kernelInfos, int count);
	uint32_t	OutToDisk(uint8_t* adfBuffer, uint32_t diskOffset, uint32_t maxDiskSize) const;
	const Info&	GetInfo() const { return m_infos; };
	void DisplayInfo(uint32_t diskOffset) const;
	bool			Compress();

private:
	void	DetermineFileType(const char* sFilename);
	void			Release();
	bool LoadRawFile(const char* sFilename);

	uint8_t*	m_data;
	uint8_t*	m_packedData;
	ldosPackType m_targetPackType;
	Info m_infos;
};

uint32_t bswap32(uint32_t v);
uint16_t bswap16(uint16_t v);

