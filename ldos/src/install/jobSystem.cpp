#include <thread>
#include <assert.h>
#include <time.h>
#include "jobSystem.h"

static const int	kMaxWorkers = 64;

int	JobSystem::RunJobs(void* items, int itemCount, processingFunction func, int workersCount)
{
	if (0 == itemCount)
		return 0;

	if (0 == workersCount)
	{
		workersCount = std::thread::hardware_concurrency();
		if ( 0 == workersCount )
			workersCount = 1;
	}

	if (workersCount > itemCount)
		workersCount = itemCount;
	if (workersCount > kMaxWorkers)
		workersCount = kMaxWorkers;

	extern bool gQuickMode;
	if (gQuickMode)
		printf("(compression ratio warning: quick mode active)\n");
	else
		printf("(you can use -quick for faster compression during dev)\n");
	printf("Packing (deflate) %d files using %d threads...\n", itemCount, workersCount);
	clock_t t0 = clock();

	m_items = items;
	m_itemCount = itemCount;
	m_itemIndex = 0;
	m_itemSucceedCount = 0;
	m_processingFunction = func;

	std::thread* pThreads[kMaxWorkers];
	for (int t = 0; t < workersCount; t++)
		pThreads[t] = new std::thread([this] { Start(); });

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
void JobSystem::Start()
{
	for (;;)
	{
		const int id = m_itemIndex.fetch_add(1);
		if (id >= m_itemCount)
			break;

		if (m_processingFunction(m_items, id))
			m_itemSucceedCount.fetch_add(1);
	}
}