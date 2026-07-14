import type { Metadata, Viewport } from 'next'
import './globals.css'
import BottomNav from '@/components/BottomNav'

export const metadata: Metadata = {
  title: 'Everyday Counts',
  description: '每天一张照片，记录生活流动',
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'black-translucent',
    title: 'Everyday',
  },
}

export const viewport: Viewport = {
  themeColor: '#0a0a0a',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN">
      <head>
        <link rel="apple-touch-icon" sizes="180x180" href="/icons/icon-192.png" />
      </head>
      <body className="bg-black min-h-screen text-white" style={{ fontFamily: 'system-ui, -apple-system, sans-serif' }}>
        <div className="max-w-lg mx-auto pb-20">
          {children}
        </div>
        <BottomNav />
      </body>
    </html>
  )
}
