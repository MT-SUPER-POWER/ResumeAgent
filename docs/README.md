# Docs 导航

## 设计

| 文档                                                                     | 说明                                           |
| ---------------------------------------------------------------------------- | ---------------------------------------------- |
| [specs/2026-05-28-resume-agent-design.md](superpowers/specs/2026-05-28-resume-agent-design.md) | 主设计文档（架构、数据模型、CLI、Prompt 策略） |
| [specs/2026-06-02-v1.0-api-design.md](superpowers/specs/2026-06-02-v1.0-api-design.md) | V1.0 REST API 服务化设计（Auth、Jobs、SSE、管理接口） |
| [specs/2026-06-03-v1.1-web-console-design.md](superpowers/specs/2026-06-03-v1.1-web-console-design.md) | V1.1 Web 管理面板设计（阶段拆分、页面范围、权限边界） |
| [ui-design/page-structure.md](ui-design/page-structure.md)                                     | Web UI 页面结构说明（侧边栏、页面职责、数据映射） |
| [ui-design/design.md](ui-design/design.md)                                                     | Web UI 设计系统（模板继承、单次分析结果与人才库信息架构） |
| [roadmap.md](roadmap.md)                                                                       | 版本路线图（V0.1 ~ V1.1 + 后续规划）           |

## 实施计划

| 文档 | 说明 |
| ---- | ---- |
| [plans/2026-06-03-v1.1a-frontend-foundation.md](superpowers/plans/2026-06-03-v1.1a-frontend-foundation.md) | V1.1A 前端底座、登录鉴权、API Client 与角色导航实施计划 |

## 架构

| 文档                                                   | 说明                                       |
| ------------------------------------------------------ | ------------------------------------------ |
| [architecture/overview.md](architecture/overview.md)   | 架构总览、模块关系、数据存储策略、技术选型 |
| [architecture/data-flow.md](architecture/data-flow.md) | 数据流设计（时序图、状态机、断点续跑流程） |
| [architecture/modules.md](architecture/modules.md)     | 10 个模块接口规格                          |

## 部署

| 文档                                       | 说明                                              |
| ------------------------------------------ | ------------------------------------------------- |
| [../deploy/README.md](../deploy/README.md) | Kubernetes 部署指南（PostgreSQL、脚本、连接方式） |

## 参考资料

| 文档                                                                       | 说明                                     |
| -------------------------------------------------------------------------- | ---------------------------------------- |
| [references/人才评级打分手册-V1.md](references/人才评级打分手册-V1.md)     | 人才评级打分手册 V1（8 维度 / 100 分）   |
| [references/岗位匹配度评分手册-V1.md](references/岗位匹配度评分手册-V1.md) | 岗位匹配度评分手册 V1（7 维度 / 100 分） |
| [references/职业描述和招聘职位.md](references/职业描述和招聘职位.md)       | 岗位 JD 描述                             |
| [前端页面参考项目](https://github.com/arhamkhnz/next-shadcn-admin-dashboard)| 前端项目参考模版 |
