'use client'

export async function requestNotificationPermission(): Promise<boolean> {
  if (!('Notification' in window)) return false
  if (Notification.permission === 'granted') return true
  const result = await Notification.requestPermission()
  return result === 'granted'
}

export function scheduleLocalReminder(hasTodayEntry: boolean): void {
  if (!('Notification' in window) || Notification.permission !== 'granted') return
  if (hasTodayEntry) return

  const now = new Date()
  const target = new Date()
  target.setHours(20, 0, 0, 0)

  // if 8pm already passed, skip
  if (now >= target) return

  const delay = target.getTime() - now.getTime()
  setTimeout(() => {
    new Notification('记录今天 📷', {
      body: '今天还没拍照，留住这一天',
      icon: '/icons/icon-192.png',
    })
  }, delay)
}
