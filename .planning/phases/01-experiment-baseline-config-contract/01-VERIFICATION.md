---
status: passed
phase: 01-experiment-baseline-config-contract
updated: 2026-04-18T23:53:00+08:00
requirements_verified: [IMG-02, QLT-01, REP-01]
---

# Phase 1 Verification

## Goal

让研究者在不修改源码的情况下理解数据放置方式、配置边界和运行入口，并在非法配置时获得快速且明确的失败反馈。

## Result

**PASSED**

Phase 1 的三个 success criteria 均已满足：

1. 研究者可以通过配置覆盖调整实验参数，而不需要修改生产源码
2. 非法或不一致的配置会在进入昂贵计算前报错并指出问题位置
3. 仓库文档清楚说明了数据放置方式、入口命令和基础输出内容

## Automated Evidence

### 1. 主流程非法配置 smoke

- Command: `main_gotha_bp(struct('display', struct('showProgess', false)))`
- Result: `bp_merge_config:UnknownField`
- Evidence:
  - 错误路径包含 `cfg.display.showProgess`
  - 错误在 merge 阶段发生，未进入数据加载

### 2. 恢复入口非法配置 smoke

- Command: `run_cs_echo_recovery_demo(struct('methd', struct('run1D', false)))`
- Result: `bp_merge_config:UnknownField`
- Evidence:
  - 错误路径包含 `cfg.methd`
  - 恢复入口已复用共享严格 merge

### 3. 显式 dataRoot 错误路径 smoke

- Command: `main_gotha_bp(struct('path', struct('dataRoot', 'definitely_missing_path')))`
- Result: `bp_data_pipeline:ExplicitDataRootMissing`
- Evidence:
  - 错误消息包含显式路径
  - 错误消息包含缺失文件名 `data_3dsar_pass1_az001_VV.mat`
  - 明确说明不会回退到 `cfg.path.dataRootCandidates`

### 4. 主流程默认兜底路径 smoke

- Command: `main_gotha_bp()`
- Result: success
- Evidence:
  - 默认候选目录查找仍然可用
  - 运行目录与成像图成功生成

### 5. headless 点目标分析图片导出 smoke

- Command: `bp_output_pipeline('save_point_analysis', ...)` with `showFigures=false` and `savePointAnalysisImage=true`
- Result: success
- Evidence:
  - `point_analysis_upslice.jpg` exists
  - `point_analysis_contour.jpg` exists
  - `point_analysis_range_profile.jpg` exists
  - `point_analysis_azimuth_profile.jpg` exists

### 6. 恢复入口轻量主链路 smoke

- Command: `run_cs_echo_recovery_demo(csCfg)` with explicit `dataRoot`, cropped data, `run1D=false`, `run2D=false`
- Result: success
- Evidence:
  - 恢复入口可以合法接受 `csCfg.project.path.dataRoot`
  - 运行目录成功生成于 `cs_echo_recovery/results/`

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| IMG-02 | PASSED | 严格 merge + examples + README 已固定“通过覆盖 struct 调参”工作流 |
| QLT-01 | PASSED | 主流程/恢复入口非法字段、错路径 smoke 均已 fail-fast |
| REP-01 | PASSED | README + examples + docs/config_contract.md 已覆盖数据、入口、输出与错误语义 |

## Must-Haves Check

| Must-have | Status | Evidence |
|-----------|--------|----------|
| 主流程未知字段和错层级在数据加载前失败 | PASSED | `bp_merge_config:UnknownField` smoke |
| 恢复入口使用共享严格 merge | PASSED | `run_cs_echo_recovery_demo` 非法配置 smoke |
| 错误信息包含完整字段路径和原因 | PASSED | `cfg.display.showProgess`、`cfg.methd`、显式 `dataRoot` 错误消息 |
| 正式主流程支持显式 `dataRoot`，未提供时兜底 | PASSED | explicit path failure + default run success |
| 主流程默认 headless 且仍可导出分析图片 | PASSED | fake point-analysis export smoke |
| notebook 只作 wrapper | PASSED | notebook JSON 中仅保留 `result = main_gotha_bp(userCfg);` 调用 |
| 研究者只靠仓库内文档即可了解使用方式 | PASSED | README + examples + config contract docs |

## Human Verification

None required for Phase 1.

## Gaps Found

None.

## Conclusion

Phase 1 已达到执行目标，可以进入 Phase 2：间断 BP 成像基线。
