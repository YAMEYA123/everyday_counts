import Dexie, { type Table } from 'dexie'

export interface DailyEntry {
  id?: number
  date: string        // "2026-07-13"
  dataUrl: string     // compressed base64 JPEG
  createdAt: number
  updatedAt: number
}

class EverydayDB extends Dexie {
  entries!: Table<DailyEntry>

  constructor() {
    super('everyday-counts')
    this.version(1).stores({
      entries: '++id, date',
    })
  }
}

export const db = new EverydayDB()

export function todayKey(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

export async function getTodayEntry(): Promise<DailyEntry | undefined> {
  return db.entries.where('date').equals(todayKey()).first()
}

export async function upsertEntry(date: string, dataUrl: string): Promise<void> {
  const existing = await db.entries.where('date').equals(date).first()
  const now = Date.now()
  if (existing?.id) {
    await db.entries.update(existing.id, { dataUrl, updatedAt: now })
  } else {
    await db.entries.add({ date, dataUrl, createdAt: now, updatedAt: now })
  }
}

export async function getEntriesForMonth(year: number, month: number): Promise<DailyEntry[]> {
  const prefix = `${year}-${String(month).padStart(2, '0')}`
  return db.entries.filter(e => e.date.startsWith(prefix)).toArray()
}

export async function getEntriesForYear(year: number): Promise<DailyEntry[]> {
  return db.entries.filter(e => e.date.startsWith(String(year))).toArray()
}
