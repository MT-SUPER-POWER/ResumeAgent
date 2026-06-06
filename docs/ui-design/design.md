# ResumeAgent Web UI 设计系统

> 状态: V0.3 模板唯一来源规范
> 适用范围: ResumeAgent Web 端 B 端后台管理界面
> 参考模板: `docs/references/next-shadcn-admin-dashboard/`
> 关联页面结构: `docs/ui-design/page-structure.md`

## 核心原则

ResumeAgent Web UI 不重新设计一套 Dashboard，也不再使用 Figma 设计稿作为落地依据。所有前端页面必须继承 `next-shadcn-admin-dashboard` 的布局、组件、主题和交互体系，再把 ResumeAgent 的业务导航、API 数据和页面内容接进去。

一句话验收标准:

```text
用户看到 ResumeAgent Web 时，应感觉它就是参考模板的一套业务定制版。
```

## 模板源

必须优先阅读和对齐以下文件:

| 模板文件 | 用途 |
| ---- | ---- |
| `docs/references/next-shadcn-admin-dashboard/README.md` | 模板能力、技术栈、设计方向 |
| `docs/references/next-shadcn-admin-dashboard/src/app/(main)/dashboard/layout.tsx` | Dashboard 全局布局、顶部栏、侧边栏 Provider |
| `docs/references/next-shadcn-admin-dashboard/src/app/(main)/dashboard/_components/sidebar/app-sidebar.tsx` | 侧边栏结构和品牌区域 |
| `docs/references/next-shadcn-admin-dashboard/src/app/(main)/dashboard/_components/sidebar/*.tsx` | 搜索、主题切换、布局控制、账号切换 |
| `docs/references/next-shadcn-admin-dashboard/src/navigation/sidebar/sidebar-items.ts` | 导航分组与菜单模型 |
| `docs/references/next-shadcn-admin-dashboard/src/app/(main)/auth/_components/login-form.tsx` | 登录表单结构、校验和 shadcn 表单风格 |
| `docs/references/next-shadcn-admin-dashboard/src/components/ui/` | shadcn/ui 基础组件库 |
| `docs/references/next-shadcn-admin-dashboard/src/lib/preferences/` | 主题、布局偏好与持久化 |
| `docs/references/next-shadcn-admin-dashboard/src/styles/presets/` | 主题 preset 与视觉 token |

## 必须继承

以下内容必须从模板迁移或保持同构实现:

- Next.js App Router 分组结构，优先使用 `(main)`、`dashboard`、`auth` 等模板路由组织。
- `SidebarProvider`、`SidebarInset`、`SidebarTrigger`、可折叠 Sidebar 和 inset 布局。
- Dashboard header 的工具区结构，包括搜索入口、布局控制、主题切换、账号入口。
- shadcn/ui 组件体系，特别是 `button`、`card`、`field`、`input`、`sidebar`、`dropdown-menu`、`dialog`、`table`、`tabs`、`badge`、`separator`、`tooltip`。
- 模板的 Tailwind v4、CSS variables、主题 preset、dark mode 和偏好存储。
- 模板的 spacing、border、radius、shadow、focus ring、hover/active/disabled 状态。
- 模板的响应式行为和移动端 Sidebar 体验。

## 允许改造

只能围绕 ResumeAgent 业务做定制:

- 品牌名称、Logo 文案、页面标题和空状态文案。
- Sidebar 导航项和分组。
- 登录接口、用户信息、权限控制和登出逻辑。
- 页面内容区的数据、表格、图表、表单和任务状态。
- API Client、状态管理、SSE 订阅、文件上传和报告下载。
- 业务主题色的轻微调整，但必须保持模板整体视觉语言。

## 禁止偏离

以下行为禁止:

