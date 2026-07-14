'use client'
import { useState, useEffect, useRef } from 'react'
import { Camera, RefreshCw } from 'lucide-react'
import { getTodayEntry, upsertEntry, todayKey, type DailyEntry } from '@/lib/db'
import { compressImage } from '@/lib/imageUtils'
import { requestNotificationPermission, scheduleLocalReminder } from '@/lib/notifications'

export default function TodayPage() {
  const [entry, setEntry] = useState<DailyEntry | null>(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)

  const today = new Date()
  const dateLabel = `${today.getFullYear()}年${today.getMonth() + 1}月${today.getDate()}日`

  useEffect(() => {
    getTodayEntry().then(e => {
      setEntry(e ?? null)
      setLoading(false)
      requestNotificationPermission().then(() => {
        scheduleLocalReminder(!!e)
      })
    })
  }, [])

  async function handleFile(file: File) {
    if (!file.type.startsWith('image/')) return
    setSaving(true)
    try {
      const dataUrl = await compressImage(file)
      await upsertEntry(todayKey(), dataUrl)
      const updated = await getTodayEntry()
      setEntry(updated ?? null)
    } finally {
      setSaving(false)
    }
  }

  function openPicker() {
    inputRef.current?.click()
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="w-6 h-6 border-2 border-white/30 border-t-white rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col">
      <div className="px-5 pt-14 pb-4">
        <p className="text-white/40 text-sm">{dateLabel}</p>
        <h1 className="text-2xl font-semibold mt-0.5">今天</h1>
      </div>

      <div className="flex-1 px-4">
        {entry ? (
          <div className="relative">
            <img
              src={entry.dataUrl}
              alt="今日照片"
              className="w-full rounded-2xl object-cover"
              style={{ maxHeight: '65vh' }}
            />
            <button
              onClick={openPicker}
              className="absolute top-3 right-3 bg-black/60 backdrop-blur-sm rounded-full px-3 py-1.5 flex items-center gap-1.5 text-sm text-white/80"
            >
              <RefreshCw size={14} />
              重拍
            </button>
          </div>
        ) : (
          <button
            onClick={openPicker}
            className="w-full border-2 border-dashed border-white/15 rounded-2xl flex flex-col items-center justify-center gap-4 text-white/40 active:bg-white/5 transition-colors"
            style={{ minHeight: '55vh' }}
          >
            {saving ? (
              <div className="w-8 h-8 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <>
                <div className="w-16 h-16 rounded-full bg-white/8 flex items-center justify-center">
                  <Camera size={28} strokeWidth={1.4} />
                </div>
                <div className="text-center">
                  <p className="text-base font-medium text-white/60">记录今天</p>
                  <p className="text-sm mt-1">拍照或从相册选取</p>
                </div>
              </>
            )}
          </button>
        )}
      </div>

      {saving && entry && (
        <div className="px-5 py-3 text-center text-white/40 text-sm">保存中…</div>
      )}

      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="hidden"
        onChange={e => {
          const file = e.target.files?.[0]
          if (file) handleFile(file)
          e.target.value = ''
        }}
      />
    </div>
  )
}
