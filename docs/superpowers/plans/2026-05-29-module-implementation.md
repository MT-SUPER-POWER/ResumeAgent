# Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement all 9 modules in dependency order, one module at a time, with tests in `/tests/` for each.

**Rules:**
- All tests in `repo/backend/tests/` (no `#[cfg(test)]` in `src/`)
- One module: implement -> test -> verify -> commit -> next
- Follow interfaces in `docs/architecture/modules.md`

## Task Table

| #   | Module                | What to build                                                                                                    | Test file                                     | Tests                                                                                                                           | Dependencies       |
| --- | --------------------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| 1   | database + repository | SeaORM CRUD for all 4 entities + soft delete + 9 JD seeds                                                        | `tests/db_integration.rs` + `tests/mapper.rs` | 基础设施（连接/迁移/表结构/种子数据）、CRUD（JD 增删改查、Resume 软删除、Extraction/Score 幂等）                                | Real PG            |
| 2   | parser                | PDF via `pdf_extract`, DOCX via `zip` + XML, SHA256 去重 + 落库验证                                              | `tests/parser_integration.rs`                 | PDF/DOCX 文本提取 + DB 落库（raw_text/status 正确写入）、SHA256 去重（同文件同 hash 跳过、异文件异 hash）、不支持类型、文件缺失 | 真实测试文件 + PG  |
| 3   | llm/client            | reqwest HTTP client for OpenAI + Claude chat APIs                                                                | `tests/llm_client_mock.rs`                    | Config loads, LlmResponse struct                                                                                                | None               |
| 4   | evaluator             | 一次 LLM 调用完成提取+双维度评分，prompt 模板在 `src/prompts/`，返回 `PipelineResult`，落库 extractions + scores | `tests/evaluator_test.rs`                     | PipelineResult JSON Schema 校验（8 evidence dims + 8 talent + 7 match）                                                         | None               |
| 5   | reporter              | Pure function: `PipelineResult` -> Markdown string. Save to filesystem                                           | `tests/reporter_test.rs`                      | Name in title, missing name -> 未知, scores included, empty skills -> -, overall assessment                                     | None               |
| 6   | summary               | Ranking table MD + summary JSON. Save to filesystem                                                              | `tests/summary_test.rs`                       | JD title in output, score columns, empty skills -> -, JSON total count                                                          | None               |
| 7   | pipeline              | 4-phase orchestrator: parse -> evaluate -> report -> summary. SHA256 dedup.                                      | `tests/pipeline_integration.rs`               | Ranking sort order by talent_score desc                                                                                         | Real PG + wiremock |
| 8   | cli                   | Wire clap subcommands (Run, JdList, JdShow, DbStatus) to pipeline + repository                                   | — (compile check)                             | —                                                                                                                               | None               |

## Test Summary

| Task      | Tests  | Requires              |
| --------- | ------ | --------------------- |
| 1         | 5 + 15 | PostgreSQL            |
| 2         | 4      | —                     |
| 3         | 2      | —                     |
| 4         | 3      | —                     |
| 5         | 5      | —                     |
| 6         | 4      | —                     |
| 7         | 1      | PostgreSQL + LLM mock |
| 8         | —      | compile only          |
| **Total** | **28** |                       |

## Progress Checklist

### [x] Task 1: database + repository
- [x] `repository/job_description.rs` — create, find_by_id, list_active, update, delete_by_id
- [x] `repository/resume.rs` — upsert, find_by_id, find_by_hash, delete_by_id, update_parse (soft delete + 恢复)
- [x] `repository/extraction.rs` — upsert (insert/update), find_by_resume, delete_by_resume
- [x] `repository/score.rs` — upsert (by resume_id+jd_id), find_by_resume_jd, delete_by_resume, list_success_by_jd
- [x] Migration 007: `resumes.deleted_at` 软删除 + Migration 008: PG timezone
- [x] Seed: 9 JDs from `docs/references/职业描述和招聘职位.md`
- [x] Time: `chrono::Local::now()` 精确到秒
- [x] `tests/mapper.rs` — 15 tests PASS (shared Runtime pattern)
- [x] Commit

### [x] Task 2: parser
- [x] `services/parser.rs` — parse_resume, parse_pdf, extract_docx_text
- [x] `tests/parser_integration.rs` — 6 tests (PDF/DOCX 提取 + DB 落库 + SHA256 去重 + 异常)
- [x] Commit

### [x] Task 3: llm/client
- [x] `llm/client.rs` — LlmClient, chat_openai, chat_claude (reqwest HTTP)
- [x] `tests/llm_connectivity.rs`
- [x] Commit

### [x] Task 4: evaluator
- [x] `src/prompts/` — 评估 prompt 模板 ({{placeholders}})
- [x] `llm/schemas.rs` — 新增 `PipelineResult`
- [x] `services/evaluator.rs` — 一次 LLM 调用，拆分为两份落库
- [x] 删除 `services/extractor.rs` + `services/scorer.rs`
- [x] `tests/evaluator_test.rs` — PipelineResult JSON Schema 校验
- [x] Commit

### [x] Task 5: reporter
- [x] `services/reporter.rs` — generate_personal_report(input: PipelineResult), save_personal_report
- [x] `tests/reporter_test.rs` — 5 tests PASS
- [x] Commit

### [x] Task 6: summary
- [x] `services/summary.rs` — generate_ranking_md, generate_summary_json, save_summary
- [x] `tests/summary_test.rs` — 4 tests PASS
- [x] Commit

### [x] Task 7: pipeline
- [x] `pipeline.rs` — run (4-phase: parse → evaluate → report → summary)
- [x] `tests/pipeline_integration.rs` — 1 test PASS
- [x] Commit

### [x] Task 8: cli
- [x] `cli/mod.rs` — JdList, JdShow from todo!() to real calls
- [x] `cargo check` — 0 errors
- [x] Commit