- 按 Figma 设计稿、旧页面稿或旧自定义设计系统重建 Web UI。
- 手写新的 `AppShell`、`TopNav`、`Sidebar` 替代模板结构。
- 新增一套与模板重复的基础 UI 组件。
- 使用自定义浅灰后台风格覆盖模板的主题和组件状态。
- 删除模板的主题切换、布局控制、Sidebar 折叠能力，除非用户明确要求。
- 把参考模板只当作视觉灵感，而不是工程底座。
- 在业务页面中直接使用大量裸 `div + Tailwind` 拼装可由 shadcn/ui 表达的控件。

## ResumeAgent 信息架构

导航应以模板 `sidebar-items.ts` 的数据模型承载，分组如下:

```text
核心工作
- 首页
- 简历分析
- 分析记录
- 人才库

基础数据
- 岗位库
- 报告中心

系统管理
- 数据中心
- 系统设置
```

Admin 用户可见 `系统管理`；普通 HR 用户只看到 `核心工作` 和 `基础数据`。

## 页面落地规则

### 首页

目标: 快速查看系统态势和进入高频任务。

内容:

- 今日上传简历
- 今日完成评估
- 累计评估人数
- 待处理异常
- 近 15 天分析趋势
- 最近分析批次
- 系统状态
- 快捷入口

实现要求:

- 使用模板的 `Card`、`Chart`、`Badge`、`Button`。
- 页面密度、卡片圆角、标题层级和空白节奏必须贴近模板 Dashboard。

### 简历分析

目标: 发起一次简历分析任务。

内容:

- 上传区
- 文件预检查
- 自动岗位匹配说明
- 开始分析按钮
- 四阶段进度
- 单文件状态列表
- 完成后的结果入口

关键文案:

```text
上传后系统将基于岗位库自动判断候选人最匹配岗位，无需手动选择 JD。
```

实现要求:

- 上传区应使用模板 `Card`、`Field`、`Button`、`Progress` 或相近组件组合。
- 文件状态列表优先使用模板 `Table`。

### 分析记录

目标: 查找和追溯一次分析。

内容:

- 批次列表
- 批次状态
- 输出文件
- 异常原因
- 断点续跑 / 失败重试入口
- 单次分析结果入口
- 单次分析结果中的候选人排名、筛选和评估详情

实现要求:

- 使用模板 `Table`、`Badge`、`DropdownMenu`、`Pagination`。
- 单次分析结果使用 `/dashboard/jobs/{id}` 路由，并通过面包屑明确其归属于分析记录。
- 候选人结果详情面板优先使用模板 `Sheet` / `Drawer` / `Dialog` 风格。
- 分数和状态使用模板 `Badge`、`Progress`、`Chart`。

### 人才库

目标: 跨分析任务沉淀、检索和持续管理候选人。

内容:

- 候选人去重
- 历史评估记录
- 招聘流程状态
- 跨任务检索和筛选
- 按 JD 归档短名单候选人
- 多选候选人做同岗位横向对比
- 候选人详情中维护排期安排和面试记录

实现要求:

- 使用模板 `Tabs` 承载 JD 分类，默认提供“全部岗位”视图。
- 使用模板 `Table`、`Checkbox`、`Badge`、`Pagination` 承载人才库主表。
- 多选候选人后，在右侧同屏展示横向对比，比较人才评级、岗位匹配、当前阶段和推进建议。
- 候选人详情继续复用模板 `Sheet` 作为覆盖右侧主区域的详情面板，保留原有决策概览、人才评级、岗位匹配、履历、证据、原始 JSON，并新增“排期安排”“面试记录”两个 tab。
- 排期安排先承载沟通、面试、作业、截止等事项；面试记录承载面试官反馈、亮点、疑点、风险点、建议追问和综合决策摘要。
- “排期安排”中的“记录反馈”打开右侧二级覆盖面板，用于留存面试阶段、面试官、结论、评分维度、亮点、疑点、风险点、建议追问、原始备注和附件，提交后进入面试记录归档。
- “面试记录”采用招聘流程时间线、单场面试记录、综合决策摘要三栏布局，突出当前面试结论、留痕完整度、评分维度、证据片段和下一步动作。
- 面试流程状态采用候选人维度的阶段队列表达，队列首项就是当前阶段；完成一个环节后移除队首，不强制固定面试轮次。
- 在后端人才库数据模型落地前，前端可使用 mock 数据跑通 UI 闭环，但页面语义必须明确其是跨 Job 人才库，而不是单次 Job 排名表。

