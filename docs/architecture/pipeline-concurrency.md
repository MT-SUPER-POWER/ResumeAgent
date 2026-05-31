# Pipeline 并发模型

> 关联: `docs/superpowers/specs/2026-05-31-v0.3-concurrency-design.md` | 模块规格: `docs/architecture/modules.md`

## 一、模型概述

Producer-Consumer 管道，3 个 Stage，Stage 间通过 `tokio::sync::mpsc` bounded channel 连接。调度采用 Work-stealing 模式——各 worker 通过共享原子索引竞争获取下一个任务，快的多干、慢的少干，天然负载均衡。

```mermaid
flowchart LR
  subgraph S1["Stage 1: Parse (M workers)"]
    direction LR
    W1["Worker-1"]
    W2["Worker-2"]
    index["AtomicUsize"]
    W1 --- index
    W2 --- index
  end

  subgraph S2["Stage 2: Evaluate (N workers)"]
    direction LR
    E1["Worker-1"]
    E2["Worker-2"]
    E3["..."]
    E4["Worker-N"]
  end

  subgraph S3["Stage 3: Summary (1 consumer)"]
    DB["JOIN pipeline_states"]
    RPT["报告 + 排名"]
  end

  S1 -->|"bounded channel (N×2)"| S2
  S2 -->|"所有 worker 结束"| S3
```

## 二、任务分配: Work-stealing

### 2.1 核心原理：无锁分配

每个 worker 通过 **CPU 级原子操作** `AtomicUsize::fetch_add(1)` 获取自己的任务编号。

```mermaid
flowchart TD
    W["Worker 调用 fetch_add(1)"] --> CPU["CPU 原子指令<br/>LOCK CMPXCHG / LLD+SC"]
    CPU --> S1["① 读取当前值"]
    S1 --> S2["② 加 1"]
    S2 --> S3["③ 写回"]
    S3 --> S4["④ 返回旧值"]
    S4 --> HARD["硬件保证: 以上四步不可分割<br/>100 个 worker 同时调用<br/>也不会有两个拿到相同返回值"]
    HARD --> RESULT["返回值 v 唯一且递增<br/>files[v] 归当前 worker"]
```

没有锁、没有互斥、没有预先分配。`fetch_add` 本身就是硬件级别的互斥协议。

### 2.2 并发控制：Semaphore

Worker 在开始干活之前必须先获取 Semaphore 许可：

```mermaid
flowchart LR
    subgraph 槽位
        direction LR
        S1["许可 1<br/>(占用)"]
        S2["许可 2<br/>(占用)"]
        S3["许可 3<br/>(空闲)"]
    end
    WQ["排队等待的 worker"] -->|"释放后补上"| S3
```

M 个许可 = 最多 M 个 worker 同时在干活。工作快的 worker 自然抢到更多文件。

### 2.3 Worker 完整循环

```mermaid
flowchart TD
    START["Worker 启动"] --> ACQ["Semaphore.acquire()<br/>等待空闲槽位（最多 M 个同时工作）"]
    ACQ --> IDX["v = AtomicUsize.fetch_add(1)<br/>获取下一个文件索引"]
    IDX --> CHECK{"v < files.len()?"}
    CHECK -->|"否 — 文件已分完"| EXIT["drop permit<br/>Worker 退出"]
    CHECK -->|"是 — 拿到文件 v"| PARSE["parse files[v]<br/>PDF/Word → raw_text"]
    PARSE --> RESULT{"解析结果?"}
    RESULT -->|"成功"| SEND["tx.send(ParseTask)<br/>推入 Stage1→Stage2 channel"]
    RESULT -->|"失败"| LOG["pipeline_states.upsert<br/>(phase=parse, status=failed)"]
    SEND --> DROP["drop permit<br/>释放槽位"]
    LOG --> DROP
    DROP --> ACQ
```

```rust
// Stage 1 代码模板（示意）
let idx = Arc::new(AtomicUsize::new(0));
let sem = Arc::new(Semaphore::new(M));
let mut handles = vec![];

loop {
    let permit = sem.clone().acquire_owned().await;
    let v = idx.fetch_add(1, Ordering::Relaxed);
    if v >= files.len() { break; }

    let tx = tx.clone();
    let fp = files[v].clone();
    handles.push(tokio::spawn(async move {
        let _permit = permit;
        if let Some(task) = parse_one(&fp).await {
            let _ = tx.send(task).await;
        }
    }));
}
```

Stage 2 同理——从 channel 收到 ParseTask 后 acquire → spawn → release。

## 三、Stage 设计

### Stage 1: Parse Workers

| 属性 | 值 |
|------|-----|
| 角色 | Producer |
| Worker 数 | M，来自 `pipeline.parse_workers`，默认 2 |
| 分配策略 | Work-stealing (`Arc<AtomicUsize>`) |
| 并发控制 | `Semaphore(M)`，最多 M 个 task 同时在跑 |
| 工作内容 | 读文件 → SHA256 去重 → 解析 PDF/Word → 更新 resumes 表 → 登记 pipeline_states |
| 产出 | `ParseTask { resume_id, raw_text }`，推入 channel |
| 失败处理 | parse 失败 → 记录 pipeline_states(status=failed) → 继续下一份 |

