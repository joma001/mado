import { getServerSession } from 'next-auth'
import { NextRequest, NextResponse } from 'next/server'
import { authOptions } from '@/lib/auth'
import { GoogleTasksClient } from '@/lib/google/tasks'

async function getClient() {
  const session = await getServerSession(authOptions)
  if (!session?.accessToken) return null
  return new GoogleTasksClient(session.accessToken)
}

export async function GET(req: NextRequest) {
  const client = await getClient()
  if (!client) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { searchParams } = req.nextUrl
  const action = searchParams.get('action') ?? 'listTaskLists'

  try {
    if (action === 'listTaskLists') {
      const lists = await client.listTaskLists()
      return NextResponse.json(lists)
    }
    if (action === 'listTasks') {
      const listId = searchParams.get('listId')!
      const showCompleted = searchParams.get('showCompleted') === 'true'
      const tasks = await client.listTasks(listId, showCompleted)
      return NextResponse.json(tasks)
    }
    return NextResponse.json({ error: 'Unknown action' }, { status: 400 })
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 })
  }
}

export async function POST(req: NextRequest) {
  const client = await getClient()
  if (!client) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  try {
    const body = await req.json()
    const { action, listId, taskId, ...payload } = body

    if (action === 'create') {
      const id = await client.createTask(listId, payload)
      return NextResponse.json({ id })
    }
    if (action === 'update') {
      await client.updateTask(listId, taskId, payload)
      return NextResponse.json({ ok: true })
    }
    if (action === 'delete') {
      await client.deleteTask(listId, taskId)
      return NextResponse.json({ ok: true })
    }
    if (action === 'move') {
      await client.moveTask(listId, taskId, payload.parent, payload.previous)
      return NextResponse.json({ ok: true })
    }
    return NextResponse.json({ error: 'Unknown action' }, { status: 400 })
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 })
  }
}
