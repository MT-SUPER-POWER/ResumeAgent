# Resume Agent Roadmap

> 最后更新: 2026-06-05
>
> - 设计: `docs/superpowers/specs/2026-05-28-resume-agent-design.md`
> - 模块: `docs/architecture/modules.md`
> - V0.3 设计: `docs/superpowers/specs/2026-05-31-v0.3-concurrency-design.md`
> - V0.4 设计: `docs/superpowers/specs/2026-06-01-v0.4-token-cost-design.md`
> - V1.0 API 设计: `docs/superpowers/specs/2026-06-02-v1.0-api-design.md`
> - V1.1 Web 设计: `docs/superpowers/specs/2026-06-03-v1.1-web-console-design.md`
> - V1.2 闭环设计: `docs/superpowers/specs/2026-06-05-v1.2-talent-pool-closed-loop.md`

---

## 版本总览

```mermaid
gantt
  title Resume Agent 版本路线
  dateFormat  YYYY-MM-DD
  axisFormat  %m-%d

  section MVP
  V0.1 MVP       :v01, 2026-05-28, 3d

  section 可靠性
  V0.2 可靠性     :v02, 2026-05-31, 2d

  section 性能
  V0.3 并发      :v03, 2026-06-02, 2d

  section 模型治理
  V0.4 成本      :v04, 2026-06-04, 2d

  section API服务化
  V1.0 API       :v10, 2026-06-06, 3d

  section Web管理面板
  V1.1A 底座     :v11a, 2026-06-09, 2d
  V1.2 人才库闭环 :v12, 2026-06-11, 4d
  V1.1B 分析     :v11b, after v12, 3d
  V1.1C 筛选     :v11c, after v11b, 3d
  V1.1D 管理     :v11d, after v11c, 2d
```

---

## V0.1 — MVP 验证

**目标**: 跑通全流程，验证 prompt 质量和评分合理性

```mermaid
flowchart LR
  subgraph V01["V0.1 范围"]
    direction LR
    A["文件解析"] --> B["LLM 评估<br/>(提取+评分合并)"]
    B --> C["报告生成"]
    C --> D["汇总排名"]
  end
```

### 交付清单

| #   | 功能                    | 说明                                                                             |
| --- | ----------------------- | -------------------------------------------------------------------------------- |
| 1   | PostgreSQL + migrations | 4 张业务表 (job_descriptions/resumes/evaluations/schema_migrations)              |
| 2   | PDF/Word 解析           | SHA256 去重，不可解析标记 skipped，不阻塞流程                                    |
| 3   | LLM 评估（提取+评分）   | Claude / OpenAI 可切换，一次调用完成提取+双维度评分，结果存 evaluations 表 JSONB |
| 4   | 个人 Markdown 报告      | 含基本信息 + 两维度明细 + 综合评估                                               |
| 5   | 汇总排名 Markdown       | 排名表，按人才评分降序                                                           |
| 6   | 汇总 JSON               | 全部数据聚合，方便程序消费                                                       |
| 7   | CLI 工具                | RunDir / RunFiles / JdList / JdShow / DbStatus                                   |
| 8   | 配置文件                | application.yaml，环境变量注入                                                   |
| 9   | Pipeline 幂等           | Phase 1 (file_hash) + Phase 2 (evaluation status) 跳过已完成                     |

### 不做

- 并发处理（串行逐份跑）
- 断点续跑（无显式 --resume 命令）
- LLM 失败重试
- Excel 导出
- Web 界面
- JD 关联（pipeline 不绑定 JD）

### 验收标准

- 10 份简历，30 分钟内完成
- PipelineResult JSON schema 校验通过率 > 90%
- 每份简历产出完整 Markdown 报告

---

## V0.2 — 可靠性

**目标**: 能处理几十份简历，不怕中断，状态可追踪

> **基础能力已在 V0.1 就绪**：Pipeline 已内置 SHA256 去重 + evaluation 状态检查，重新运行同一目录自动跳过已完成的文件。V0.2 补齐 LLM 韧性和统一操作记录管理。

```mermaid
flowchart LR
  subgraph V02["V0.2 新增"]
    direction LR
    A["job_runs + pipeline_states"] --> B["统一追踪每份简历阶段"]
    B --> C["LLM 指数退避重试"]
    C --> D["失败隔离 + --rerun"]
  end
```

