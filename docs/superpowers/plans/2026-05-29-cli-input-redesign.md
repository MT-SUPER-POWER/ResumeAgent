# CLI Input Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `run` command to accept `--dir` or `--files` and pass a file list to pipeline.

**Architecture:** CLI layer collects and validates file paths from user input, then passes a flat `&[PathBuf]` to `pipeline::run`. Pipeline no longer knows about directory scanning — it just processes whatever files it receives.

**Tech Stack:** Rust, Clap 4 derive, existing pipeline/services unchanged.

---

### Task 1: Modify pipeline to accept file list

**Files:**
- Modify: `repo/backend/src/pipeline.rs` (full file)

- [ ] **Step 1: Change `pipeline::run` signature and remove directory scanning**

Replace the `read_dir` + extension filtering block (lines 19-31 in current `pipeline.rs`) with the new parameter. The function header changes from `pub async fn run(resumes_dir: &str)` and the directory-scanning block is removed.

```rust
use crate::errors::AppError;
use crate::llm::client::LlmClient;
use crate::llm::schemas::PipelineResult;
use crate::services::{evaluator, parser, reporter, summary};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};

pub async fn run(files: &[PathBuf]) -> Result<(), AppError> {
    let cfg = crate::config::get();
    let timestamp = crate::repository::local_now()
        .format("%Y-%m-%dT%H-%M-%S")
        .to_string();
    let run_dir = Path::new(&cfg.output.base_dir).join(&timestamp);
    tokio::fs::create_dir_all(&run_dir)
        .await
        .map_err(|e| AppError::Internal(format!("Cannot create output dir: {e}")))?;

    let client = LlmClient::new();

    println!("Processing {} resume(s)", files.len());

    let mut ranking_entries: Vec<summary::RankingEntry> = Vec::new();

    for (i, file_path) in files.iter().enumerate() {
        let file_name = file_path.file_name().unwrap().to_string_lossy();
        println!("[{}/{}] Processing: {file_name}", i + 1, files.len());

        // Phase 1: Parse
        let content = tokio::fs::read(file_path).await
            .map_err(|e| AppError::ParseError(format!("Cannot read file: {e}")))?;
        let mut hasher = Sha256::new();
        hasher.update(&content);
        let file_hash = format!("{:x}", hasher.finalize());
        let ext = file_path.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
        let file_type = if ext == "pdf" { "pdf" } else { "docx" };

        let existing = crate::repository::resume::find_by_hash(&file_hash).await?;
        let (resume_id, raw_text) = if let Some(ref r) = existing {
            if r.parse_status == "success" && r.raw_text.is_some() {
                println!("  Already parsed, skipping");
                (r.id, r.raw_text.clone())
            } else {
                (r.id, None)
            }
        } else {
            let r = crate::repository::resume::upsert(
                &file_path.to_string_lossy(), &file_hash, &file_name, file_type).await?;
            (r.id, None)
        };

        let raw_text = if let Some(t) = raw_text { t } else {
            let parse_result = parser::parse_resume(&file_path.to_string_lossy()).await;
            crate::repository::resume::update_parse(
                resume_id, parse_result.raw_text.as_deref(),
                &parse_result.status, parse_result.error.as_deref(),
            ).await?;
            if parse_result.status != "success" {
                println!("  Skipping (parse: {})\n", parse_result.status);
                continue;
            }
            parse_result.raw_text.unwrap()
        };

        // Phase 2: Evaluate (LLM)
        let existing_ext = crate::repository::extraction::find_by_resume(resume_id).await?;
        let pipeline_result: PipelineResult;
        if let Some(ref e) = existing_ext {
            if e.status == "success" {
                println!("  Already evaluated, skipping");
                let result_json = e.result_json.as_ref().ok_or_else(|| {
                    AppError::Internal("Extraction marked success but no result_json".into())
                })?;
                let candidate: crate::llm::schemas::Candidate =
                    serde_json::from_value(result_json["candidate"].clone()).map_err(|err| {
                        AppError::Internal(format!("Failed to deserialize stored candidate: {err}"))
                    })?;
                let evidence: crate::llm::schemas::Evidence =
                    serde_json::from_value(result_json["evidence"].clone()).map_err(|err| {
                        AppError::Internal(format!("Failed to deserialize stored evidence: {err}"))
                    })?;
                let scores = crate::repository::score::list_success_by_jd("__unmatched__").await?;
                let matching_score = scores.iter().find(|s| s.resume_id == resume_id);
                let talent_score = matching_score.and_then(|s| s.talent_score);
                let match_score = matching_score.and_then(|s| s.match_score);
                pipeline_result = PipelineResult {
                    target_role: None,
                    best_match_role: None,
                    candidate,
                    evidence,
                    talent_rating: crate::llm::schemas::TalentRating {
                        total_score: talent_score.unwrap_or(0.0),
                        dimensions: vec![],
                    },
                    job_matching: crate::llm::schemas::JobMatching {
                        total_score: match_score.unwrap_or(0.0),
                        dimensions: vec![],
                    },
                    overall_assessment: String::new(),
                };
            } else {
                pipeline_result = evaluator::evaluate(&client, resume_id, &raw_text).await?;
            }
        } else {
            pipeline_result = evaluator::evaluate(&client, resume_id, &raw_text).await?;
        }
        println!("  Evaluate: done");

        // Phase 3: Report
        let report_md = reporter::generate_personal_report(&pipeline_result);
        let report_path = reporter::save_personal_report(
            &run_dir.join("reports"),
            pipeline_result.candidate.name.as_deref().unwrap_or(&format!("resume_{resume_id}")),
            &report_md,
        ).await.map_err(|e| AppError::Internal(format!("Save report: {e}")))?;

        ranking_entries.push(summary::RankingEntry {
            rank: 0,
            resume_id,
            candidate_name: pipeline_result.candidate.name.clone().unwrap_or_else(|| "未知".into()),
            talent_score: Some(pipeline_result.talent_rating.total_score),
            match_score: Some(pipeline_result.job_matching.total_score),
            skills: pipeline_result.candidate.skills.clone(),
            report_path,
        });
        println!();
    }

    // Phase 4: Summary
    ranking_entries.sort_by(|a, b| b.talent_score.partial_cmp(&a.talent_score).unwrap());
    for (idx, e) in ranking_entries.iter_mut().enumerate() {
        e.rank = idx + 1;
    }

    let ranking_md = summary::generate_ranking_md(&ranking_entries, "All JDs");
    let summary_json = summary::generate_summary_json(&ranking_entries, "All JDs");
    let (md_path, json_path) = summary::save_summary(
        &run_dir.join("summary"), &ranking_md, &summary_json,
    ).await.map_err(|e| AppError::Internal(format!("Save summary: {e}")))?;

    println!("Summary saved:\n  {md_path}\n  {json_path}");
    println!("\nDone! {} resume(s) processed.", ranking_entries.len());
    Ok(())
}
```

