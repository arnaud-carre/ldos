#pragma once
#include <atomic>


class JobSystem
{
public:
	typedef bool (*processingFunction)(void* firstItem, int index);
	int		RunJobs(void* items,
					int itemCount,
					processingFunction func,
					int workersCount = 0);

private:
	void	Start();
	void* m_items;
	int m_itemCount;
	std::atomic<int> m_itemIndex;
	std::atomic<int> m_itemSucceedCount;
	processingFunction m_processingFunction;
};