### 交付清单

| #   | 功能              | 说明                                                                       |
| --- | ----------------- | -------------------------------------------------------------------------- |
| 1   | job_runs 操作记录 | UUID PK，每次 run 一条记录，追踪 total/parsed/evaluated/failed/errors      |
| 2   | pipeline_states   | 统一管理每份简历在每个阶段的运行状态 (parse/evaluate)                      |
| 3   | LLM 重试          | 可重试错误(429/5xx/连接超时)自动重试 3 次，指数退避 1s/2s/4s               |
| 4   | 失败隔离          | 单份简历任一阶段报错不终止整批，pipeline_states 记录 error_msg 后 continue |
| 5   | --rerun 命令      | 读取历史 job_run，从上次失败阶段精确续跑，文件缺失则报错                   |

### 不做

- 并发处理
- 文件系统监听模式

### 验收标准

- 50 份简历中任意一份网络错误不影响其余
- job_runs 表准确记录每次操作的全貌
- pipeline_states 能定位每份简历在哪个阶段失败及原因
- `--rerun` 精确续跑，已完成阶段跳过，失败阶段重试
- 运行结束打印失败清单，含文件名和错误原因

---

## V0.3 — 性能

**目标**: 百份级别简历在可接受时间内完成

> **架构设计**: `docs/superpowers/specs/2026-05-31-v0.3-concurrency-design.md`

```mermaid
flowchart LR
  subgraph V03["V0.3 新增"]
    direction LR
    A["Producer-Consumer 管道"] --> B["N 个常驻 worker<br/>--concurrency N"]
    B --> C["Stage 3 DB 汇聚"]
    C --> D["failures 字段<br/>data.json + ranking.md"]
  end
```

### 交付清单

| #   | 功能              | 说明                                                                |
| --- | ----------------- | ------------------------------------------------------------------- |
| 1   | Producer-Consumer | 3-stage 管道：Stage1 解析 → bounded channel → Stage2 N worker 评估  |
| 2   | 并发控制          | `--concurrency N` (auto=3)，N 个常驻 worker，channel 容量 N×2       |
| 3   | DB 连接池检查     | 启动时 needed=concurrency×2+2 对比 max_connections，不足则 warn     |
| 4   | DB 汇聚           | Stage 3 从 DB JOIN pipeline_states 过滤本 run 结果，而非接收 Vec    |
| 5   | 失败清单          | data.json 新增 summary + failures 字段，ranking.md 新增处理失败章节 |

### 不做

- Rate Limiting（RPM/TPM）— V0.2 重试已覆盖，后续版本再考虑
- 阶段流水线化（parse 与 evaluate 重叠）— parse 远快于 evaluate，无收益

### 验收标准

- 100 份简历，concurrency=5 时 < 15 分钟
- 不触发 API rate limit 错误
- 单份简历任一阶段失败不影响其余
- data.json 和 ranking.md 包含失败清单

---

## V0.4 — 模型治理与成本追踪

**目标**: 数据库驱动的模型管理，完整 Token/费用追踪，支持多中转灵活切换

> **架构设计**: `docs/superpowers/specs/2026-06-01-v0.4-token-cost-design.md`

```mermaid
flowchart LR
  subgraph V04["V0.4 新增"]
    direction LR
    A["models 表 + 加密存储"] --> B["Router 层<br/>查表路由 + 统一计费"]
    C["AES-256-GCM 加密"] --> A
    B --> D["job_run 累计<br/>total_tokens / total_cost"]
    E["CLI model 子命令"] --> A
  end
```

### 交付清单

| #   | 功能             | 说明                                                                                                       |
| --- | ---------------- | ---------------------------------------------------------------------------------------------------------- |
| 1   | models 表        | DB 注册模型（name/protocol/input_price/output_price/encrypted_key/base_url/enabled），种子内置常见模型     |
| 2   | AES-256-GCM 加密 | `utils/crypto.rs`，api_key 加密落库，MASTER_KEY 来自 yaml 配置                                             |
| 3   | Router 层        | 查 models 表路由到 openai/claude handler，统一计费，协议扩展点预留                                         |
| 4   | job_run 成本字段 | `total_tokens` + `total_cost`，每次 LLM 调用原子累加                                                       |
| 5   | CLI model 命令   | add / list / set-price / enable / disable / remove                                                         |
| 6   | run --model      | 指定本次运行使用的模型，不传默认用第一个 enabled                                                           |
| 7   | 配置重构         | `application.default.yaml` 模板（提交）+ `application.yaml` 真实配置（gitignore），移除旧的 llm 硬编码字段 |

