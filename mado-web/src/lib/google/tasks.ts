import type { Task, TaskList } from '@/types/task'

const BASE = 'https://www.googleapis.com/tasks/v1'

export class GoogleTasksClient {
  constructor(private accessToken: string) {}

  private headers(): HeadersInit {
    return { Authorization: `Bearer ${this.accessToken}` }
  }

  private async fetchWithRetry(url: string, init?: RequestInit, retries = 3): Promise<Response> {
    for (let i = 0; i < retries; i++) {
      const res = await fetch(url, { ...init, headers: { ...this.headers(), ...init?.headers } })
      if (res.status === 429 || res.status >= 500) {
        await new Promise((r) => setTimeout(r, Math.pow(2, i) * 1000))
        continue
      }
      return res
    }
    return fetch(url, { ...init, headers: { ...this.headers(), ...init?.headers } })
  }

  async listTaskLists(): Promise<TaskList[]> {
    const res = await this.fetchWithRetry(`${BASE}/users/@me/lists`)
    if (!res.ok) throw new Error(`listTaskLists: ${res.status}`)
    const data = await res.json()
    return (data.items ?? []).map((l: { id: string; title: string }) => ({
      id: l.id,
      title: l.title,
    }))
  }

  async listTasks(listId: string, showCompleted = false): Promise<Omit<Task, 'priority' | 'labelIds' | 'recurrenceData'>[]> {
    const params = new URLSearchParams({
      maxResults: '100',
      showCompleted: String(showCompleted),
      showHidden: String(showCompleted),
    })
    const res = await this.fetchWithRetry(`${BASE}/lists/${encodeURIComponent(listId)}/tasks?${params}`)
    if (!res.ok) throw new Error(`listTasks: ${res.status}`)
    const data = await res.json()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return (data.items ?? []).map((t: any) => ({
      id: t.id,
      title: t.title ?? '',
      notes: t.notes,
      status: t.status ?? 'needsAction',
      dueDate: t.due,
      completedDate: t.completed,
      parentTaskId: t.parent,
      position: parseInt(t.position ?? '0', 10),
      taskListId: listId,
    }))
  }

  async createTask(listId: string, task: { title: string; notes?: string; due?: string }): Promise<string> {
    const body: Record<string, unknown> = { title: task.title }
    if (task.notes) body.notes = task.notes
    if (task.due) body.due = task.due
    const res = await this.fetchWithRetry(
      `${BASE}/lists/${encodeURIComponent(listId)}/tasks`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
    )
    if (!res.ok) throw new Error(`createTask: ${res.status}`)
    const data = await res.json()
    return data.id
  }

  async updateTask(listId: string, taskId: string, updates: { title?: string; notes?: string; status?: string; due?: string | null }): Promise<void> {
    const res = await this.fetchWithRetry(
      `${BASE}/lists/${encodeURIComponent(listId)}/tasks/${encodeURIComponent(taskId)}`,
      { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(updates) }
    )
    if (!res.ok) throw new Error(`updateTask: ${res.status}`)
  }

  async deleteTask(listId: string, taskId: string): Promise<void> {
    const res = await this.fetchWithRetry(
      `${BASE}/lists/${encodeURIComponent(listId)}/tasks/${encodeURIComponent(taskId)}`,
      { method: 'DELETE' }
    )
    if (!res.ok && res.status !== 404) throw new Error(`deleteTask: ${res.status}`)
  }

  async moveTask(listId: string, taskId: string, parent?: string, previous?: string): Promise<void> {
    const params = new URLSearchParams()
    if (parent) params.set('parent', parent)
    if (previous) params.set('previous', previous)
    const res = await this.fetchWithRetry(
      `${BASE}/lists/${encodeURIComponent(listId)}/tasks/${encodeURIComponent(taskId)}/move?${params}`,
      { method: 'POST' }
    )
    if (!res.ok) throw new Error(`moveTask: ${res.status}`)
  }
}
