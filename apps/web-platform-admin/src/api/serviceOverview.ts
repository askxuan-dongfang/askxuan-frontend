import client from './client'
import { ElMessage } from '@/i18n'

export type ServiceOrderKind = 'bookings' | 'consultations'
export interface ServiceOrderQuery {
  q?: string
  status?: string
  paymentStatus?: string
  templeId?: string
  masterId?: string
  from?: string
  to?: string
  page: number
  size: number
}
export interface ServiceOrder extends Record<string, unknown> {
  id: string
  userId: string
  templeId: string
  templeName: string
  masterId: string
  masterName: string
  serviceId?: string
  serviceName?: string
  bookingDate?: string
  timeSlot?: string
  serviceFee?: number
  meritMoney?: number
  totalFee?: number
  consultFee?: number
  validHours?: number
  responseMinutes?: number
  validFrom?: string
  expiresAt?: string
  question?: string
  note?: string
  paymentNo: string
  paymentStatus: string
  paymentChannel?: string
  simulated?: boolean
  status: string
  createdAt: string
}
export interface ServiceOrderPage {
  total: number
  page: number
  size: number
  list: ServiceOrder[]
}
export interface ServiceReceiptFile {
  id: string
  name: string
  contentType: string
  size: number
  sha256: string
}
export interface ServiceFulfillment {
  status: string
  logs: Array<{ id: number; fromStatus: string; toStatus: string; operatorId: string; operatorType: string; remark: string; createTime: string }>
  receipts: Array<{ id: string; summary: string; operatorId: string; operatorType: string; createdAt: string; files: ServiceReceiptFile[] }>
  records: Array<{ id: string; kind: string; content: string; operatorId: string; operatorType: string; createdAt: string; files: ServiceReceiptFile[] }>
}

const prefix = '/admin/platform/service-orders'
export function getServiceOrders(kind: ServiceOrderKind, params: ServiceOrderQuery) {
  return client.get<ServiceOrderPage>(`${prefix}/${kind}`, { params })
}
export function getServiceOrder(kind: ServiceOrderKind, id: string) {
  return client.get<ServiceOrder>(`${prefix}/${kind}/${encodeURIComponent(id)}`)
}
export function getServiceFulfillment(id: string) {
  return client.get<ServiceFulfillment>(`${prefix}/bookings/${encodeURIComponent(id)}/fulfillment`)
}
export async function downloadServiceReceipt(bookingId: string, fileId: string) {
  // The existing authenticated file endpoint validates the booking and file
  // association server-side. No bearer token is placed in a URL.
  const blob = await client.get<Blob>(`/bookings/${encodeURIComponent(bookingId)}/receipt-files/${encodeURIComponent(fileId)}`, { responseType: 'blob' })
  // This legacy endpoint returns business errors as HTTP 200 JSON. The shared
  // client cannot inspect a Blob, so never save that error as a receipt file.
  if (blob.type.toLowerCase().includes('json')) {
    let message = '回执文件读取失败'
    try { message = JSON.parse(await blob.text()).message || message } catch { /* malformed error response */ }
    ElMessage.error(message)
    throw new Error(message)
  }
  return blob
}