### 不做

- 预筛选、TopK、Excel 导出 — 推迟到 V1.1C 前端实现
- 自动从官网拉取定价 — 三方中转价格与官方无关

### 验收标准

- `resume-agent model add gpt-4o --protocol openai --api-key sk-xxx --input-price 2.5 --output-price 10.0` 成功加密落库
- `resume-agent run --dir ./resumes --model gpt-4o` 全程使用指定模型，费用实时计算
- job_runs 表 `total_tokens` / `total_cost` 准确反映当次运行总消耗
- 两个并发 worker 同时累加 token 数不丢失（原子 UPDATE）

---

## V1.0 — REST API 服务化

**目标**: 将 CLI 能力服务化，为 Web 管理面板提供稳定的认证、任务、结果、模型和系统管理接口。

> **设计文档**: `docs/superpowers/specs/2026-06-02-v1.0-api-design.md`

将所有 CLI 命令抽象为 `/api/v1/*` 端点，Actix-web 嵌入现有 Rust 项目。

```mermaid
flowchart LR
  subgraph V10["V1.0 REST API"]
    direction LR
    API["REST API<br/>(Actix-web)"]
    Core["核心引擎<br/>(复用 CLI 逻辑)"]
    DB[(PostgreSQL)]

    API --> Core
    Core --> DB
  end
```

| # | 功能 | 说明 |
|---|------|------|
| 1 | JWT 认证 | users 表 + bcrypt 密码 + JWT，role 分为 admin / user |
| 2 | Jobs API | 上传/提交/查询/重跑，SSE 实时进度推送 |
| 3 | JDs API | 岗位描述 CRUD |
| 4 | Models API | 模型管理（只读全员，写操作 admin） |
| 5 | Users API | 用户列表、创建、角色调整、禁用和恢复（admin only） |
| 6 | System API | DB 状态、重置、缓存清理（admin only） |
| 7 | 统一响应格式 | `{ code, msg, data, detail }` 信封 + 错误码体系 |
| 8 | SSE 事件规范 | 状态快照流：job_started / stage / progress / warning / error / heartbeat / complete |
| 9 | serve 子命令 | `resume-agent serve --port 8080` 启动 HTTP 服务 |

### 验收标准

- `resume-agent serve --port 8080` 可启动 HTTP 服务。
- Auth / Jobs / JDs / Models / Users / System API 按角色权限返回统一响应信封。
- `POST /api/v1/jobs` 可提交批量简历并通过 SSE 推送实时进度。
- `GET /api/v1/jobs/{id}/results` 可返回完整结构化结果，前端无需解析 Markdown。

---

## V1.1 — Web 管理面板

**目标**: HR 和 Admin 通过浏览器完成核心工作流，前端基于 Next.js + shadcn，参考 `docs/references/next-shadcn-admin-dashboard/` 的后台布局与角色切换模式。

> **设计文档**: `docs/superpowers/specs/2026-06-03-v1.1-web-console-design.md`
>
> **优先级调整**: V1.1A（前端底座）完成后，优先进入 V1.2（人才库面试闭环），而非 V1.1B。V1.1B/C/D 排在 V1.2 之后。原因：人才库闭环是连接 AI 初筛与人工决策的核心链路，必须优先于分析记录、候选人筛选导出和管理面板等辅助功能。

V1.1 不再作为 V1.0 的 Phase 2，而是独立的 Web 产品化阶段。

```mermaid
flowchart LR
  subgraph V11["V1.1 Web 管理面板"]
    direction LR
    A["V1.1A<br/>前端底座 + 登录鉴权"] --> B["V1.1B<br/>HR 简历分析闭环"]
    B --> C["V1.1C<br/>候选人评估 + 筛选导出"]
    C --> D["V1.1D<br/>Admin 管理面板"]
  end
```

