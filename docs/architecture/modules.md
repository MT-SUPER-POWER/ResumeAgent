# 模块规格

## 1. 文件解析器

| 属性 | 说明 |
|------|------|
| 运行位置 | 本地 |
| 依赖 | `pdf-extract`, `zip` |
| 输入 | 文件路径 (PDF/Word) |
| 输出 | `ParseResult { raw_text, status, error }` |

### 接口

```rust
struct ParseResult {
    raw_text: Option<String>,
    status: String,    // "success" | "failed" | "skipped"
    error: Option<String>,
}

async fn parse_resume(file_path: &str) -> ParseResult;
```

### 行为

- PDF: `pdf_extract::extract_text()` 提取文本层文字，不包含图片 OCR
- Word (.docx): 解压 zip，解析 `word/document.xml` 提取 `<w:t>` 文本节点
- 加密/损坏文件返回 `failed`
- 图片型 PDF（无文本层）标记 `skipped`，注明需 OCR
- 空文档标记 `skipped`

---

## 2. Resume Store

| 属性 | 说明 |
|------|------|
| 运行位置 | 本地 |
| 依赖 | SeaORM (PostgreSQL) |
| 职责 | 简历文件注册、SHA256 去重、原始文本持久化 |

### 接口

```rust
struct ResumeModel {
    id: i64,
    file_path: String,
    file_hash: String,    // SHA256, UNIQUE, 幂等关键
    file_name: String,
    file_type: String,    // "pdf" | "docx"
    raw_text: Option<String>,
    parse_status: String, // "pending" | "success" | "failed" | "skipped"
    parse_error: Option<String>,
    created_at: NaiveDateTime,
}

async fn upsert(file_path, file_hash, file_name, file_type) -> ResumeModel;
async fn find_by_hash(hash: &str) -> Option<ResumeModel>;
async fn update_parse(id, raw_text, status, error) -> ();
```

### 数据格式

```
resumes 表
─────────────────────────────────────────────────────
id         SERIAL PRIMARY KEY
file_path  TEXT NOT NULL
file_hash  TEXT NOT NULL UNIQUE     ← SHA256 去重
file_name  TEXT NOT NULL
file_type  TEXT NOT NULL            ← 'pdf' | 'docx'
raw_text   TEXT                     ← Phase 1 解析产出
parse_status TEXT DEFAULT 'pending'
parse_error TEXT
created_at TIMESTAMP DEFAULT now()
```

---

## 3. JD Store

| 属性 | 说明 |
|------|------|
| 运行位置 | 本地 |
| 依赖 | SeaORM (PostgreSQL) |
| 职责 | JD 查询、种子数据管理 |

### 接口

```rust
struct JdModel {
    id: String,
    title: String,
    tech_stack: Option<Vec<String>>,
    department: Option<String>,
    location: Option<String>,
    description: String,
    requirements: String,
    extra: Option<String>,
    is_active: bool,
}

async fn find_by_id(id: &str) -> Option<JdModel>;
async fn list_active() -> Vec<JdModel>;
```

---

## 4. LLM Client

| 属性 | 说明 |
|------|------|
| 运行位置 | 本地 |
| 依赖 | `reqwest` |
| 职责 | Provider 抽象 (OpenAI / Claude)、认证、超时、重试、token 统计 |

### 接口

```rust
struct LlmClient {
    // 内部持有 config 引用，决定调用 openai 还是 claude
}

struct LlmResponse {
    content: String,
    prompt_tokens: u64,
    completion_tokens: u64,
    estimated_cost: f64,
}

impl LlmClient {
    async fn chat(
        &self,
        system_prompt: &str,
        user_message: &str,
        require_json: bool,
    ) -> Result<LlmResponse, AppError>;
}
```

### 能力

- Provider 切换（配置文件 `provider` 字段）
- 超时控制
- 指数退避重试（max 3 次）
- Token 用量日志
- 成本估算
- JSON 响应校验 + 不合法重试

