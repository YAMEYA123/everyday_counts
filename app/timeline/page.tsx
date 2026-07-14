'use client'
import { useState, useEffect } from 'react'
import { ChevronLeft, ChevronRight, X } from 'lucide-react'
import { db, type DailyEntry } from '@/lib/db'

function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate()
}

function firstDayOfMonth(year: number, month: number): number {
  // 0=Sun, returns 0-6; we want Mon=0
  const d = new Date(year, month - 1, 1).getDay()
  return (d + 6) % 7
}

export default function TimelinePage() {
  const now = new Date()
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth() + 1)
  const [entries, setEntries] = useState<Map<string, DailyEntry>>(new Map())
  const [preview, setPreview] = useState<DailyEntry | null>(null)

  useEffect(() => {
    const prefix = `${year}-${String(month).padStart(2, '0')}`
    db.entries.filter(e => e.date.startsWith(prefix)).toArray().then(list => {
      const map = new Map<string, DailyEntry>()
      list.forEach(e => map.set(e.date, e))
      setEntries(map)
    })
  }, [year, month])

  function prevMonth() {
    if (month === 1) { setYear(y => y - 1); setMonth(12) }
    else setMonth(m => m - 1)
  }

  function nextMonth() {
    if (month === 12) { setYear(y => y + 1); setMonth(1) }
    else setMonth(m => m + 1)
  }

  const days = daysInMonth(year, month)
  const offset = firstDayOfMonth(year, month)
  const cells: (number | null)[] = [
    ...Array(offset).fill(null),
    ...Array.from({ length: days }, (_, i) => i + 1),
  ]
  // pad to complete last row
  while (cells.length % 7 !== 0) cells.push(null)

  const todayKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`

  return (
    <div className="min-h-screen px-4 pt-14 pb-4">
      {/* header */}
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-semibold">时间线</h1>
        <div className="flex items-center gap-2">
          <button onClick={prevMonth} className="p-1.5 rounded-lg text-white/60 active:bg-white/10">
            <ChevronLeft size={20} />
          </button>
          <span className="text-sm font-medium w-16 text-center">
            {year}年{month}月
          </span>
          <button onClick={nextMonth} className="p-1.5 rounded-lg text-white/60 active:bg-white/10">
            <ChevronRight size={20} />
          </button>
        </div>
      </div>

      {/* weekday labels */}
      <div className="grid grid-cols-7 mb-1">
        {['一', '二', '三', '四', '五', '六', '日'].map(d => (
          <div key={d} className="text-center text-xs text-white/30 py-1">{d}</div>
        ))}
      </div>

      {/* calendar grid */}
      <div className="grid grid-cols-7 gap-1">
        {cells.map((day, i) => {
          if (!day) return <div key={`empty-${i}`} />
          const key = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
          const entry = entries.get(key)
          const isToday = key === todayKey

          return (
            <button
              key={key}
              onClick={() => entry && setPreview(entry)}
              className={`aspect-square rounded-lg overflow-hidden relative ${
                isToday ? 'ring-1 ring-white/60' : ''
              } ${entry ? 'active:opacity-80' : ''}`}
            >
              {entry ? (
                <img src={entry.dataUrl} alt={key} className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full bg-white/5 flex items-end justify-start p-1">
                  <span className="text-xs text-white/20">{day}</span>
                </div>
              )}
              {entry && (
                <div className="absolute bottom-0.5 left-0.5 text-[9px] text-white/60 leading-none">
                  {day}
                </div>
              )}
            </button>
          )
        })}
      </div>

      {/* stats */}
      <div className="mt-4 text-center text-white/30 text-sm">
        {entries.size} / {days} 天已记录
      </div>

      {/* fullscreen preview */}
      {preview && (
        <div
          className="fixed inset-0 bg-black z-50 flex items-center justify-center"
          onClick={() => setPreview(null)}
        >
          <button className="absolute top-12 right-4 text-white/60 p-2">
            <X size={24} />
          </button>
          <img
            src={preview.dataUrl}
            alt={preview.date}
            className="max-w-full max-h-full object-contain"
            onClick={e => e.stopPropagation()}
          />
          <div className="absolute bottom-24 left-0 right-0 text-center text-white/50 text-sm">
            {preview.date}
          </div>
        </div>
      )}
    </div>
  )
}