### V1.1A — 前端底座 + 登录鉴权

| # | 功能 | 说明 |
|---|------|------|
| 1 | 前端应用骨架 | `repo/frontend/`，Next.js + TypeScript + shadcn + Tailwind |
| 2 | 模板裁剪 | 保留 AppShell、Sidebar、Navbar、主题和基础组件，移除无关 demo 页面 |
| 3 | API Client | 封装 `/api/v1/*` 调用、统一响应信封、错误提示和 token 注入 |
| 4 | 登录鉴权 | 登录页、JWT 持久化、`/auth/me` 会话恢复、退出登录 |
| 5 | 角色态 | Sidebar 按 HR / Admin 显示不同入口 |

---

## V1.2 — 人才库面试闭环（优先于 V1.1B/C/D）

**目标**: 打通"人才库筛选 → 安排面试 → 会议记录留痕 → 阶段同步回表"的完整招聘闭环，让招聘流程在系统内形成可追溯的电路。

> **设计文档**: `docs/superpowers/specs/2026-06-05-v1.2-talent-pool-closed-loop.md`
>
> **优先级说明**: V1.2 排在 V1.1A 之后、V1.1B/C/D 之前，因为人才库是连接"AI 初筛"与"人工决策"的关键节点——只有闭环跑通，HR 才能在系统内完成从筛选到面试的完整工作流，而不是停留在只读排行榜。

```mermaid
flowchart LR
  subgraph V12["V1.2 人才库面试闭环"]
    direction LR
    A["人才库筛选<br/>按 JD 归档候选人"] --> B["安排面试<br/>排期 + 面试官 + 方式"]
    B --> C["会议记录留痕<br/>评分维度 + 亮点/疑点/风险"]
    C --> D["阶段同步回表<br/>更新 stageQueue"]
    D --> A
  end
```

### 闭环电路

```
┌─────────────────────────────────────────────────────────────┐
│                      人才库 (Talent Pool)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  JD Tab ─→ 候选人表 ─→ 多选对比 ─→ 详情 Sheet         │  │
│  │                                          │             │  │
│  │                          ┌───────────────┤             │  │
│  │                          │               │             │  │
│  │                    排期安排 Tab    面试记录 Tab         │  │
│  │                        │               ↑               │  │
│  │                        ▼               │               │  │
│  │                  记录反馈 ────→ 面试记录归档            │  │
│  │                        │               │               │  │
│  │                        ▼               │               │  │
│  │                  提交留档 ─────────────┘               │  │
│  │                        │                               │  │
│  │                        ▼                               │  │
│  │              stageQueue 阶段推进                        │  │
│  │              (队首出队 → 下一阶段)                      │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  数据流: evaluation → talent_pool → interviews → feedback   │
│  阶段流: stageQueue["待沟通","技术一面","复试"] → 逐一出队   │
└─────────────────────────────────────────────────────────────┘
```

### 交付清单

#### 后端 — 数据模型

| # | 功能 | 说明 |
|---|------|------|
| 1 | `talent_pool` 表 | 跨 Job 人才库主表：`id`、`resume_id`（FK→resumes）、`jd_id`（FK→job_descriptions）、`source_job_id`、`source_batch`、`owner`、`communication_status`（待沟通/已确认/待反馈/已归档）、`stage_queue`（TEXT[]，阶段队列，队首=当前阶段）、`added_at`、`updated_at` |
| 2 | `interviews` 表 | 面试记录表：`id`、`talent_pool_id`（FK）、`round`（轮次名称）、`scheduled_at`、`duration_minutes`、`status`（已安排/已完成/已取消）、`interviewers`（TEXT[]）、`location`（线上/线下地址）、`conclusion`（通过/待定/淘汰/进入下一轮）、`overall_score`、`score_dimensions`（JSONB）、`highlights`（TEXT[]）、`concerns`（TEXT[]）、`risks`（TEXT[]）、`suggested_questions`（TEXT[]）、`notes`、`attachments`（JSONB，文件列表）、`created_at`、`updated_at` |

#### 后端 — API

