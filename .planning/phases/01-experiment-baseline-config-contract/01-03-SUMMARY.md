---
phase: 01-experiment-baseline-config-contract
plan: 03
subsystem: docs
tags: [readme, examples, reproducibility, matlab]
requires: []
provides:
  - "面向研究者的 README 总入口文档"
  - "主流程与恢复流程最小示例"
  - "配置契约参考文档"
affects: [phase-02, onboarding, reproducibility]
tech-stack:
  added: []
  patterns:
    - "通过示例脚本展示配置覆盖，而不是要求用户改默认配置文件"
key-files:
  created:
    - docs/config_contract.md
    - examples/run_bp_minimal.m
    - examples/run_cs_recovery_minimal.m
  modified:
    - README.md
key-decisions:
  - "README 只保留总览，详细契约下沉到 docs/config_contract.md"
  - "示例脚本显式展示 dataRoot 与覆盖 struct 的正式用法"
patterns-established:
  - "Pattern: README 指向 examples 和 docs，而不是复制全部细节"
  - "Pattern: 示例脚本优先演示覆盖 struct，不演示改源码"
requirements-completed: [REP-01, IMG-02, QLT-01]
duration: 25min
completed: 2026-04-18
---

# Phase 1: 实验基线与配置契约 Summary

**README、最小示例和配置契约文档一起把“如何运行、如何覆盖、如何判断错误”写成了仓库内可直接复用的说明**

## Performance

- **Duration:** 25 min
- **Started:** 2026-04-18T23:28:00+08:00
- **Completed:** 2026-04-18T23:53:00+08:00
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- 根 README 重写为面向研究者的正式入口文档
- 新增主流程与恢复流程最小示例，明确通过覆盖 struct 调整实验
- 新增配置契约文档，固定严格失败、显式 `dataRoot` 和 notebook wrapper 语义

## Task Commits

本次在手工 fallback 执行模式下使用共享实现提交，而不是每个 task 单独提交。

1. **Task 1: README 总入口文档** - `13d4fb6` (shared phase code commit)
2. **Task 2: 主流程与恢复流程最小示例** - `13d4fb6` (shared phase code commit)
3. **Task 3: 配置契约参考文档** - `13d4fb6` (shared phase code commit)

**Plan metadata:** captured in the phase completion docs commit

## Files Created/Modified
- `README.md` - 面向研究者的总入口说明、数据放置、入口、输出和版本控制约定
- `examples/run_bp_minimal.m` - 主流程最小示例
- `examples/run_cs_recovery_minimal.m` - 恢复流程最小示例
- `docs/config_contract.md` - 配置契约、正反例和推荐工作流

## Decisions Made
- 根 README 不再承担全部细节，避免文档臃肿和重复
- 最小示例统一使用显式 `dataRoot`，把正式复现方式写清楚

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- 无阻塞问题。README、examples 和配置契约文档的结构与 Phase 1 的锁定决策一致。

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- 新研究者只靠仓库内文档即可理解 Phase 2 之前的实验基线
- 后续所有 phase 都可以直接引用 examples 与 config_contract，而不必重复解释 Phase 1 契约

---
*Phase: 01-experiment-baseline-config-contract*
*Completed: 2026-04-18*