- [ ] **Step 2: Run `cargo check` to verify pipeline compiles**

Run: `cargo check 2>&1`
Expected: pipeline.rs compiles cleanly. Note that `cli/mod.rs` will have a compile error because it still calls `pipeline::run(&resumes_dir)` — this will be fixed in Task 2.

- [ ] **Step 3: Commit**

```bash
git add repo/backend/src/pipeline.rs
git commit -m "refactor(pipeline): change run signature from &str to &[PathBuf]"
```

---

### Task 2: Add file collection logic to CLI layer

**Files:**
- Create: `repo/backend/src/cli/collect.rs`
- Modify: `repo/backend/src/main.rs` (full file, ~27 lines)
- Modify: `repo/backend/src/cli/mod.rs` (full file, ~66 lines)
- Modify: `repo/backend/src/lib.rs:1` (add `pub mod cli`)

- [ ] **Step 1: Create `collect.rs` with file collection logic**

Create `repo/backend/src/cli/collect.rs`:

```rust
use std::path::PathBuf;

/// Return supported extensions (lowercase, no dot).
fn supported_extensions() -> &'static [&'static str] {
    &["pdf", "docx"]
}

fn has_supported_extension(path: &std::path::Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| supported_extensions().contains(&e.to_lowercase().as_str()))
        .unwrap_or(false)
}

/// Collect resume files from a directory (non-recursive).
pub fn from_dir(dir: &str) -> Result<Vec<PathBuf>, String> {
    let dir_path = std::path::Path::new(dir);
    if !dir_path.is_dir() {
        return Err(format!("Directory not found: {dir}"));
    }

    let mut files: Vec<PathBuf> = std::fs::read_dir(dir_path)
        .map_err(|e| format!("Cannot read directory {dir}: {e}"))?
        .filter_map(|entry| entry.ok())
        .map(|e| e.path())
        .filter(|p| p.is_file() && has_supported_extension(p))
        .collect();

    if files.is_empty() {
        return Err(format!("No PDF or DOCX files found in: {dir}"));
    }

    files.sort();
    Ok(files)
}

/// Validate and collect individual file paths.
pub fn from_files(paths: &[String]) -> Result<Vec<PathBuf>, String> {
    let mut files = Vec::new();
    for p in paths {
        let path = std::path::Path::new(p);
        if !path.exists() {
            return Err(format!("File not found: {p}"));
        }
        if !path.is_file() {
            return Err(format!("Not a file: {p}"));
        }
        if !has_supported_extension(path) {
            return Err(format!(
                "Unsupported file type: {p} (expected .pdf or .docx)"
            ));
        }
        files.push(path.to_path_buf());
    }
    Ok(files)
}
```

