import axios from 'axios'
import {
  clearStoredAuthSession,
  getAccessToken,
  getStoredAuthSession,
  setStoredAuthSession,
} from '@/services/http/tokenStorage'

const API_BASE_URL =
  (import.meta.env.VITE_API_BASE_URL as string | undefined)?.trim() ||
  'http://127.0.0.1:3000/api/v1'

export const adminTokenStorage = {
  get() {
    return getAccessToken()
  },
  set(token: string) {
    const currentAdmin = getStoredAuthSession()?.admin || {
      username: 'admin',
      role: 'admin',
    }
    setStoredAuthSession({ token, admin: currentAdmin })
  },
  clear() {
    clearStoredAuthSession()
  },
}

function redirectToAdminLogin() {
  if (typeof window === 'undefined') {
    return
  }

  if (window.location.pathname !== '/auth/admin-login') {
    window.location.assign('/auth/admin-login')
  }
}

export const adminApi = axios.create({
  baseURL: API_BASE_URL,
})

adminApi.interceptors.request.use((config) => {
  const token = adminTokenStorage.get()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

adminApi.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error?.response?.status
    if (status === 401) {
      adminTokenStorage.clear()
      redirectToAdminLogin()
    }

    const message =
      error?.response?.data?.message ||
      error?.response?.data?.error ||
      error?.message ||
      'Erreur de service'

    return Promise.reject(new Error(message))
  },
)

export async function adminLogin(username: string, password: string) {
  const response = await adminApi.post('/admin/auth/login', {
    username,
    password,
  })

  const data = response.data?.data || {}
  if (data.token && data.admin) {
    setStoredAuthSession({
      token: data.token,
      admin: data.admin,
    })
  }

  return data
}

export async function fetchCommissionOverview() {
  const response = await adminApi.get('/admin/commissions/overview')
  return response.data?.data || {}
}

export async function fetchAgentCommissionDetail(agentId: string) {
  const response = await adminApi.get(`/admin/commissions/agents/${agentId}`)
  return response.data?.data || {}
}
