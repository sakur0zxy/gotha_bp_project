# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-18)

**Core value:** 在方位向数据间断条件下，压缩感知恢复后的成像结果必须以图像质量为准尽可能接近完整数据 BP 成像结果，尤其是主瓣宽度接近且旁瓣不明显恶化。
**Current focus:** Phase 1 - 实验基线与配置契约

## Current Position

Phase: 1 of 5 (实验基线与配置契约)
Plan: 0 of 3 in current phase
Status: Ready to plan
Last activity: 2026-04-18 - 完成 Phase 1 discuss，锁定配置契约、数据路径、默认运行模式、入口统一和产物管理决策

Progress: [-----] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: 0 min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: none
- Trend: Stable

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: 以 brownfield 整理而不是重写方式推进项目
- [Init]: 以图像域质量作为压缩感知恢复的主要验收标准
- [Init]: v1 不做 GUI 和 Python 重写
- [Phase 1]: 配置覆盖严格失败，错误必须包含位置和原因
- [Phase 1]: 数据集定位采用显式路径优先，约定查找兜底
- [Phase 1]: 主流程默认 headless，notebook/demo 保持交互
- [Phase 1]: `main_gotha_bp.m` 作为唯一真实入口
- [Phase 1]: 实验结果产物默认不纳入版本控制

### Pending Todos

None yet.

### Blockers/Concerns

- 需要在后续 phase 中把 `cs_echo_recovery/` 收敛为受控、可复现实验链路，而不是仅停留在本地实验雏形
- 当前仓库缺少自动化测试与标准回归入口，后续改动存在退化风险

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Scope | GUI 图形界面 | Deferred | 2026-04-18 |
| Scope | Python 重写 | Deferred | 2026-04-18 |

## Session Continuity

Last session: 2026-04-18 21:37
Stopped at: Phase 1 context gathered
Resume file: .planning/phases/01-experiment-baseline-config-contract/01-CONTEXT.md