- [ ] **Step 2: Update `main.rs` with new Clap definitions**

Replace `repo/backend/src/main.rs`:

```rust
mod cli;
mod config;
mod database;
mod errors;
mod llm;
mod models;
mod pipeline;
mod repository;
mod services;

use clap::Parser;

#[derive(Parser)]
#[command(name = "resume-agent", about = "AI-powered resume screening tool")]
struct Cli {
    #[command(subcommand)]
    command: cli::Command,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    config::logger::init();
    database::init().await;
    let cli = Cli::parse();
    cli::run(cli.command).await
}
```

- [ ] **Step 3: Update `cli/mod.rs` with new Run variants**

Replace `repo/backend/src/cli/mod.rs`:

```rust
mod collect;

use crate::pipeline;
use clap::Subcommand;

#[derive(Subcommand)]
pub enum Command {
    /// Process resumes from a directory (non-recursive)
    RunDir {
        #[arg(long = "dir", value_name = "DIR")]
        dir: String,
    },
    /// Process specific resume files
    RunFiles {
        #[arg(long = "files", value_name = "FILE", num_args = 1..)]
        files: Vec<String>,
    },
    /// List all active job descriptions
    JdList,
    /// Show job description details
    JdShow {
        /// JD ID
        id: String,
    },
    /// Show database migration status
    DbStatus,
}

pub async fn run(cmd: Command) -> anyhow::Result<()> {
    match cmd {
        Command::RunDir { dir } => {
            let files = collect::from_dir(&dir)?;
            pipeline::run(&files).await?;
        }
        Command::RunFiles { files } => {
            let files = collect::from_files(&files)?;
            pipeline::run(&files).await?;
        }
        Command::JdList => {
            let jds = crate::repository::job_description::list_active().await?;
            if jds.is_empty() {
                println!("No active JDs found.");
            } else {
                println!("| ID | Title | Department | Location |");
                println!("|----|-------|------------|----------|");
                for j in &jds {
                    println!(
                        "| {} | {} | {} | {} |",
                        j.id,
                        j.title,
                        j.department.as_deref().unwrap_or("-"),
                        j.location.as_deref().unwrap_or("-"),
                    );
                }
            }
        }
        Command::JdShow { id } => {
            match crate::repository::job_description::find_by_id(&id).await? {
                Some(jd) => {
                    println!("ID: {}", jd.id);
                    println!("Title: {}", jd.title);
                    println!("Department: {}", jd.department.as_deref().unwrap_or("-"));
                    println!("Location: {}", jd.location.as_deref().unwrap_or("-"));
                    println!("Tech Stack: {:?}", jd.tech_stack);
                    println!("Description: {}", jd.description);
                    println!("Requirements: {}", jd.requirements);
                    println!("Extra: {}", jd.extra.as_deref().unwrap_or("-"));
                }
                None => println!("JD not found: {id}"),
            }
        }
        Command::DbStatus => {
            println!("Database connection OK. Migrations run automatically on startup.");
        }
    }
    Ok(())
}
```

- [ ] **Step 4: Add `pub mod cli` to `lib.rs`**

In `repo/backend/src/lib.rs`, add `pub mod cli;` after the existing module declarations:

```rust
pub mod cli;
pub mod config;
pub mod database;
pub mod errors;
pub mod llm;
pub mod models;
pub mod repository;
pub mod services;

pub use errors::AppError;
```

- [ ] **Step 5: Run `cargo check` to verify compilation**

Run: `cargo check 2>&1`
Expected: 0 errors, 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add repo/backend/src/cli/collect.rs repo/backend/src/cli/mod.rs repo/backend/src/main.rs repo/backend/src/lib.rs
git commit -m "feat(cli): add --dir and --files input modes to run command"
```

---

### Task 3: Add unit tests for file collection

**Files:**
- Create: `repo/backend/tests/cli_collect_test.rs`

- [ ] **Step 1: Write tests for `collect` module**

Create `repo/backend/tests/cli_collect_test.rs`:

```rust
// cli collect 模块测试
//
// 覆盖文件收集逻辑：目录扫描、多文件收集、异常路径处理。
// 不涉及 pipeline 或 LLM 调用。

use resume_agent::cli::collect;
use std::fs;
use std::io::Write;

// ================= from_dir ==================

#[test]
fn test_from_dir_finds_pdf_and_docx() {
    let dir = tempfile::tempdir().unwrap();
    fs::write(dir.path().join("a.pdf"), b"pdf content").unwrap();
    fs::write(dir.path().join("b.docx"), b"docx content").unwrap();
    fs::write(dir.path().join("c.txt"), b"text file").unwrap();

    let files = collect::from_dir(dir.path().to_str().unwrap()).unwrap();
    assert_eq!(files.len(), 2);
    let names: Vec<&str> = files.iter().map(|p| p.file_name().unwrap().to_str().unwrap()).collect();
    assert!(names.contains(&"a.pdf"));
    assert!(names.contains(&"b.docx"));
}

