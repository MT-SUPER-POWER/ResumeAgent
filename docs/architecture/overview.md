# 架构总览

> 关联设计文档: `docs/superpowers/specs/2026-05-28-resume-agent-design.md`

## 架构模式

**混合架构** —— 确定性步骤本地执行，需要判断推理的步骤 LLM 执行。

```mermaid
flowchart TB
  CLI["CLI 入口<br/>(resume-agent)"]

  subgraph Local["本地层"]
    Parser["文件解析器<br/>(PDF/Word→文本)"]
    JD[(JD Store<br/>PostgreSQL)]
    Resume[(Resume Store<br/>PostgreSQL)]
    Report["报告生成器<br/>(JSON→MD)"]
    Summary["汇总引擎<br/>(排名+统计+Excel)"]
  end

  subgraph LLM["LLM 层"]
    Extract["信息提取器<br/>(简历→结构化JSON)"]
    Scorer["评分引擎<br/>(双维度评分)"]
  end

  subgraph Infra["横切基础设施"]
    LLMClient["LLM Client<br/>(Provider抽象/限流/重试/并发)"]
    TaskRunner["Task Runner<br/>(队列/状态/断点续跑/幂等)"]
  end

  CLI --> Parser
  CLI --> JD
  CLI --> Resume
  Parser --> Resume
  Parser --> Extract
  JD --> Scorer
  Extract --> Scorer
  Scorer --> Report
  Report --> Summary

  LLMClient -.-> Extract
  LLMClient -.-> Scorer
  TaskRunner -.-> Parser
  TaskRunner -.-> Extract
  TaskRunner -.-> Scorer
  TaskRunner -.-> Report
```

## 设计原则

| 原则                   | 说明                                                                     |
| ---------------------- | ------------------------------------------------------------------------ |
| **LLM 只做判断**       | 文件解析、格式转换、汇总排序由本地代码完成。LLM 仅负责"看懂简历"和"打分" |
| **提取一次，评分多次** | 简历提取结果与 JD 无关，同一份提取结果可对多个 JD 评分                   |
| **每一步幂等**         | 基于 SHA256 做去重，中断后可断点续跑                                     |
| **中间产物全程留存**   | extracted JSON、score JSON 全部持久化，方便调试和复用                    |
| **Prompt 与代码分离**  | Prompt 模板独立为 Markdown 文件，用占位符注入变量                        |

## 模块关系

```mermaid
flowchart LR
  Parser["1.文件解析器"] --> ResumeStore["2.Resume Store"]
  Parser --> Extractor["5.信息提取器"]
  JDStore["3.JD Store"] --> Scorer["6.评分引擎"]
  Extractor --> Scorer
  Scorer --> Reporter["7.报告生成器"]
  Reporter --> Summarizer["8.汇总引擎"]

  LLMClient["4.LLM Client"] -.-> Extractor
  LLMClient -.-> Scorer
  TaskRunner["9.Task Runner"] -.-> Parser
  TaskRunner -.-> Extractor
  TaskRunner -.-> Scorer
  TaskRunner -.-> Reporter

  CLI["10.CLI 入口"] --> Parser
  CLI --> JDStore
  CLI --> ResumeStore
  CLI --> Summarizer
```

## 数据存储策略

```mermaid
flowchart TB
  subgraph PostgreSQL
    JD[(job_descriptions)]
    R[(resumes)]
    E[(extractions)]
    S[(scores)]
    JR[(job_runs)]
    SM[(schema_migrations)]
  end

  subgraph Filesystem["文件系统 (output/)"]
    ExtractedJSON["extracted/*.json"]
    ScoredJSON["scored/*.json"]
    Reports["reports/*.md"]
    SummaryFiles["summary/*.md|json|xlsx"]
  end

  R -->|raw_text| Filesystem
  E -->|result_json| ExtractedJSON
  S -->|result_json| ScoredJSON
  Reports --> SummaryFiles
```

**双重存储**：评分结果同时写入 PostgreSQL（JSONB，方便查询排序）和文件系统（Markdown/JSON，方便人工阅读）。

## 技术选型理由

| 决策         | 选择                   | 原因                                                      |
| ------------ | ---------------------- | --------------------------------------------------------- |
| 数据库       | PostgreSQL             | 全栈项目长期选择，JSONB 支持灵活查询，后续 Web 版无需迁移 |
| 语言         | Rust                   | 高性能、内存安全，SeaORM 生态完善                            |
| 迁移方案     | 版本号 SQL             | 简单可追溯，适合 MVP 快速迭代                             |
| LLM 两次调用 | 提取+评分分开          | 好调试，提取结果可复用，prompt 更聚焦                     |
| Prompt 管理  | Markdown 文件 + 占位符 | 与代码解耦，方便 diff/Review/A/B 测试                     |