### 配置

```yaml
llm:
  provider: openai                     # openai | claude
  openai:
    model: gpt-4o
    api_key: ${OPENAI_API_KEY}
  claude:
    model: claude-sonnet-4-6
    api_key: ${ANTHROPIC_API_KEY}
  timeout_seconds: 60
  max_retries: 3
```

---

## 5. 评估器

| 属性 | 说明 |
|------|------|
| 运行位置 | LLM |
| 依赖 | LLM Client |
| 输入 | 简历纯文本 + JD + 两份评分手册 |
| 输出 | 结构化 JSON — `PipelineResult`（见下方 Schema） |
| Prompt 管理 | `src/prompts/` 目录，Markdown 模板 + `{{placeholder}}` 占位符 |

> **设计原则**：一次 LLM 调用完成信息提取和双维度评分，不拆分为两次调用。提取和评分共用同一段推理上下文，减少 token 浪费，降低延迟，避免提取结果与评分脱节。

### Schema: PipelineResult

**这是评估 prompt 的输出契约。Prompt 中必须指定此 JSON 格式，LLM 返回后用 `serde_json` 校验。落库时拆分为 `extractions.result_json` 和 `scores.result_json` 分别存储。**

```json
{
  "target_role": "实习前端工程师(React)",
  "best_match_role": "初级前端工程师(React)",
  "candidate": {
    "name": "张三",
    "email": "zhangsan@example.com",
    "phone": "13800138000",
    "city": "北京",
    "years_of_experience": 5.0,
    "current_title": "高级前端工程师",
    "education": [
      { "school": "北京大学", "degree": "本科", "major": "计算机科学与技术", "year": 2018 }
    ],
    "skills": ["TypeScript", "React", "Vue", "Node.js"],
    "work_experience": [
      {
        "company": "ABC科技有限公司", "title": "前端工程师",
        "duration": "2020.06 - 2024.12",
        "highlights": ["主导微前端架构落地，支撑 5 个业务线独立部署"]
      }
    ]
  },
  "evidence": {
    "逻辑思维与认知能力": [
      { "quote": "主导微前端架构落地...", "analysis": "架构设计能力", "level": "强" }
    ],
    "专业知识与专业技能": [],
    "创新与AI原生能力": [],
    "决策与问题解决能力": [],
    "组织协作与低自我": [],
    "抗压与韧性": [],
    "职业规划与自驱力": [],
    "履历质量与可信度": []
  },
  "talent_rating": {
    "total_score": 72.0,
    "dimensions": [
      { "name": "逻辑思维与认知能力", "score": 8.0, "evidence_level": "强", "comment": "架构设计能力强" }
    ]
  },
  "job_matching": {
    "total_score": 68.0,
    "dimensions": [
      { "name": "硬性条件匹配", "score": 7.0, "evidence_level": "中", "comment": "工作年限略低于要求" }
    ]
  },
  "overall_assessment": "候选人前端基础扎实，建议面试重点考察跨部门协作能力。"
}
```

### 字段约定

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `target_role` | string? | 否 | 候选人自己想应聘的岗位（从简历求职意向提取） |
| `best_match_role` | string? | 否 | AI 判断候选人最适合的岗位（从 JD 表格匹配） |
| `candidate` | object | 是 | 候选人基本信息，各字段可为 null |
| `evidence.<维度>` | array | 是 | 8 个维度，无证据则为 `[]` |
| `evidence.<维度>[].quote` | string | 是 | 原文引用 |
| `evidence.<维度>[].analysis` | string | 是 | 分析说明 |
| `evidence.<维度>[].level` | string | 是 | `"强"` / `"中"` / `"弱"` |
| `talent_rating.total_score` | number | 是 | 人才质量总分 |
| `talent_rating.dimensions` | array | 是 | 必须包含全部 8 个维度 |
| `job_matching.total_score` | number | 是 | 岗位匹配度总分 |
| `job_matching.dimensions` | array | 是 | 必须包含全部 7 个维度 |
| `dimensions[].score` | number | 是 | 0-10 分 |
| `dimensions[].evidence_level` | string | 是 | `"强"` / `"中"` / `"弱"` / `"缺失"` |
| `dimensions[].comment` | string | 是 | 评分依据说明 |
| `overall_assessment` | string | 是 | 综合评估摘要 |

