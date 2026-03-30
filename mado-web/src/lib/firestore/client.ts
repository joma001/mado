import { FirestoreDocument, FirestoreValue, encodeFields, sanitizeUserId } from './codec'

const BASE_URL = 'https://firestore.googleapis.com/v1/projects/mado-ba266/databases/(default)/documents'

export class FirestoreClient {
  constructor(private accessToken: string) {}

  private headers(): HeadersInit {
    return {
      Authorization: `Bearer ${this.accessToken}`,
      'Content-Type': 'application/json',
    }
  }

  userPath(email: string): string {
    return `users/${sanitizeUserId(email)}`
  }

  // GET a single document
  async getDocument(path: string): Promise<FirestoreDocument | null> {
    const res = await fetch(`${BASE_URL}/${path}`, { headers: this.headers() })
    if (res.status === 404) return null
    if (!res.ok) throw new Error(`Firestore GET ${path}: ${res.status} ${await res.text()}`)
    return res.json()
  }

  // LIST documents in a collection
  async listDocuments(collectionPath: string, pageSize = 100): Promise<FirestoreDocument[]> {
    const url = `${BASE_URL}/${collectionPath}?pageSize=${pageSize}`
    const res = await fetch(url, { headers: this.headers() })
    if (!res.ok) throw new Error(`Firestore LIST ${collectionPath}: ${res.status}`)
    const data = await res.json()
    return data.documents ?? []
  }

  // SET (create or overwrite) a document
  async setDocument(path: string, fields: Record<string, FirestoreValue>): Promise<void> {
    const url = `${BASE_URL}/${path}`
    const body = JSON.stringify({ fields })
    const res = await fetch(url, { method: 'PATCH', headers: this.headers(), body })
    if (!res.ok) throw new Error(`Firestore SET ${path}: ${res.status} ${await res.text()}`)
  }

  // DELETE a document
  async deleteDocument(path: string): Promise<void> {
    const res = await fetch(`${BASE_URL}/${path}`, { method: 'DELETE', headers: this.headers() })
    if (!res.ok && res.status !== 404) {
      throw new Error(`Firestore DELETE ${path}: ${res.status}`)
    }
  }

  // BATCH WRITE
  async batchWrite(writes: BatchWrite[]): Promise<void> {
    const url = `${BASE_URL.replace('/documents', '')}:commit`
    const body = JSON.stringify({
      writes: writes.map((w) => {
        if (w.type === 'update') {
          return {
            update: { name: `${BASE_URL}/${w.path}`, fields: w.fields },
          }
        }
        return { delete: `${BASE_URL}/${w.path}` }
      }),
    })
    const res = await fetch(url, { method: 'POST', headers: this.headers(), body })
    if (!res.ok) throw new Error(`Firestore BATCH: ${res.status} ${await res.text()}`)
  }

  // Helper: set document from plain object
  async setDocumentFromObject(path: string, obj: Record<string, unknown>): Promise<void> {
    await this.setDocument(path, encodeFields(obj))
  }
}

type BatchWrite =
  | { type: 'update'; path: string; fields: Record<string, FirestoreValue> }
  | { type: 'delete'; path: string }
