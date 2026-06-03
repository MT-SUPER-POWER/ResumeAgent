# ResumeAgent Web UI 设计系统

> 状态: V0.2 模板继承规范
> 适用范围: ResumeAgent Web 端 B 端后台管理界面
> 参考模板: `docs/references/next-shadcn-admin-dashboard/`
> 关联页面结构: `docs/ui-design/page-structure.md`

## 核心原则

ResumeAgent Web UI 不重新设计一套 Dashboard。所有前端页面必须继承 `next-shadcn-admin-dashboard` 的布局、组件、主题和交互体系，再把 ResumeAgent 的业务导航、API 数据和页面内容接进去。

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
- 候选人评估

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

实现要求:

- 使用模板 `Table`、`Badge`、`DropdownMenu`、`Pagination`。

### 候选人评估

目标: 查看排名、筛选候选人、阅读评估详情。

内容:

- 排名表
- 筛选区
- 候选人详情抽屉
- 8 维人才评级
- 7 维岗位匹配
- 证据片段
- 原始 JSON 入口

实现要求:

- 详情面板优先使用模板 `Sheet` / `Drawer` / `Dialog` 风格。
- 分数和状态使用模板 `Badge`、`Progress`、`Chart`。

### 岗位库

目标: 管理自动匹配的基础数据。

内容:

- 活跃岗位列表
- 岗位详情
- 新增 / 编辑 / 导入
- 启用 / 停用
- 最近被推荐次数

### 报告中心

目标: 管理交付物。

内容:

- 个人报告
- 汇总排名
- JSON 导出
- Excel 导出
- 报告预览

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

## Figma 约束

现有 Figma 设计稿只能作为业务信息架构和页面内容参考，不再作为独立视觉系统来源。

Figma 后续如需继续维护，应重建为模板继承版:

- Foundations 对齐模板 CSS variables 和 shadcn/ui token。
- Components 对齐模板 `src/components/ui`。
- Pages 只表达 ResumeAgent 业务内容，不重新发明 Dashboard 壳。
