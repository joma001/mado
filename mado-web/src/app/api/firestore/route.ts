import { getServerSession } from 'next-auth'
import { NextRequest, NextResponse } from 'next/server'
import { authOptions } from '@/lib/auth'
import { FirestoreClient } from '@/lib/firestore/client'
import { encodeFields, type FirestoreValue } from '@/lib/firestore/codec'

async function getClient() {
  const session = await getServerSession(authOptions)
  if (!session?.accessToken) return null
  return { client: new FirestoreClient(session.accessToken), email: session.user?.email ?? '' }
}

export async function GET(req: NextRequest) {
  const result = await getClient()
  if (!result) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  const { client, email } = result

  const { searchParams } = req.nextUrl
  const collection = searchParams.get('collection')!
  const docId = searchParams.get('docId')
  const userPath = client.userPath(email)

  try {
    if (docId) {
      const doc = await client.getDocument(`${userPath}/${collection}/${docId}`)
      return NextResponse.json(doc)
    }
    const docs = await client.listDocuments(`${userPath}/${collection}`)
    return NextResponse.json(docs)
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 })
  }
}

export async function POST(req: NextRequest) {
  const result = await getClient()
  if (!result) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  const { client, email } = result

  try {
    const body = await req.json()
    const { action, collection, docId, fields } = body as {
      action: 'set' | 'delete'
      collection: string
      docId: string
      fields?: Record<string, unknown>
    }
    const userPath = client.userPath(email)
    const path = `${userPath}/${collection}/${docId}`

    if (action === 'set' && fields) {
      await client.setDocument(path, encodeFields(fields) as Record<string, FirestoreValue>)
      return NextResponse.json({ ok: true })
    }
    if (action === 'delete') {
      await client.deleteDocument(path)
      return NextResponse.json({ ok: true })
    }
    return NextResponse.json({ error: 'Unknown action' }, { status: 400 })
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 })
  }
}
