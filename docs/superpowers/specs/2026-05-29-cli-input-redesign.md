# CLI Input Redesign

> 日期: 2026-05-29 | 范围: V0.1

## 目标

将 `run` 命令的输入从单一目录路径扩展为支持目录和文件两种方式，同时保持现有输出结构和辅助命令不变。

## 命令树

```
resume-agent
├── run --dir <目录>              # 扫描目录下所有简历
├── run --files <文件>...         # 分析指定文件
├── jd-list                       # 列出所有活跃 JD
├── jd-show <id>                  # 查看 JD 详情
└── db-status                     # 数据库连接状态
```

### `run --dir <目录>`

- 非递归扫描目标目录
- 收集 `.pdf`、`.docx` 文件（大小写不敏感：`.PDF`、`.DOCX`、`.Docx` 等均识别）
- 按文件名排序后依次处理
- 目录不存在或为空时直接报错退出

### `run --files <文件>...`

- 接受一个或多个文件路径
- 每个文件独立校验：不存在即报错退出，不静默跳过
- 后缀大小写不敏感
- 支持混合 PDF/DOCX

### 路径处理

- 相对路径和绝对路径均支持
- 含空格路径正常处理
- 不支持的文件类型在解析阶段标记 `skipped`（已有逻辑，无需改动）

## 输出

保持不变：

```
{output.base_dir}/<timestamp>/reports/<name>.md
{output.base_dir}/<timestamp>/summary/ranking.md
{output.base_dir}/<timestamp>/summary/data.json
```

## 保留命令

`jd-list`、`jd-show`、`db-status` 行为不变。

## 不改动

- `pipeline.rs` 的 4 阶段流程不变，只改入口的输入收集方式
- `parser.rs` 的解析逻辑不变
- `reporter.rs` / `summary.rs` 不变
- 数据库 schema 不变

## 实现要点

1. `main.rs` 的 Clap 定义改为 `--dir` 和 `--files` 互斥的 flag + arg 组合
2. CLI 层负责展开文件列表，统一传给 `pipeline::run(&files)`
3. `pipeline::run` 签名从 `&str`（目录路径）改为 `&[PathBuf]`（文件列表）
