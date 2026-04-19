# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-04-18)

**Core value:** 在方位向数据间断条件下，压缩感知恢复后的成像结果必须以图像质量为准，尽可能接近完整数据 BP 成像结果，尤其是主瓣宽度接近且旁瓣不能明显恶化。  
**Current focus:** Phase 2 - 间断 BP 成像基线

## Current Position

Phase: 2 of 5 (间断 BP 成像基线)  
Plan: 0 of 3 in current phase  
Status: Ready to discuss  
Last activity: 2026-04-19 - 完成 quick task「full-comment-simplify-pass」，补齐 src 深层注释并精简全项目文档表述

Progress: [#----] 20%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 38 min
- Total execution time: 1.9 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 3 | 115 min | 38 min |

**Recent Trend:**
- Last 5 plans: 01-01, 01-02, 01-03
- Trend: Active

## Accumulated Context

### Decisions

Decisions are logged in `PROJECT.md` Key Decisions table. Recent decisions affecting current work:

- [Init] 以 brownfield 整理而不是重写方式推进项目
- [Init] 以图像域质量作为压缩感知恢复的主要验收标准
- [Init] v1 不做 GUI 和 Python 重写
- [Phase 1] 配置覆盖严格失败，错误必须包含位置和原因
- [Phase 1] 数据集定位采用显式 `dataRoot` 优先，候选目录兜底
- [Phase 1] `main_gotha_bp.m` 作为唯一真实入口，`main_gotha_bp.ipynb` 仅作 wrapper
- [Phase 1] 实验结果产物默认不纳入版本控制，`cs_echo_recovery/results/` 默认忽略
- [Quick 2026-04-19] 新增 `config.output.enableOutput` 与 `csCfg.output.enableOutput`，关闭时不创建输出目录也不写实验产物
- [Quick 2026-04-19] 数据入口新增 `dataVariableName` 与 `dataFieldMap` 契约，支持非 GOTCHA 数据集按配置接入
- [Quick 2026-04-19] 文档入口改为新手导航结构，新增第一次运行指南，并为主流程/恢复流程关键参数补齐易懂注释
- [Quick 2026-04-19] 全项目注释统一改为短句风格，`src/` 深层链路补齐必要说明，正式文档删去重复表述

### Pending Todos

None yet.

### Blockers/Concerns

- 需要在后续 phase 中把 `cutInfo`、随机种子、输出元数据和运行目录命名继续钉牢为可复现实验基线
- 当前仓库已有最小数据入口自动化测试，但仍缺少覆盖成像与恢复全链路的标准回归入口

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Scope | GUI 图形界面 | Deferred | 2026-04-18 |
| Scope | Python 重写 | Deferred | 2026-04-18 |

## Quick Tasks Completed

| Date | Slug | Status | Notes |
|------|------|--------|-------|
| 2026-04-19 | output-master-switch | complete | Main and recovery outputs can now be disabled without creating directories or files |
| 2026-04-19 | generic-dataset-contract | complete | Dataset loading is now contract-driven with configurable variable names, field maps, docs, and smoke tests |
| 2026-04-19 | doc-onboarding-polish | complete | README and recovery docs were corrected; key config and recovery parameters now have beginner-friendly comments |
| 2026-04-19 | full-comment-simplify-pass | complete | Deep src comments were added and project docs/comments were shortened without losing meaning |

## Session Continuity

Last session: 2026-04-19  
Stopped at: Quick comment/doc pass complete; Phase 2 still ready to discuss
Resume file: `.planning/ROADMAP.md`
