# @askxuan/domain-status

五端共享的业务状态显示字典。状态值保持后端原值，组件通过 `getStatusMeta(domain, status)` 取得统一文案和语义色调；未知状态原样显示并使用信息色，避免前端自行推断新状态。
