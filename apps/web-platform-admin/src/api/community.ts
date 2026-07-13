import client from './client'

export interface CommunityPost {
  id: string
  masterId: string
  type: 'article' | 'video'
  title: string
  content: string
  beliefCode: string
  status: string
  auditRemark?: string
  likeCount: number
  commentCount: number
  createTime: string
}

export interface CommunityComment {
  id: string
  postId: string
  userId: string
  content: string
  status: string
  auditRemark?: string
  createTime: string
}

export interface CommunityPage<T> {
  total: number
  list: T[]
  page: number
  size: number
}

export function getCommunityPosts(params: { status?: string; page: number; size: number }) {
  return client.get<CommunityPage<CommunityPost>>('/admin/platform/community/posts', { params })
}

export function reviewCommunityPost(id: string, action: 'approve' | 'reject', data: { auditorId: string; remark?: string }) {
  return client.put<CommunityPost>(`/admin/platform/community/posts/${id}/${action}`, data)
}

export function getCommunityComments(params: { status?: string; page: number; size: number }) {
  return client.get<CommunityPage<CommunityComment>>('/admin/platform/community/comments', { params })
}

export function reviewCommunityComment(id: string, action: 'approve' | 'reject', data: { auditorId: string; remark?: string }) {
  return client.put<CommunityComment>(`/admin/platform/community/comments/${id}/${action}`, data)
}