#[test]
fn test_from_dir_case_insensitive_extensions() {
    let dir = tempfile::tempdir().unwrap();
    fs::write(dir.path().join("A.PDF"), b"upper").unwrap();
    fs::write(dir.path().join("B.Docx"), b"mixed").unwrap();

    let files = collect::from_dir(dir.path().to_str().unwrap()).unwrap();
    assert_eq!(files.len(), 2);
}

#[test]
fn test_from_dir_empty_directory() {
    let dir = tempfile::tempdir().unwrap();
    let result = collect::from_dir(dir.path().to_str().unwrap());
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("No PDF or DOCX files"));
}

#[test]
fn test_from_dir_not_found() {
    let result = collect::from_dir("./nonexistent_path_12345");
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("Directory not found"));
}

#[test]
fn test_from_dir_sorts_by_name() {
    let dir = tempfile::tempdir().unwrap();
    fs::write(dir.path().join("c.pdf"), b"c").unwrap();
    fs::write(dir.path().join("a.pdf"), b"a").unwrap();
    fs::write(dir.path().join("b.pdf"), b"b").unwrap();

    let files = collect::from_dir(dir.path().to_str().unwrap()).unwrap();
    let names: Vec<&str> = files.iter().map(|p| p.file_name().unwrap().to_str().unwrap()).collect();
    assert_eq!(names, vec!["a.pdf", "b.pdf", "c.pdf"]);
}

// ================= from_files ==================

#[test]
fn test_from_files_multiple_mixed_types() {
    let dir = tempfile::tempdir().unwrap();
    let pdf_path = dir.path().join("resume.pdf");
    let docx_path = dir.path().join("cover.docx");
    fs::write(&pdf_path, b"pdf").unwrap();
    fs::write(&docx_path, b"docx").unwrap();

    let files = collect::from_files(&[
        pdf_path.to_str().unwrap().to_string(),
        docx_path.to_str().unwrap().to_string(),
    ]).unwrap();
    assert_eq!(files.len(), 2);
}

#[test]
fn test_from_files_not_found() {
    let result = collect::from_files(&["nonexistent_file.pdf".to_string()]);
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("File not found"));
}

#[test]
fn test_from_files_unsupported_extension() {
    let dir = tempfile::tempdir().unwrap();
    let txt_path = dir.path().join("notes.txt");
    fs::write(&txt_path, b"text").unwrap();

    let result = collect::from_files(&[txt_path.to_str().unwrap().to_string()]);
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("Unsupported file type"));
}

#[test]
fn test_from_files_path_with_spaces() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("my resume .pdf");
    fs::write(&path, b"spaces").unwrap();

    let files = collect::from_files(&[path.to_str().unwrap().to_string()]).unwrap();
    assert_eq!(files.len(), 1);
}
```

- [ ] **Step 2: Make `collect` module public in `cli/mod.rs`**

In `repo/backend/src/cli/mod.rs`, change `mod collect;` to `pub mod collect;`.

Use Edit to replace:
- old: `mod collect;`
- new: `pub mod collect;`

- [ ] **Step 3: Run tests to verify they pass**

Run: `cargo test --test cli_collect_test 2>&1`
Expected: 9 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add repo/backend/tests/cli_collect_test.rs repo/backend/src/cli/mod.rs
git commit -m "test(cli): add unit tests for file collection logic"
```

---

### Task 4: Verify full integration

- [ ] **Step 1: Run all existing tests to check for regressions**

Run: `cargo test 2>&1`
Expected: All existing tests still pass. Note that `#[ignore]` E2E tests will be skipped.

- [ ] **Step 2: Manual smoke test — `--help` output**

Run: `cargo run -- --help 2>&1`
Expected: Shows subcommands including `run-dir` and `run-files` with their `--dir` and `--files` arguments.

- [ ] **Step 3: Manual smoke test — `run-dir` with test data**

Run: `cargo run -- run-dir --dir testdata 2>&1`
Expected: Starts processing resumes from testdata directory. LLM calls will fire (needs API key). Can be cancelled after confirming it starts correctly.

- [ ] **Step 4: Manual smoke test — `run-files` with single file**

Run: `cargo run -- run-files --files "testdata/王子健-后端开发 .pdf" 2>&1`
Expected: Starts processing a single file. Can be cancelled after confirming it starts correctly.

- [ ] **Step 5: Manual smoke test — invalid directory**

Run: `cargo run -- run-dir --dir ./nonexistent 2>&1`
Expected: Error "Directory not found" with non-zero exit code.

- [ ] **Step 6: Commit (if any final adjustments were needed)**

Only if changes were made during verification.
