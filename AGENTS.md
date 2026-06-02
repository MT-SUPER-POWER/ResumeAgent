<!-- BEGIN: cooperation-rule -->

# 项目协作规范

## 1. Git 提交信息规范（必须）

- 每次任务结束后，编写一条规范的 Git 提交信息并用于提交变更；遵循 Conventional Commits。
- 默认执行策略：直接提交本次任务相关改动（`git add` + `git commit`）。仅当用户明确说明"不要提交/稍后提交"时，改为只提供提交建议。
- ⚠️ **子仓库注意**：如果是 git submodule，变更需在对应子仓库内提交，必要时再到主仓库更新子模块引用。
  - 格式：`<type>(<scope>): <subject>`
  - 常用 type：`feat`、`fix`、`docs`、`refactor`、`chore`、`test`、`perf`、`build`。
  - scope 建议：`api`、`web`、`db`、`clip`、`transcode`、`infra`。
  - 主题行不超过 50 个字符，使用祈使句；中文或英文均可，但保持一致。
  - 可选正文（换行后 72 列换行）：说明动机、关键变更点与影响范围。
  - 示例：
    - `feat(clip): 实现直播片段自动切割接口`
    - `fix(web): 修复视频预览组件未释放资源`
    - `docs(readme): 增加本地开发指南`

## 2. 文档书写规范（必须）

- 每当完成一个功能模块的更新或者新增内容之后，必须要更新相关文档（如 README.md、API 文档等），确保文档内容与代码实现保持一致。
- 涉及到需要用流程图表示的内容不要用 ASCII 图，可以直接使用 `Mermaid` 语法生成流程图，保持文档的清晰和专业。
  - 和人对话的时候不要使用 `Mermaid`，而是使用 ASCII，因为对话界面不支持渲染 `Mermaid` 导致不好阅读
- `docs/` 下如果发生文档内容变动，必须要更新 `docs/README.md` 中的目录索引，确保文档结构清晰，便于查阅。

## 3. 代码规范（必须）

- 对于接口类的代码，一定要留下文档注释，说明接口的功能、输入输出参数以及返回值等信息，确保其他开发者能够快速理解和使用这些接口。
- 注释使用中文
- 可以使用 `======================== MODULE ========================` 这种大划分线来区分代码中的不同部分，提升代码的可读性和结构清晰度。
- 变更我的代码的时候，除非这个代码你也需要删除，或者当前的注释不合适，不然不要删除我的注释部分。


## 4. 关键性注释标签（必须）

代码中涉及扩展点、已知限制、临时方案、待优化逻辑等非显而易见的决策时，必须使用以下标准化标签注释。标签用大写，后跟冒号和中文说明：

| 标签         | 用途                       |
| ------------ | -------------------------- |
| `TODO`       | 待实现的功能或逻辑         |
| `FIXME`      | 已知有问题的代码，需要修复 |
| `DEBUG`      | 调试用代码，上线前需移除   |
| `BUG`        | 标记已知 bug 的位置        |
| `NOTE`       | 重要的设计决策或约束说明   |
| `OPTIMIZE`   | 性能可优化但当前不紧急     |
| `REVIEW`     | 需要人工复核的逻辑         |
| `DEPRECATED` | 即将废弃或不再推荐的用法   |

示例：
```rust
// NOTE: 如果模型协议不是 openai 或 claude 的，请在此补充新分支
match protocol {
    "openai" => openai_handler(...),
    "claude" => claude_handler(...),
    _ => return Err(...),
}
```

**注意**：标签仅用于上述特定场景的关键性注释。一般的代码说明、流程解释等普通注释不需要带关键字，保持简洁即可。

<!-- END: cooperation-rule  -->


<!-- BEING: AGENT-GUIDE-RULE-->
# Agent Guide

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.


## 5. Use Third Library Rules

When you try to code or answer questions about a third-party library, follow these rules:

1. **Check the documentation first**: Always refer to the official documentation of the library for usage patterns, best practices, and examples. This can prevent common mistakes and ensure you're using the library as intended. (You can use Context7 MCP ServerTools )

2. **Look for existing solutions**: Before writing new code, check if there are existing solutions or examples that address your problem. This can save time and reduce the likelihood of introducing bugs.

3. **Encounter the error message**: If you encounter an error message, search for it online. Often, others have faced the same issue and may have shared their solutions on forums, GitHub issues, or Stack Overflow.

<!-- END: AGENT-GUIDE-RULE-->
