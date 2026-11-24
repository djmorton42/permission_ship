import type { RouteObject } from 'react-router'
import { LoginPage } from './features/authentication/LoginPage'
import { AcceptInvitationPage } from './features/invitations/AcceptInvitationPage'
import { AppLayout } from './layouts/AppLayout'
import { HomePage } from './pages/HomePage'
import { NotFoundPage } from './pages/NotFoundPage'

export const routes: RouteObject[] = [
  {
    element: <AppLayout />,
    children: [
      { index: true, element: <HomePage /> },
      { path: 'login', element: <LoginPage /> },
      { path: 'invitations/accept', element: <AcceptInvitationPage /> },
      { path: '*', element: <NotFoundPage /> },
    ],
  },
]