### 评分维度

| 人才评级 8 维 | 岗位匹配度 7 维 |
|-------------|---------------|
| 逻辑思维与认知能力 | 硬性条件匹配 |
| 专业知识与专业技能 | 岗位核心能力匹配 |
| 创新与AI原生能力 | 经验场景匹配 |
| 决策与问题解决能力 | 业务/行业理解匹配 |
| 组织协作与低自我 | 产出成果匹配 |
| 抗压与韧性 | 工作方式与组织适配 |
| 职业规划与自驱力 | 风险与成本匹配 |
| 履历质量与可信度 | — |

### 8 个证据维度（与上面人才评级一致）

1. 逻辑思维与认知能力 — 架构设计、系统思考、问题分析
2. 专业知识与专业技能 — 技术栈深度、工具掌握、证书
3. 创新与AI原生能力 — 新技术探索、工具开发、AI使用
4. 决策与问题解决能力 — 技术选型、难题攻关、优化成果
5. 组织协作与低自我 — 团队合作、跨部门沟通、知识分享
6. 抗压与韧性 — 高压项目、快速迭代、解决冲突
7. 职业规划与自驱力 — 持续学习、技术博客、开源贡献
8. 履历质量与可信度 — 经历连贯性、量化成果、真实性

### Prompt 管理

Prompt 模板存放在 `src/prompts/` 目录，使用 `{{PLACEHOLDER}}` 占位符，运行时替换：

| 占位符 | 替换来源 | 说明 |
|--------|----------|------|
| `{{talent_manual}}` | `docs/references/人才评级打分手册-V1.md` | 8 维度评分标准 |
| `{{match_manual}}` | `docs/references/岗位匹配度评分手册-V1.md` | 7 维度匹配标准 |
| `{{resume_text}}` | 简历文件解析结果 | 简历纯文本 |
| `{{job_title}}` | JD 记录 | 岗位名称 |
| `{{job_department}}` | JD 记录 | 部门 |
| `{{job_requirements}}` | JD 记录 | 岗位要求 |
| `{{job_description}}` | JD 记录 | 岗位描述 |

### Prompt 策略

- System prompt 包含提取指令 + 两份评分手册 + 输出格式要求
- User message 包含简历文本 + JD 信息
- 要求严格输出以上 JSON 格式，不得编造信息
- 找不到证据的维度返回空数组 `[]`
- LLM 返回后 `serde_json::from_str::<PipelineResult>()` 校验
- 校验通过后拆分为 ExtractionResult 和 ScoreResult 分别落库

### 落库

评估器返回 `PipelineResult` 后，同时写入两张表：

1. `extractions` 表 — `{ candidate, evidence }` 部分
2. `scores` 表 — `{ talent_rating, job_matching, overall_assessment }` 部分

---

## 6. 报告生成器

| 属性 | 说明 |
|------|------|
| 运行位置 | 本地 |
| 依赖 | 无（纯字符串拼接） |
| 输入 | `PipelineResult`（包含 candidate + evidence + 双维度评分） |
| 输出 | Markdown 格式个人报告 |

### 接口

```rust
fn generate_personal_report(extraction: &ExtractionResult, score: &ScoreResult) -> String;
async fn save_personal_report(output_dir: &Path, name: &str, content: &str) -> Result<String>;
```

### Markdown 模板结构

