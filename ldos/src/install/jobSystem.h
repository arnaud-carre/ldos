#pragma once
#include <stdint.h>
#include <atomic>

class JobSystem
{
public:
	int		RunJobs(void* items,
					int itemSizeof,
					int itemCount,
					bool(*processingFunction)(void* item),
					int workersCount = 0);

private:
	static uint32_t threadMain(void* pUser);
	uint32_t		Start();
	uint8_t* m_items;
	int m_itemSizeof;
	int volatile m_itemCount;
	std::atomic<int32_t> m_itemIndex;
	std::atomic<int32_t> m_itemSucceedCount;
	bool(*m_processingFunction)(void* item);
};
