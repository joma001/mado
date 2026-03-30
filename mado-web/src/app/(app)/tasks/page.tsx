'use client'

import { useEffect } from 'react'
import { useTaskStore } from '@/stores/taskStore'

export default function TasksPage() {
  const { taskLists, tasks, selectedListId, isLoading, fetchTaskLists, fetchLabels, fetchTaskMeta, setSelectedList } = useTaskStore()

  useEffect(() => {
    fetchTaskLists()
    fetchLabels()
    fetchTaskMeta()
  }, [fetchTaskLists, fetchLabels, fetchTaskMeta])

  return (
    <div className="flex h-full">
      {/* Task Lists sidebar */}
      <div className="w-48 border-r border-divider bg-surface-secondary p-3">
        <p className="mb-2 text-xs font-medium text-text-tertiary">Projects</p>
        {taskLists.map((list) => (
          <button
            key={list.id}
            onClick={() => setSelectedList(list.id)}
            className={`w-full rounded-md px-3 py-1.5 text-left text-sm ${
              selectedListId === list.id ? 'bg-accent-light text-accent font-medium' : 'text-text-secondary hover:bg-hover-bg'
            }`}
          >
            {list.title}
          </button>
        ))}
      </div>

      {/* Task list */}
      <div className="flex-1 overflow-y-auto p-4">
        <h2 className="mb-4 text-lg font-semibold text-text-primary">
          {taskLists.find((l) => l.id === selectedListId)?.title ?? 'Tasks'}
        </h2>
        {isLoading ? (
          <div className="flex justify-center py-8">
            <div className="h-5 w-5 animate-spin rounded-full border-2 border-accent border-t-transparent" />
          </div>
        ) : tasks.length === 0 ? (
          <p className="py-8 text-center text-sm text-text-tertiary">No tasks yet</p>
        ) : (
          <div className="space-y-1">
            {tasks.map((task) => (
              <div key={task.id} className="flex items-center gap-3 rounded-lg px-3 py-2 hover:bg-hover-bg">
                <input
                  type="checkbox"
                  checked={task.status === 'completed'}
                  readOnly
                  className="h-4 w-4 rounded border-border accent-accent"
                />
                <span className={`flex-1 text-sm ${task.status === 'completed' ? 'text-text-tertiary line-through' : 'text-text-primary'}`}>
                  {task.title}
                </span>
                {task.priority > 0 && (
                  <span className={`text-[10px] font-bold ${
                    task.priority === 3 ? 'text-priority-high' : task.priority === 2 ? 'text-priority-medium' : 'text-priority-low'
                  }`}>
                    P{task.priority}
                  </span>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
