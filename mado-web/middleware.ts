import { withAuth } from 'next-auth/middleware'

export default withAuth({
  pages: { signIn: '/login' },
})

export const config = {
  matcher: ['/calendar/:path*', '/tasks/:path*', '/notes/:path*', '/settings/:path*'],
}
