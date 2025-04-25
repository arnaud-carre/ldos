#include <thread>
#include <assert.h>
#include <time.h>
#include "jobSystem.h"

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

	m_workerCount = workersCount;

	m_t0 = clock();

	m_items = items;
	m_itemCount = itemCount;
	m_itemIndex = 0;
	m_itemSucceedCount = 0;
	m_processingFunction = func;

	for (int t = 0; t < workersCount; t++)
		m_pThreads[t] = new std::thread([this] { Start(); });

	return workersCount;
}

int JobSystem::Complete()
{
	// wait for all threads to finish
	for (int t = 0; t < m_workerCount; t++)
	{
		m_pThreads[t]->join();
		delete m_pThreads[t];
	}

	clock_t t1 = clock();
	float t = float(t1 - m_t0) / float(CLOCKS_PER_SEC);
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