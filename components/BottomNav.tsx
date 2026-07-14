'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Camera, Grid3x3, Film } from 'lucide-react'

const TABS = [
  { href: '/', label: '今天', Icon: Camera },
  { href: '/timeline', label: '时间线', Icon: Grid3x3 },
  { href: '/review', label: '回顾', Icon: Film },
]

export default function BottomNav() {
  const path = usePathname()
  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-black/95 backdrop-blur-sm border-t border-white/10 pb-safe z-50">
      <div className="max-w-lg mx-auto flex">
        {TABS.map(({ href, label, Icon }) => {
          const active = href === '/' ? path === '/' : path.startsWith(href)
          return (
            <Link
              key={href}
              href={href}
              className={`flex-1 flex flex-col items-center justify-center min-h-[52px] py-1.5 gap-0.5 text-xs transition-colors ${
                active ? 'text-white' : 'text-white/40'
              }`}
            >
              <Icon size={20} strokeWidth={active ? 2.2 : 1.6} />
              <span className={active ? 'font-medium' : ''}>{label}</span>
            </Link>
          )
        })}
      </div>
    </nav>
  )
}
