#pragma once
#include <stdint.h>
#include <atomic>

class JobSystem
{
public:
	int		RunJobs(void* items,
					int itemCount,
					bool(*processingFunction)(void* base, int index),
					int workersCount = 0);

private:
	static uint32_t threadMain(void* pUser);
	uint32_t		Start();
	uint8_t* m_base;
	int m_itemCount;
	std::atomic<int> m_itemIndex;
	std::atomic<int> m_itemSucceedCount;
	bool(*m_processingFunction)(void* base, int index);
};
