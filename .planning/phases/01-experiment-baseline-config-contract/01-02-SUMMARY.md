---
phase: 01-experiment-baseline-config-contract
plan: 02
subsystem: infra
tags: [matlab, data-path, headless, notebook, output]
requires: []
provides:
  - "显式 dataRoot 优先、候选目录兜底的数据路径规则"
  - "主流程 headless 默认值"
  - "point-analysis 图片导出与 showFigures 解耦"
  - "notebook 薄包装与运行产物忽略规则"
affects: [phase-02, phase-03, phase-05]
tech-stack:
  added: []
  patterns:
    - "显式路径优先，候选目录兜底"
    - "headless 默认不等于禁止保存图片"
key-files:
  created:
    - .gitignore
  modified:
    - config/default_config.m
    - src/bp_validate_config.m
    - src/bp_data_pipeline.m
    - src/bp_output_pipeline.m
    - cs_echo_recovery/cs_default_config.m
    - main_gotha_bp.ipynb
key-decisions:
  - "dataRoot 显式路径一旦给出就不再回退候选目录"
  - "showFigures 只控制交互显示，不再控制点目标分析图片是否保存"
patterns-established:
  - "Pattern: cfg.path.dataRoot 作为正式实验首选路径"
  - "Pattern: notebook 只负责调用 main_gotha_bp.m"
requirements-completed: [IMG-02, REP-01]
duration: 55min
completed: 2026-04-18
---

# Phase 1: 实验基线与配置契约 Summary

**显式数据路径、headless 默认、独立图片导出和 notebook 薄包装一起把正式实验入口固定下来**

## Performance

- **Duration:** 55 min
- **Started:** 2026-04-18T22:33:00+08:00
- **Completed:** 2026-04-18T23:28:00+08:00
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments
- 新增 `cfg.path.dataRoot`，并把数据加载规则改成显式路径优先、候选目录兜底
- 主流程默认改为 headless，同时点目标分析图片保存不再依赖 `showFigures=true`
- `main_gotha_bp.ipynb` 收口为 wrapper，`.gitignore` 开始忽略运行产物

## Task Commits

本次在手工 fallback 执行模式下使用共享实现提交，而不是每个 task 单独提交。

1. **Task 1: 显式 dataRoot 与路径优先级** - `13d4fb6` (shared phase code commit)
2. **Task 2: headless 默认值与图片导出解耦** - `13d4fb6` (shared phase code commit)
3. **Task 3: notebook 薄包装与运行产物忽略规则** - `13d4fb6` (shared phase code commit)

**Plan metadata:** captured in the phase completion docs commit

## Files Created/Modified
- `config/default_config.m` - 新增 `path.dataRoot`，主流程默认 headless
- `src/bp_validate_config.m` - 校验 `cfg.path.dataRoot`
- `src/bp_data_pipeline.m` - 实现显式路径优先与稳定错误标识
- `src/bp_output_pipeline.m` - 图片保存与 `showFigures` 解耦
- `cs_echo_recovery/cs_default_config.m` - 恢复入口的 `project` 改为完整主流程 schema
- `main_gotha_bp.ipynb` - 从第二套实现收口为 wrapper
- `.gitignore` - 忽略 `img/` 与 `cs_echo_recovery/results/`

## Decisions Made
- 将 `cs_default_config().project` 改成 `default_config()` 作为 schema，保证 `csCfg.project.path.dataRoot` 之类的合法覆盖不会被严格 merge 错杀
- 保留 notebook 的 MATLAB kernel 元数据，仅替换重复主流程实现

## Deviations from Plan

### Auto-fixed Issues

**1. 恢复入口的 `project` 初始 schema 过空，导致合法覆盖被严格 merge 拒绝**
- **Found during:** 恢复入口 smoke test
- **Issue:** `cs_default_config().project` 原本是空 struct，`csCfg.project.path.dataRoot` 会被当作未知字段
- **Fix:** 将 `cfg.project` 改为 `default_config()`，让恢复入口的 project 覆盖复用完整主流程 schema
- **Files modified:** `cs_echo_recovery/cs_default_config.m`
- **Verification:** `run_cs_echo_recovery_demo` 在显式 `dataRoot` 与裁剪数据配置下成功完成 smoke run
- **Committed in:** `13d4fb6`

---

**Total deviations:** 1 auto-fixed
**Impact on plan:** 这是必要修复，避免严格 merge 与恢复入口的合法配置用法冲突。

## Issues Encountered
- 使用常量矩阵做 `bp_output_pipeline('save_point_analysis', ...)` 假数据验证时，MATLAB `contour` 会给出常量等高线警告，但图片仍能正常导出，不影响解耦验证结论。

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 2 可以直接假设数据路径与默认运行模式已经固定
- notebook 与正式入口不再漂移，后续只需维护 `.m` 代码路径

---
*Phase: 01-experiment-baseline-config-contract*
*Completed: 2026-04-18*
