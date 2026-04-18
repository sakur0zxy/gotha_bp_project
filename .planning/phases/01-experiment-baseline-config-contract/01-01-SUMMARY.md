---
phase: 01-experiment-baseline-config-contract
plan: 01
subsystem: config
tags: [matlab, config, schema, validation]
requires: []
provides:
  - "严格递归配置覆盖与 dotted-path 错误定位"
  - "恢复入口与主流程共享同一套配置覆盖语义"
affects: [phase-02, phase-03, reproducibility]
tech-stack:
  added: []
  patterns:
    - "默认配置 struct 作为唯一 schema"
    - "merge 阶段即拒绝未知字段和错层级"
key-files:
  created: []
  modified:
    - src/bp_merge_config.m
    - cs_echo_recovery/run_cs_echo_recovery_demo.m
key-decisions:
  - "保持 main_gotha_bp.m 的 fail-fast 顺序不变，只收紧 merge 与恢复入口语义"
  - "错误消息必须输出 cfg.* 完整字段路径，而不是模糊 invalid config"
patterns-established:
  - "Pattern: 严格 merge 先于 validate 和数据加载"
  - "Pattern: 恢复入口顶层配置也复用共享 merge"
requirements-completed: [IMG-02, QLT-01]
duration: 35min
completed: 2026-04-18
---

# Phase 1: 实验基线与配置契约 Summary

**严格配置覆盖与恢复入口统一失败语义，让误配置在数据加载前就能被定位到具体字段路径**

## Performance

- **Duration:** 35 min
- **Started:** 2026-04-18T21:58:00+08:00
- **Completed:** 2026-04-18T22:33:00+08:00
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- `bp_merge_config.m` 不再吞未知字段、错拼字段和错误层级
- 主流程非法配置会在 merge/validate 阶段失败，不再把错误拖到数据加载之后
- `run_cs_echo_recovery_demo.m` 改为复用共享严格 merge，恢复入口不再拥有独立宽松语义

## Task Commits

本次在手工 fallback 执行模式下使用共享实现提交，而不是每个 task 单独提交。

1. **Task 1: 严格递归配置覆盖** - `13d4fb6` (shared phase code commit)
2. **Task 2: 保持主流程 fail-fast 顺序** - `13d4fb6` (shared phase code commit)
3. **Task 3: 恢复入口复用共享 merge** - `13d4fb6` (shared phase code commit)

**Plan metadata:** captured in the phase completion docs commit

## Files Created/Modified
- `src/bp_merge_config.m` - 严格 schema-first 递归 merge 与路径级错误定位
- `cs_echo_recovery/run_cs_echo_recovery_demo.m` - 恢复入口改为复用共享 merge

## Decisions Made
- 继续沿用 `default_config.m` 作为唯一 schema 来源，而不是额外再造一份 schema 文件
- 保持 `main_gotha_bp.m` 现有的 `default -> merge -> validate -> load data` 顺序不变

## Deviations from Plan

### Auto-fixed Issues

**1. 手工 fallback 执行未按 task 粒度拆分 git 提交**
- **Found during:** Plan execution bookkeeping
- **Issue:** 当前执行环境未使用 gsd 子执行器流程，task 级原子提交未单独拆分
- **Fix:** 采用共享代码提交并在 summary 中明确记录
- **Files modified:** `.planning/phases/01-experiment-baseline-config-contract/01-01-SUMMARY.md`
- **Verification:** code commit `13d4fb6` 已覆盖本计划所有实现变更
- **Committed in:** phase completion docs commit

---

**Total deviations:** 1 auto-fixed
**Impact on plan:** 不影响代码结果与验证，只影响提交粒度记录方式。

## Issues Encountered
- 无代码级阻塞问题。`main_gotha_bp.m` 原有 fail-fast 顺序已经满足计划要求，因此无需额外改动。

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 2 可以直接建立在严格配置契约之上，不再需要担心未知配置字段静默失效
- 恢复入口的顶层配置语义已经与主流程统一，后续收敛恢复链路时边界更清晰

---
*Phase: 01-experiment-baseline-config-contract*
*Completed: 2026-04-18*