### 岗位库

目标: 管理自动匹配的基础数据。

内容:

- 在招 / 草稿 / 已归档岗位列表
- 岗位详情（基本信息、JD 内容、使用统计、操作记录）
- 新建 / 编辑 / 导入 / 复制 JD
- 归档岗位
- 关联候选人与分析任务统计

实现要求:

- 使用 analytics 风格 KPI 条带展示在招、草稿、归档岗位占比，以及关联候选人与分析任务。
- 使用模板 `Table`、`Badge`、`DropdownMenu`、`DateRangePicker` 和 `Sheet` 构建检索、筛选与详情工作流。
- 表格支持状态、部门、城市、技术栈筛选与分页；行操作包含查看、编辑、复制与更多菜单。
- 详情侧栏使用 `Tabs` 分区，底部提供编辑、复制、归档、新建分析与跳转人才库入口。

### 报告中心

目标: 管理交付物。

内容:

- 个人报告
- 汇总排名
- JSON 导出
- Excel 导出
- 报告预览

实现要求:

- 报告中心是交付物目录，不重复实现分析记录或候选人结果页面。
- 使用 `Tabs` 区分批次汇总与个人报告，使用 `Sheet` 预览产物信息。
- 报告必须保留返回对应单次分析结果的入口。

### 数据中心

目标: 监控数据质量和成本。

内容:

- 简历文件表
- 评估结果表
- `result_json`
- `token_usage`
- 异常统计
- Token / 成本趋势

### 系统设置

目标: 管理系统参数。

内容:

- LLM Provider
- 数据库连接
- 输出目录
- Prompt 模板
- 评分手册版本
- 超时 / 重试 / 并发

## 组件使用规范

| 场景 | 必须优先使用 |
| ---- | ---- |
| 页面容器 | 模板 Dashboard layout + `SidebarInset` |
| 导航 | 模板 sidebar 组件 + `sidebar-items.ts` 数据模型 |
| 表单 | `Field`、`Input`、`Checkbox`、`Select`、`Button`、`react-hook-form`、`zod` |
| 数据表 | `Table`、`Badge`、`DropdownMenu`、`Pagination` |
| 筛选 | `Input`、`Select`、`Popover`、`Calendar`、`DateRangePicker` |
| 详情 | `Sheet` / `Drawer` / `Dialog` |
| 指标 | `Card`、`Chart`、`Badge` |
| 通知 | `sonner` |
| 图标 | `lucide-react`，保持模板尺寸和描边风格 |

## 视觉质量检查

提交 Web UI 前必须自查:

- 是否能从代码结构看出它继承自参考模板。
- 页面是否保留模板的顶部工具栏、可折叠侧边栏、主题切换和布局控制。
- 新增页面是否使用模板 shadcn/ui 组件，而不是重复造基础控件。
- 间距、圆角、边框、阴影、字体大小是否与模板页面一致。
- 移动端是否仍保留模板 Sidebar 行为。
- 暗色模式是否可用，且没有硬编码浅色样式导致不可读。
- 业务色和状态色是否通过 token / class 体系表达，而不是散落 raw hex。

## Figma 处理规则

现有 Figma 设计稿完全不再使用。它不作为视觉风格、布局结构、组件规范、页面密度、色彩、间距或交互的参考来源。

后续 Web UI 重塑只允许依据:

- `docs/references/next-shadcn-admin-dashboard/`
- `docs/ui-design/design.md`
- `docs/ui-design/page-structure.md`
- ResumeAgent 业务 specs 和 API 文档

如果 Figma、旧设计稿或历史文档与参考模板冲突，以参考模板为准。
