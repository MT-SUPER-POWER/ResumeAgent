# Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement all 9 modules in dependency order, one module at a time, with tests in `/tests/` for each.

**Rules:**
- All tests in `repo/backend/tests/` (no `#[cfg(test)]` in `src/`)
- One module: implement -> test -> verify -> commit -> next
- Follow interfaces in `docs/architecture/modules.md`

## Task Table

| #   | Module                | What to build                                                                                     | Test file                       | Tests                                                                                                        | Dependencies            |
| --- | --------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------ | ----------------------- |
| 1   | database + repository | SeaORM CRUD for all 4 entities + soft delete + 9 JD seeds                          | `tests/db_integration.rs` + `tests/mapper.rs` | 基础设施（连接/迁移/表结构/种子数据）、CRUD（JD 增删改查、Resume 软删除、Extraction/Score 幂等） | Real PG                 |
| 2   | parser                | PDF via `pdf_extract`, DOCX via `zip` + XML, SHA256 去重 + 落库验证                 | `tests/parser_integration.rs`   | PDF/DOCX 文本提取 + DB 落库（raw_text/status 正确写入）、SHA256 去重（同文件同 hash 跳过、异文件异 hash）、不支持类型、文件缺失 | 真实测试文件 + PG |
| 3   | llm/client            | reqwest HTTP client for OpenAI + Claude chat APIs                                                 | `tests/llm_client_mock.rs`      | Config loads, LlmResponse struct                                                                             | None                    |
| 4   | extractor             | LLM extraction: hardcoded system prompt, call client, parse `ExtractionResult`, upsert to DB      | `tests/extractor_test.rs`       | Parse valid JSON, parse null name, reject missing dimension                                                  | None                    |
| 5   | scorer                | LLM scoring: load manuals from `docs/references/`, call client, parse `ScoreResult`, upsert to DB | `tests/scorer_test.rs`          | Parse valid JSON (8 talent dims + 7 match dims), reject missing fields                                       | None                    |
| 6   | reporter              | Pure function: `ExtractionResult` + `ScoreResult` -> Markdown string. Save to filesystem          | `tests/reporter_test.rs`        | Name in title, missing name -> 未知, scores included, empty skills -> -, overall assessment                  | None                    |
| 7   | summary               | Ranking table MD + summary JSON. Save to filesystem                                               | `tests/summary_test.rs`         | JD title in output, score columns, empty skills -> -, JSON total count                                       | None                    |
| 8   | pipeline              | 5-phase orchestrator: parse -> extract -> score -> report -> summary. SHA256 dedup at each phase  | `tests/pipeline_integration.rs` | Ranking sort order by talent_score desc                                                                      | Real PG + wiremock      |
| 9   | cli                   | Wire clap subcommands (Run, JdList, JdShow, DbStatus) to pipeline + repository                    | — (compile check)               | —                                                                                                            | None                    |

## Test Summary

| Task      | Tests  | Requires              |
| --------- | ------ | --------------------- |
| 1         | 5 + 15 | PostgreSQL            |
| 2         | 4      | —                     |
| 3         | 2      | —                     |
| 4         | 3      | —                     |
| 5         | 3      | —                     |
| 6         | 5      | —                     |
| 7         | 4      | —                     |
| 8         | 1      | PostgreSQL + LLM mock |
| 9         | —      | compile only          |
| **Total** | **31** |                       |

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

### [ ] Task 2: parser
- [ ] `services/parser.rs` — parse_resume, parse_pdf, extract_docx_text
- [ ] `tests/parser_integration.rs` — 文本提取 + DB 落库验证 + SHA256 去重 + 异常场景
- [ ] Commit

### [ ] Task 3: llm/client
- [ ] `llm/client.rs` — LlmClient, chat, chat_openai, chat_claude
- [ ] `tests/llm_client_mock.rs` — 2 tests PASS
- [ ] Commit

### [ ] Task 4: extractor
- [ ] `services/extractor.rs` — extract (prompt + LLM + JSON parse + DB upsert)
- [ ] `tests/extractor_test.rs` — 3 tests PASS
- [ ] Commit

### [ ] Task 5: scorer
- [ ] `services/scorer.rs` — score (manuals + LLM + JSON parse + DB upsert)
- [ ] `tests/scorer_test.rs` — 3 tests PASS
- [ ] Commit

### [ ] Task 6: reporter
- [ ] `services/reporter.rs` — generate_personal_report, save_personal_report
- [ ] `tests/reporter_test.rs` — 5 tests PASS
- [ ] Commit

### [ ] Task 7: summary
- [ ] `services/summary.rs` — generate_ranking_md, generate_summary_json, save_summary
- [ ] `tests/summary_test.rs` — 4 tests PASS
- [ ] Commit

### [ ] Task 8: pipeline
- [ ] `pipeline.rs` — run (5-phase + SHA256 dedup)
- [ ] `tests/pipeline_integration.rs` — 1 test PASS
- [ ] Commit

### [ ] Task 9: cli
- [ ] `cli/mod.rs` — JdList, JdShow from todo!() to real calls
- [ ] `cargo check` — 0 errors
- [ ] Commit
