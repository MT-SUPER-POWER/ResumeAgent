# CLI 使用指南

> 版本: V0.1 | 最后更新: 2026-05-29

## 环境准备

```bash
# 1. 切到 backend 目录（application.yaml 在此目录）
cd repo/backend

# 2. 确保 PostgreSQL 已启动，数据库已创建
# 3. 确保 application.yaml 中 LLM API key 已配置
```

## 命令一览

### 核心流程

```bash
# 分析整个目录下的简历（非递归，仅 PDF/DOCX）
cargo run -- run-dir --dir ./testdata

# 分析指定文件（支持多个）
cargo run -- run-files --files "testdata/简历1.pdf" "testdata/简历2.docx"

# 文件后缀大小写不敏感：.PDF、.Docx 均可识别
```

### JD 管理

```bash
# 列出所有活跃岗位
cargo run -- jd-list

# 查看某个岗位详情
cargo run -- jd-show <岗位ID>
```

### 数据库

```bash
# 检查数据库连接状态
cargo run -- db-status
```

## 输出结构

每次运行在 `output/` 下生成以时间戳命名的目录：

```
output/
└── 2026-05-29T14-30-00/
    ├── reports/          # 每份简历的 Markdown 报告
    │   ├── 张三.md
    │   └── 李四.md
    └── summary/          # 汇总排名
        ├── ranking.md    # 排名表（按人才评级降序）
        └── data.json     # 全部数据（方便程序消费）
```

## 配置说明

`application.yaml` 关键配置项：

```yaml
llm:
  provider: openai              # openai | claude
  openai:
    model: gpt-4o
    api_key: ${OPENAI_API_KEY}  # 支持环境变量注入
  claude:
    model: claude-sonnet-4-6
    api_key: ${ANTHROPIC_API_KEY}

db:
  host: ${PG_HOST}
  port: 5432
  database: resume_agent
  user: ${PG_USER}
  password: ${PG_PASSWORD}

output:
  base_dir: ./output
```

## 工作原理

```
简历文件 → 文件解析(PDF/DOCX→文本) → LLM 评估(提取+双维度打分) → 个人报告 → 汇总排名
```

- **人才评级**：8 维度，满分 100
- **岗位匹配度**：7 维度，满分 100
- SHA256 去重：同份简历重复处理不触发 LLM 调用
- 输出双重存储：PostgreSQL JSONB + 文件系统 Markdown/JSON
