// One navigation contract for the sidebar, routes and links inside the workspace.
export const agentCenterSections = [
  { path: '/ai/agent', title: '智能体编排', section: 'config', description: '定义问事助手的职责、知识范围和 Harness 执行策略' },
  { path: '/ai/connections', title: '模型与连接', description: '管理大模型、联网搜索与知识模型的服务连接' },
  { path: '/ai/knowledge', title: '知识中心', description: '管理文档、检索、Wiki 和实体知识图谱' },
  { path: '/ai/tools', title: '技能与工具', section: 'skills', description: '为问事助手添加、移除或启停现有技能与 MCP 工具' },
  { path: '/ai/debug', title: '调试工作台', section: 'debug', description: '验证回答与 Harness 工具执行过程' },
  { path: '/ai/evaluations', title: '质量评测', section: 'evaluation', description: '通过测试用例检查当前草稿的回答质量' },
  { path: '/ai/releases', title: '版本与发布', section: 'versions', description: '管理已发布版本、灰度范围与回滚' },
  { path: '/ai/runs', title: '运行监控', section: 'runs', description: '查看用户请求、执行状态和工具调用记录' },
] as const
export const agentSectionPath = (section: string) => agentCenterSections.find(item => 'section' in item && item.section === section)?.path || '/ai/agent'