**M 为何默认 2**：解析是本地 IO 密集型，2 个并发已可饱和磁盘读取。

### Stage 2: Evaluate Workers

| 属性 | 值 |
|------|-----|
| 角色 | Consumer + Producer（产出入库） |
| Worker 数 | N，来自 `llm.concurrency`，默认 3 |
| 分配策略 | Work-stealing（channel recv → sem acquire → spawn） |
| 并发控制 | `Semaphore(N)`，最多 N 个 LLM 同时在飞 |
| 工作内容 | 从 channel recv → 检查已有 evaluation（幂等）→ 调 LLM → 落库 evaluations + pipeline_states |
| 产出 | 存入 evaluations 表 + pipeline_states，Stage 3 通过 DB 读取 |
| 失败处理 | LLM 失败 → 记录 pipeline_states(status=failed) → 继续下一份 |

**N 为何默认 3**：大多数 LLM API 免费 tier 的保守并发数。

### Stage 3: Summary

| 属性 | 值 |
|------|-----|
| 角色 | Consumer（DB 汇聚） |
| Worker 数 | 1 |
| 工作内容 | 等待 Stage 1 + Stage 2 全结束 → `list_success_by_job_run()` 从 DB JOIN pipeline_states 拉取本 run 成功结果 → 生成个人报告 → 生成 ranking.md + data.json（含失败清单）→ 更新 job_runs |

## 四、Channel 与背压

channel 容量 = N × 2。

```mermaid
sequenceDiagram
    participant S1 as Stage 1 Worker
    participant CH as Channel (N×2)
    participant S2 as Stage 2 Worker

    S1->>CH: tx.send(task).await
    Note over CH: 容量有剩余 → 立即放入
    S2->>CH: rx.recv().await
    Note over CH: 有数据 → 立即返回

    S1->>CH: tx.send(task).await
    Note over CH: 已满 → 阻塞 S1
    S2->>CH: rx.recv().await (取走一个)
    Note over CH: 空出一个槽位 → S1 解除阻塞
```

- 当 Stage 2 全部 busy 时，channel 最多缓存 N×2 个 ParseTask
- channel 满时 `tx.send()` 阻塞 → Stage 1 自动降速
- 防止内存中堆积过多未处理任务

## 五、配置

```yaml
# application.yaml
pipeline:
  parse_workers: 2        # M — Stage 1 解析并发数

llm:
  concurrency: auto       # N — Stage 2 评估并发数，auto=3

db:
  max_connections: 20
```

### 连接池校验

启动时，`needed = (M + N) × 2 + 2`，若大于 `db.max_connections` 则打印建议但不阻塞。

## 六、错误处理

```mermaid
flowchart TD
    F["resume file"] --> P["Stage 1: Parse"]
    P -->|"success"| T["push ParseTask → channel"]
    P -->|"failed"| PS["pipeline_states<br/>phase=parse<br/>status=failed"]
    PS --> NEXT1["下一份"]

    T --> E["Stage 2: Evaluate"]
    E -->|"success"| ES["pipeline_states<br/>phase=evaluate<br/>status=success"]
    E -->|"failed"| EF["pipeline_states<br/>phase=evaluate<br/>status=failed"]
    EF --> NEXT2["下一份"]

    ES --> S3["Stage 3: Summary"]
    EF --> S3
    S3 --> RPT["ranking.md → 处理失败章节<br/>data.json → failures 字段"]
```

- 所有错误通过 `pipeline_states(job_run_id, phase, error_msg)` 持久化
- job_runs.errors JSONB 持续写入运行日志
- Stage 3 汇总时自动关联本 run 的失败记录

## 七、生命周期

```mermaid
flowchart TD
    INIT["1. 初始化"] --> INIT_DETAIL["创建 job_run (UUID)<br/>DB 连接池校验<br/>创建 bounded channel (容量 N×2)"]

    INIT_DETAIL --> S1["2. Stage 1 (M workers)"]
    S1 --> S1_DETAIL["Work-stealing 遍历文件列表<br/>Semaphore(M) 控制并发<br/>解析成功 → tx.send(ParseTask)"]

    S1_DETAIL --> S2["3. Stage 2 (N workers)"]
    S2 --> S2_DETAIL["从 channel recv<br/>Semaphore(N) 控制并发 LLM<br/>评估 + 落库"]

    S2_DETAIL --> S3["4. Stage 3 (主线程)"]
    S3 --> S3_DETAIL["await Stage1 + Stage2 完成<br/>JOIN pipeline_states 拉取结果<br/>生成报告 + ranking.md + data.json<br/>mark_done(job_run)<br/>打印完成汇总 + 失败清单"]
```

### 关键同步点

| 事件 | 机制 |
|------|------|
| Stage 1 → Stage 2 数据传递 | `mpsc::channel::send()` |
| Stage 1 全部完成 | drop 原始 tx，Stage 1 handle.await |
| Stage 2 全部完成 | drop rx → while-let 退出 → 收集 JoinHandle |
| Stage 3 汇聚 | `list_success_by_job_run()` SQL JOIN |