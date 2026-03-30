// Firestore REST API value encoding/decoding
// Must match native Swift FirestoreClient.swift exactly

export type FirestoreValue =
  | { stringValue: string }
  | { integerValue: string } // integers encoded as strings
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { timestampValue: string } // ISO8601
  | { arrayValue: { values?: FirestoreValue[] } }
  | { mapValue: { fields?: Record<string, FirestoreValue> } }
  | { nullValue: null }

export type FirestoreDocument = {
  name?: string
  fields?: Record<string, FirestoreValue>
  createTime?: string
  updateTime?: string
}

// Encode a JS value to Firestore REST format
export function encode(value: unknown): FirestoreValue {
  if (value === null || value === undefined) {
    return { nullValue: null }
  }
  if (typeof value === 'string') {
    return { stringValue: value }
  }
  if (typeof value === 'boolean') {
    return { booleanValue: value }
  }
  if (typeof value === 'number') {
    if (Number.isInteger(value)) {
      return { integerValue: String(value) }
    }
    return { doubleValue: value }
  }
  if (value instanceof Date) {
    return { timestampValue: value.toISOString() }
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map(encode),
      },
    }
  }
  if (typeof value === 'object') {
    const fields: Record<string, FirestoreValue> = {}
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      fields[k] = encode(v)
    }
    return { mapValue: { fields } }
  }
  return { nullValue: null }
}

// Decode a Firestore REST value to JS
export function decode(value: FirestoreValue): unknown {
  if ('stringValue' in value) return value.stringValue
  if ('integerValue' in value) return parseInt(value.integerValue, 10)
  if ('doubleValue' in value) return value.doubleValue
  if ('booleanValue' in value) return value.booleanValue
  if ('timestampValue' in value) return value.timestampValue
  if ('nullValue' in value) return null
  if ('arrayValue' in value) {
    return (value.arrayValue.values ?? []).map(decode)
  }
  if ('mapValue' in value) {
    const result: Record<string, unknown> = {}
    const fields = value.mapValue.fields ?? {}
    for (const [k, v] of Object.entries(fields)) {
      result[k] = decode(v)
    }
    return result
  }
  return null
}

// Decode a full Firestore document to a plain object
export function decodeDocument(doc: FirestoreDocument): Record<string, unknown> {
  const result: Record<string, unknown> = {}
  if (!doc.fields) return result
  for (const [key, value] of Object.entries(doc.fields)) {
    result[key] = decode(value)
  }
  return result
}

// Encode a plain object to Firestore document fields
export function encodeFields(obj: Record<string, unknown>): Record<string, FirestoreValue> {
  const fields: Record<string, FirestoreValue> = {}
  for (const [key, value] of Object.entries(obj)) {
    fields[key] = encode(value)
  }
  return fields
}

// Extract document ID from Firestore document name
export function extractDocId(name: string): string {
  return name.split('/').pop() ?? ''
}

// Sanitize email to Firestore user path
export function sanitizeUserId(email: string): string {
  return email.replace(/@/g, '_at_').replace(/\./g, '_')
}

// Sanitize calendar ID for document path
export function sanitizeCalendarId(calendarId: string): string {
  return calendarId.replace(/\//g, '_')
}

// Sanitize file name for notes document path
export function sanitizeFileName(fileName: string): string {
  return fileName.replace(/\//g, '__').replace(/\./g, '_')
}
