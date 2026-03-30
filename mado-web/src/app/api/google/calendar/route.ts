import { getServerSession } from 'next-auth'
import { NextRequest, NextResponse } from 'next/server'
import { authOptions } from '@/lib/auth'
import { GoogleCalendarClient } from '@/lib/google/calendar'

async function getClient() {
  const session = await getServerSession(authOptions)
  if (!session?.accessToken) return null
  return new GoogleCalendarClient(session.accessToken)
}

export async function GET(req: NextRequest) {
  const client = await getClient()
  if (!client) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { searchParams } = req.nextUrl
  const action = searchParams.get('action') ?? 'listCalendars'

  try {
    if (action === 'listCalendars') {
      const calendars = await client.listCalendars()
      return NextResponse.json(calendars)
    }
    if (action === 'listEvents') {
      const calendarId = searchParams.get('calendarId') ?? 'primary'
      const timeMin = searchParams.get('timeMin')!
      const timeMax = searchParams.get('timeMax')!
      const events = await client.listEvents(calendarId, timeMin, timeMax)
      return NextResponse.json(events)
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
    const { action, calendarId, ...payload } = body

    if (action === 'create') {
      const event = await client.createEvent(calendarId ?? 'primary', payload)
      return NextResponse.json(event)
    }
    if (action === 'update') {
      const event = await client.updateEvent(calendarId, payload.eventId, payload, payload.etag)
      return NextResponse.json(event)
    }
    if (action === 'delete') {
      await client.deleteEvent(calendarId, payload.eventId)
      return NextResponse.json({ ok: true })
    }
    if (action === 'rsvp') {
      await client.rsvp(calendarId, payload.eventId, payload.response, payload.email)
      return NextResponse.json({ ok: true })
    }
    return NextResponse.json({ error: 'Unknown action' }, { status: 400 })
  } catch (e) {
    return NextResponse.json({ error: String(e) }, { status: 500 })
  }
}