| # | 功能 | 说明 |
|---|------|------|
| 1 | `GET /api/v1/talent-pool` | 人才库列表，支持 `?jd_id=`、`?status=`、`?owner=`、`?search=` 筛选，分页 |
| 2 | `POST /api/v1/talent-pool` | 从 evaluation 添加候选人到人才库，指定 JD 和 owner |
| 3 | `GET /api/v1/talent-pool/{id}` | 人才库条目详情，含排期和面试记录 |
| 4 | `PATCH /api/v1/talent-pool/{id}` | 更新沟通状态、阶段队列、owner |
| 5 | `DELETE /api/v1/talent-pool/{id}` | 从人才库移除候选人（软删除或标记归档） |
| 6 | `POST /api/v1/talent-pool/{id}/interviews` | 安排面试：轮次、时间、面试官、方式、地点 |
| 7 | `GET /api/v1/talent-pool/{id}/interviews` | 查询候选人所有面试记录 |
| 8 | `PATCH /api/v1/interviews/{id}` | 更新面试记录（面试完成后填写反馈） |
| 9 | `POST /api/v1/interviews/{id}/feedback` | 提交面试反馈：结论、评分维度、亮点/疑点/风险/建议追问/备注/附件 |
| 10 | `POST /api/v1/talent-pool/{id}/advance-stage` | 推进阶段：队首出队，可选自动创建下一轮面试 |
| 11 | `GET /api/v1/talent-pool/stats` | 人才库统计：各 JD 候选人数、各阶段分布、沟通状态分布 |

#### 前端

| # | 功能 | 说明 |
|---|------|------|
| 1 | 人才库 API 接入 | 替换 `candidate-data.ts` mock 数据，通过 API Client 获取真实人才库数据 |
| 2 | 排期安排接入 | "安排一面""发送日程""记录反馈"按钮对接后端排期/面试 API |
| 3 | 面试反馈提交 | 二级覆盖面板（`InterviewFeedbackPanel`）表单数据通过 API 提交留档 |
| 4 | 阶段同步展示 | 提交反馈后自动推进 `stageQueue`，人才库表格"当前阶段"列实时反映 |
| 5 | 面试记录归档 | 已提交的反馈进入面试记录 Tab 的时间线，不可编辑但可查看 |
| 6 | 从分析记录添加 | 在 Job 结果页（`/dashboard/jobs/[id]`）提供"添加到人才库"入口 |

### 阶段队列规则

- `stageQueue` 是一个有序数组，队首 = 候选人当前所处的阶段。
- 完成当前阶段（提交面试反馈）后，队首出队，下一项自动成为当前阶段。
- 阶段名称不强制枚举——HR 可以自定义（如"待沟通""技术一面""作业评估""复试""HR 终面"）。
- 当 `stageQueue` 为空时，候选人状态标记为"已完成全部流程"。
- 如果面试结论为"淘汰"，候选人进入"已归档"状态并从活跃队列移除。

### 不做（V1.2 范围外）

- 日历集成（Google Calendar / 飞书日历双向同步）
- 邮件/飞书通知（面试邀请自动发送）
- 面试官独立视角和待办列表
- 面试题目库和自动组卷
- 多轮面试的复杂工作流引擎（分支、条件跳转）

### V1.2 验收标准

- HR 可在人才库按 JD 筛选候选人，查看排期和面试记录。
- HR 可通过详情 Sheet 的排期安排 Tab 安排面试（时间、面试官、方式），数据持久化。
- HR 可在面试完成后通过"记录反馈"面板提交评分维度、结论、亮点/疑点/风险和建议追问。
- 提交反馈后，候选人的 `stageQueue` 自动推进，人才库表格"当前阶段"列同步更新。
- 面试记录 Tab 的时间线展示完整面试历史，包含每轮的结论和综合决策摘要。
- 可从分析记录页将评估结果一键添加到人才库。

### V1.1B — HR 简历分析闭环

| # | 功能 | 说明 |
|---|------|------|
| 1 | 简历上传 | PDF / DOCX 批量上传、文件预检查、创建 Job |
| 2 | 实时进度 | 连接 `GET /jobs/{id}/sse`，展示阶段、总进度、单文件状态 |
| 3 | 分析记录 | Job 列表、状态、统计、耗时、Token 和费用摘要 |
| 4 | 任务详情 | 阶段时间线、失败原因、重跑入口、结果入口 |
| 5 | 岗位库基础管理 | JD 列表、详情、新增、编辑、停用 |

