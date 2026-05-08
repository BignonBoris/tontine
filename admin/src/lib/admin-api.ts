import axios from 'axios'

const API_BASE_URL =
  (import.meta.env.VITE_API_BASE_URL as string | undefined)?.trim() ||
  'http://127.0.0.1:3000/api/v1'

const TOKEN_KEY = 'viziobox_admin_token'

export const adminTokenStorage = {
  get() {
    return window.localStorage.getItem(TOKEN_KEY)
  },
  set(token: string) {
    window.localStorage.setItem(TOKEN_KEY, token)
  },
  clear() {
    window.localStorage.removeItem(TOKEN_KEY)
  },
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
  if (data.token) {
    adminTokenStorage.set(data.token)
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
