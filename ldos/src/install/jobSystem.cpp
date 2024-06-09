#include <thread>
#include <assert.h>
#include <time.h>
#include "jobSystem.h"

static const int	kMaxWorkers = 64;

uint32_t JobSystem::threadMain(void* data)
{
	JobSystem* js = (JobSystem*)data;
	return js->Start();
}

int	JobSystem::RunJobs(void* items, int itemCount, bool(*processingFunction)(void* base, int index), int workersCount)
{
	if (0 == itemCount)
		return 0;

	if (0 == workersCount)
		workersCount = std::thread::hardware_concurrency();

	if (workersCount > itemCount)
		workersCount = itemCount;

	if (workersCount <= 0)
		workersCount = 1;
	else if (workersCount > kMaxWorkers)
		workersCount = kMaxWorkers;

	extern bool gQuickMode;
	if (gQuickMode)
		printf("(compression ratio warning: quick mode active)\n");
	else
		printf("(you can use -quick for faster compression during dev)\n");
	printf("Packing (deflate) %d files using %d threads...\n", itemCount, workersCount);
	clock_t t0 = clock();

	m_base = (uint8_t*)items;
	m_itemCount = itemCount;
	m_itemIndex = 0;
	m_itemSucceedCount = 0;
	m_processingFunction = processingFunction;

	std::thread* pThreads[kMaxWorkers];
	for (int t = 0; t < workersCount; t++)
		pThreads[t] = new std::thread(JobSystem::threadMain, this);

	// wait for all threads to finish
	for (int t = 0; t < workersCount; t++)
	{
		pThreads[t]->join();
		delete pThreads[t];
	}

	clock_t t1 = clock();
	float t = float(t1 - t0) / float(CLOCKS_PER_SEC);
	printf("%d jobs succeed in %.02f sec\n", m_itemSucceedCount.load(), t);

	return m_itemSucceedCount;
}

// Grab jobs as fast as possible
uint32_t JobSystem::Start()
{
	for (;;)
	{
		int id = m_itemIndex.fetch_add(1); //InterlockedIncrement((volatile LONG *)&m_itemIndex) - 1;
		if (id >= m_itemCount)
			break;

		if (m_processingFunction(m_base,id))
			m_itemSucceedCount.fetch_add(1);
	}
	return 0;
}