### V1.1C — 候选人评估 + 筛选导出

| # | 功能 | 说明 |
|---|------|------|
| 1 | 候选人排名 | 基于 `jobs/{id}/results` 展示排名表和核心字段 |
| 2 | 多维筛选 | skills / years / city / scores / status 等前端筛选 |
| 3 | 详情查看 | 基本信息、人才评级、岗位匹配、证据片段、原始 JSON |
| 4 | TopK 报告 | 前端选择前 N 名形成导出范围 |
| 5 | Excel 导出 | 按当前筛选结果导出候选人评估表 |

### V1.1D — Admin 管理面板

| # | 功能 | 说明 |
|---|------|------|
| 1 | 模型管理 | 模型列表、默认模型、启用/停用、价格、Key 更新 |
| 2 | 用户管理 | 用户列表、创建用户、角色调整、禁用和恢复 |
| 3 | 系统状态 | DB 连通性、迁移状态、版本、缓存目录状态 |
| 4 | 危险操作 | 重置数据库、清理缓存，必须二次确认 |
| 5 | 数据中心 | 失败评估、解析异常、成本摘要和数据质量入口 |

### 不做（V1.1 移除）

- 多 HR 工作空间隔离。
- 在线编辑 Prompt 和评分手册。
- 报告模板管理。
- 模型价格历史审计。
- WebSocket；实时进度继续使用 SSE。

### V1.1 验收标准

- HR 可通过浏览器完成登录、上传简历、查看实时进度、进入任务结果。
- 候选人评估页可按岗位、城市、技能、评分和状态筛选，并导出当前结果。
- Admin 可管理模型、用户和系统状态，危险操作具备二次确认。
- 前端所有业务请求走统一 API Client，并正确处理 `{ code, msg, data, detail }` 响应信封。

---

## 后续版本

| 项目           | 优先级 | 说明                                   | 技术依赖                               |
| -------------- | ------ | -------------------------------------- | -------------------------------------- |
| OCR 解析      | 中     | 图片/扫描件简历                        | 需先确定输入格式和 OCR 服务            |
| 多 JD 批量评分 | 中     | 一份简历同时匹配多个岗位               | 提取复用已支持，评分阶段并发按 JD 分组 |
| 重复简历检测   | 低     | 同一候选人投了略微不同版本的简历       | 文本相似度 / embedding                 |
| 评分手册版本化 | 低     | 手册迭代后，历史评分可追溯用的哪个版本 | 评分表加 `manual_version` 字段         |
| 面试数据反哺   | 低     | 积累面试数据后反哺评分模型优化         | 依赖 V1.2 面试数据积累                 |
| 通知          | 低     | 评分完成/面试安排后邮件/飞书通知 HR    | 邮件服务 / 飞书 SDK                     |

---

## 技术债务跟踪

| #   | 问题                                                      | 版本 | 状态                           |
| --- | --------------------------------------------------------- | ---- | ------------------------------ |
| 1   | LLM provider 切换目前仅支持 OpenAI / Claude，如需扩展需改 Router | V0.1 | V0.4 Router 已预留 NOTE 扩展点 |
| 2   | Prompt 无版本管理，修改后无法回滚对比                            | V0.3 | 建议后续加 prompt 版本号       |
| 3   | 模型价格无历史审计，调价后历史 job_run 无法回溯当时单价          | V0.4 | 后续可加 price_snapshots 表    |
| 4   | 用户工作空间隔离                                    | V1.1 | 无 workspace 概念，模型和 job 全局可见 |
| 5   | 模型分层（官方 vs 自定义）                          | V1.0 | sync-prices 行为与角色权限交叉，需先设计分层模型 |
| 6   | 用户安全增强                                      | V1.0 | 暂无密码复杂度、修改密码、登录失败次数限制 |
| 7   | Token 撤销机制                                   | V1.0 | 无黑名单、无 refresh token |
| 8   | Rate Limiting                                   | V1.0 | V0.2 重试覆盖基本韧性，API 层限流后续加 |
