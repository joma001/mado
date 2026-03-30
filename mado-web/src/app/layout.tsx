import type { Metadata } from 'next'
import { SessionProvider } from '@/components/layout/SessionProvider'
import './globals.css'

export const metadata: Metadata = {
  title: 'Mado',
  description: 'Calendar, Tasks & Notes — unified productivity',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased">
        <SessionProvider>{children}</SessionProvider>
      </body>
    </html>
  )
}
