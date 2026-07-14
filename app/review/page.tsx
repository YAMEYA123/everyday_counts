'use client'
import { useState, useEffect, useRef } from 'react'
import { Play, Download, Loader2 } from 'lucide-react'
import { db, type DailyEntry } from '@/lib/db'

type Range = 'month' | 'year'

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((res, rej) => {
    const img = new Image()
    img.onload = () => res(img)
    img.onerror = rej
    img.src = src
  })
}

async function generateSlideshow(
  entries: DailyEntry[],
  onProgress: (cur: number, total: number) => void,
): Promise<Blob> {
  const W = 1080
  const H = 1920
  const SECS_PER_PHOTO = 2
  const FPS = 30

  const canvas = document.createElement('canvas')
  canvas.width = W
  canvas.height = H
  const ctx = canvas.getContext('2d')!

  const mimeType = MediaRecorder.isTypeSupported('video/mp4') ? 'video/mp4' : 'video/webm'
  const stream = canvas.captureStream(FPS)
  const recorder = new MediaRecorder(stream, { mimeType })
  const chunks: Blob[] = []
  recorder.ondataavailable = e => { if (e.data.size > 0) chunks.push(e.data) }

  recorder.start()

  const sorted = [...entries].sort((a, b) => a.date.localeCompare(b.date))

  for (let i = 0; i < sorted.length; i++) {
    onProgress(i + 1, sorted.length)
    const img = await loadImage(sorted[i].dataUrl)

    // draw cover-fit
    const scale = Math.max(W / img.width, H / img.height)
    const sw = img.width * scale
    const sh = img.height * scale
    ctx.fillStyle = '#000'
    ctx.fillRect(0, 0, W, H)
    ctx.drawImage(img, (W - sw) / 2, (H - sh) / 2, sw, sh)

    // hold frame for SECS_PER_PHOTO seconds
    const frames = SECS_PER_PHOTO * FPS
    for (let f = 0; f < frames; f++) {
      await new Promise(r => requestAnimationFrame(r))
    }
  }

  recorder.stop()
  await new Promise<void>(r => { recorder.onstop = () => r() })

  return new Blob(chunks, { type: mimeType })
}

export default function ReviewPage() {
  const now = new Date()
  const [range, setRange] = useState<Range>('month')
  const [entries, setEntries] = useState<DailyEntry[]>([])
  const [status, setStatus] = useState<'idle' | 'generating' | 'done'>('idle')
  const [progress, setProgress] = useState({ cur: 0, total: 0 })
  const [videoUrl, setVideoUrl] = useState<string | null>(null)
  const blobRef = useRef<Blob | null>(null)

  useEffect(() => {
    const y = now.getFullYear()
    const m = now.getMonth() + 1
    if (range === 'month') {
      const prefix = `${y}-${String(m).padStart(2, '0')}`
      db.entries.filter(e => e.date.startsWith(prefix)).toArray().then(setEntries)
    } else {
      db.entries.filter(e => e.date.startsWith(String(y))).toArray().then(setEntries)
    }
  }, [range])

  async function generate() {
    if (entries.length === 0) return
    setStatus('generating')
    setVideoUrl(null)
    try {
      const blob = await generateSlideshow(entries, (cur, total) => setProgress({ cur, total }))
      blobRef.current = blob
      setVideoUrl(URL.createObjectURL(blob))
      setStatus('done')
    } catch (e) {
      console.error(e)
      setStatus('idle')
    }
  }

  function download() {
    if (!blobRef.current) return
    const ext = blobRef.current.type.includes('mp4') ? 'mp4' : 'webm'
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blobRef.current)
    a.download = `everyday-counts-${range === 'month'
      ? `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
      : now.getFullYear()}.${ext}`
    a.click()
  }

  const estimatedSecs = entries.length * 2

  return (
    <div className="min-h-screen px-4 pt-14 pb-4">
      <h1 className="text-2xl font-semibold mb-6">回顾</h1>

      {/* range selector */}
      <div className="flex gap-2 mb-6">
        {(['month', 'year'] as Range[]).map(r => (
          <button
            key={r}
            onClick={() => { setRange(r); setStatus('idle'); setVideoUrl(null) }}
            className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition-colors ${
              range === r ? 'bg-white text-black' : 'bg-white/10 text-white/60'
            }`}
          >
            {r === 'month' ? `${now.getMonth() + 1}月` : `${now.getFullYear()}年`}
          </button>
        ))}
      </div>

      {/* info */}
      <div className="bg-white/5 rounded-2xl p-4 mb-6">
        <div className="flex justify-between text-sm text-white/60 mb-1">
          <span>已记录</span>
          <span>{entries.length} 张照片</span>
        </div>
        <div className="flex justify-between text-sm text-white/60">
          <span>预计时长</span>
          <span>约 {estimatedSecs} 秒</span>
        </div>
      </div>

      {/* action */}
      {status === 'idle' && (
        <button
          onClick={generate}
          disabled={entries.length === 0}
          className="w-full py-3.5 rounded-2xl bg-white text-black font-semibold flex items-center justify-center gap-2 disabled:opacity-30"
        >
          <Play size={18} />
          生成回顾视频
        </button>
      )}

      {status === 'generating' && (
        <div className="text-center py-8">
          <Loader2 size={32} className="animate-spin mx-auto mb-3 text-white/60" />
          <p className="text-white/60 text-sm">
            处理第 {progress.cur} / {progress.total} 张…
          </p>
          <div className="mt-3 h-1 bg-white/10 rounded-full overflow-hidden">
            <div
              className="h-full bg-white rounded-full transition-all duration-300"
              style={{ width: `${progress.total ? (progress.cur / progress.total) * 100 : 0}%` }}
            />
          </div>
        </div>
      )}

      {status === 'done' && videoUrl && (
        <div>
          <video
            src={videoUrl}
            controls
            playsInline
            className="w-full rounded-2xl mb-4"
            style={{ maxHeight: '50vh' }}
          />
          <button
            onClick={download}
            className="w-full py-3.5 rounded-2xl bg-white text-black font-semibold flex items-center justify-center gap-2"
          >
            <Download size={18} />
            保存到相册 / 下载
          </button>
          <button
            onClick={() => { setStatus('idle'); setVideoUrl(null) }}
            className="w-full py-2 mt-2 text-sm text-white/40"
          >
            重新生成
          </button>
        </div>
      )}

      {entries.length === 0 && (
        <p className="text-center text-white/30 text-sm mt-8">
          本{range === 'month' ? '月' : '年'}还没有任何记录
        </p>
      )}
    </div>
  )
}