```markdown
# 候选人评估报告: {name}

## 基本信息
| 字段 | 值 |
|------|----|
| 姓名 | {name} |
| 邮箱 | {email} |
| 城市 | {city} |
| 当前职位 | {current_title} |
| 工作年限 | {years}年 |
| 学历 | {education_summary} |
| 技能 | {skills} |

## 人才评级: {talent_score}/100
| 维度 | 得分 | 证据等级 | 评价 |
|------|------|----------|------|
| ... | ... | ... | ... |

## 岗位匹配度: {match_score}/100
| 维度 | 得分 | 证据等级 | 评价 |
|------|------|----------|------|
| ... | ... | ... | ... |

## 综合评估
{overall_assessment}
```

---

## 7. 汇总引擎

| 属性 | 说明 |
|------|------|
| 运行位置 | 本地 |
| 依赖 | 无（纯数据排序和序列化） |
| 输入 | 全部 `ScoreResult` |
| 输出 | 排名 MD + 汇总 JSON |

### 接口

```rust
struct RankingEntry {
    rank: usize,
    candidate_name: String,
    talent_score: f64,
    match_score: f64,
    skills: Vec<String>,
    report_path: String,
}

fn generate_ranking_md(entries: &[RankingEntry], jd_title: &str) -> String;
fn generate_summary_json(entries: &[RankingEntry], jd_title: &str) -> SummaryJson;
async fn save_summary(output_dir: &Path, md: &str, json: &SummaryJson) -> (String, String);
```

### 输出内容

- **ranking.md**: 按人才评级降序排列的候选人排名表
- **data.json**: 全部数据汇总（排名 + 统计），方便程序消费

### 输出目录结构

每次运行按时间戳隔离，防止不同批次文件混杂：

```
{base_dir}/
└── 2026-05-29T14-30-00/
    ├── reports/
    │   ├── 张三.md
    │   ├── 李四.md
    │   └── ...
    └── summary/
        ├── ranking.md
        └── data.json
```

- `{base_dir}` 由配置 `output.base_dir` 指定
- `{timestamp}` 为运行时的 `chrono::Utc::now()` 格式化时间戳
- 报告文件名取候选人姓名，非法字符替换为 `_`

---

## 8. Pipeline

| 属性 | 说明 |
|------|------|
| 运行位置 | 本地 |
| 依赖 | 全部模块 |
| 职责 | 流水线编排、SHA256 去重、状态追踪、断点续跑 |

### 接口

```rust
async fn run(resumes_dir: &str, jd_id: &str) -> Result<(), AppError>;
```

### 4 阶段流程

```
Phase 1 (本地)  扫描目录 → SHA256 → parse → upsert resumes
Phase 2 (LLM)   遍历 → evaluate(resume_text, jd) → upsert extractions + scores
Phase 3 (本地)  遍历 → generate_personal_report → 写 .md
Phase 4 (本地)  排序 → generate_ranking_md + generate_summary_json → 写文件
```

### 幂等策略

- **Phase 1**: `file_hash` 已存在且 `parse_status=success` → 跳过解析
- **Phase 2**: `extractions` 表中 `resume_id` 已有 `status=success` → 跳过评估
- **Phase 3**: 无幂等检查，纯函数直接覆盖写文件
- **Phase 4**: 无幂等检查，纯函数直接覆盖写文件

---

## 9. CLI 入口

| 属性 | 说明 |
|------|------|
| 运行位置 | 本地 |
| 依赖 | `clap` |
| 职责 | 命令路由、参数校验、配置加载 |

### 接口

```rust
enum Command {
    Run {
        resumes_dir: String,
        #[arg(long = "jd")]
        jd_id: String,
    },
    JdList,
    JdShow { id: String },
    DbStatus,
}

async fn run(cmd: Command) -> anyhow::Result<()>;
```

### 命令树

```
resume-agent
├── run <resumes-dir> --jd <id>    # 执行完整流水线
├── jd-list                          # 列出所有活跃 JD
├── jd-show <id>                     # 查看 JD 详情
└── db-status                        # 查看数据库连接状态
```
