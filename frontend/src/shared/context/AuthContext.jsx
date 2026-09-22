import React, { createContext, useContext, useState, useEffect } from 'react'
import { apiClient } from '../services/apiClient.js'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem('loopworth_user')
    return saved ? JSON.parse(saved) : null
  })
  const [token, setToken] = useState(() => localStorage.getItem('loopworth_token'))
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadUser() {
      const savedToken = localStorage.getItem('loopworth_token')
      if (savedToken) {
        try {
          const res = await apiClient.get('/api/auth/me')
          setUser(res.data)
          localStorage.setItem('loopworth_user', JSON.stringify(res.data))
        } catch {
          logout()
        }
      }
      setLoading(false)
    }
    loadUser()
  }, [])

  const login = async (email, password) => {
    const res = await apiClient.post('/api/auth/login', { email, password })
    const { token: jwt, userId, name, email: userEmail, role, phone, address, district, town } = res.data
    const userData = { userId, name, email: userEmail, role, phone, address, district, town }
    localStorage.setItem('loopworth_token', jwt)
    localStorage.setItem('loopworth_user', JSON.stringify(userData))
    setToken(jwt)
    setUser(userData)
    return userData
  }

  const register = async (nameOrData, email, password, phone, address, district, town) => {
    let payload = {}
    if (typeof nameOrData === 'object' && nameOrData !== null) {
      payload = nameOrData
    } else {
      payload = { name: nameOrData, email, password, phone, address, district, town }
    }

    const res = await apiClient.post('/api/auth/register', payload)
    const { token: jwt, userId, name: userName, email: userEmail, role, phone: userPhone, address: userAddress, district: userDistrict, town: userTown } = res.data
    const userData = { 
      userId, 
      name: userName, 
      email: userEmail, 
      role,
      phone: userPhone,
      address: userAddress,
      district: userDistrict,
      town: userTown
    }
    localStorage.setItem('loopworth_token', jwt)
    localStorage.setItem('loopworth_user', JSON.stringify(userData))
    setToken(jwt)
    setUser(userData)
    return userData
  }

  const updateProfile = async (profileData) => {
    const res = await apiClient.put('/api/auth/profile', profileData)
    const updatedUser = { ...user, ...res.data }
    localStorage.setItem('loopworth_user', JSON.stringify(updatedUser))
    setUser(updatedUser)
    return updatedUser
  }

  const logout = () => {
    localStorage.removeItem('loopworth_token')
    localStorage.removeItem('loopworth_user')
    setToken(null)
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, token, role: user?.role, loading, login, register, updateProfile, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
