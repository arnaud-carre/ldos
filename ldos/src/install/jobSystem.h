#pragma once
#include <thread>
#include <atomic>

static const int kMaxWorkers = 64;

class JobSystem
{
public:
	typedef bool (*processingFunction)(void* firstItem, int index);
	int	RunJobs(void* items,
					int itemCount,
					processingFunction func,
					int workersCount = 0);
	int Complete();

private:
	void	Start();
	void* m_items;
	int m_itemCount;
	std::atomic<int> m_itemIndex;
	std::atomic<int> m_itemSucceedCount;
	processingFunction m_processingFunction;
	std::thread* m_pThreads[kMaxWorkers];
	clock_t m_t0;
	int m_workerCount;
};
