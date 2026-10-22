import client from './client'

export type SandboxState = 'pending_review' | 'approved' | 'rejected' | 'success' | 'failed' | 'unknown'
export type SandboxOutcome = 'success' | 'failed' | 'unknown'
export type SandboxAction = 'approve' | 'reject' | 'submit' | 'retry' | 'resolve'
export interface SandboxPayout extends Record<string, unknown> {
  id: string; simulated: true; recipient: string; amountCents: number
  status: SandboxState; version: number; attempt: number; createdBy: string; createdAt: string; updatedAt: string
}
export interface SandboxEvent extends Record<string, unknown> {
  id: number; requestId: string; stage: string; action: string; fromStatus: string; toStatus: string
  outcome: string; version: number; attempt: number; actorId: string; createdAt: string
}
export interface SandboxPage { simulated: true; list: SandboxPayout[]; total: number; page: number; size: number }
export interface SandboxDetail { simulated: true; record: SandboxPayout; events: SandboxEvent[] }
export interface SandboxCommand { requestId: string; version: number; action: SandboxAction; outcome?: SandboxOutcome }
const prefix = '/admin/finance/payout-sandbox'
export function getSandboxPayouts(params: { page: number; size: number; status?: SandboxState }) { return client.get<SandboxPage>(prefix, { params }) }
export function getSandboxPayout(id: string) { return client.get<SandboxDetail>(`${prefix}/${encodeURIComponent(id)}`) }
export function createSandboxPayout(data: { requestId: string; amountCents: number }) { return client.post<SandboxPayout>(prefix, data) }
export function actSandboxPayout(id: string, data: SandboxCommand) { return client.post<SandboxPayout>(`${prefix}/${encodeURIComponent(id)}/actions`, data) }
