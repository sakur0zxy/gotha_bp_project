---
status: complete
completed: 2026-04-19
slug: doc-onboarding-polish
---

# Quick Task Summary

## Outcome

项目的文档入口和关键注释已经重写为更适合新人的形式。现在 README 更像首页导航，新增了第一次运行指南，并把配置修改与自定义数据集接入分别拆成独立文档；同时把 `default_config.m`、`cs_default_config.m` 和恢复算法入口里的关键参数都补上了“这个参数是做什么的”说明，恢复模块 README 里的旧路径示例和旧 GOTCHA-only 口径也一并修正。

## Changes

- 重写 `README.md`，把它调整为新人入口导航页
- 新增 `docs/getting_started.md`，提供第一次运行的分步说明
- 重写 `docs/config_contract.md`，按“我要做什么”解释配置覆盖规则
- 重写 `docs/data_format_contract.md`，按接入步骤说明自定义数据集格式要求
- 优化 `config/default_config.m`、`main_gotha_bp.m`、`src/bp_data_pipeline.m`、`cs_echo_recovery/cs_default_config.m`、`cs_echo_recovery/run_cs_echo_recovery_demo.m` 的解释性注释
- 为 `config/default_config.m` 和 `cs_echo_recovery/cs_default_config.m` 中的关键实验参数补充逐项说明
- 为 `cs_echo_recovery/cs_recover_azimuth_fft_ista.m`、`cs_echo_recovery/cs_recover_echo_fft2_ista.m`、`cs_echo_recovery/cs_recovery_pipeline.m`、`cs_echo_recovery/cs_save_results.m` 补充恢复流程参数和阶段说明
- 重写 `cs_echo_recovery/README.md`，修正旧 `addpath('gotha_bp_project')` 示例、变量名不一致和过时表述
- 优化 `examples/run_bp_minimal.m` 和 `examples/run_cs_recovery_minimal.m` 的步骤说明注释
- 修正 `docs/getting_started.md` 中遗漏的 `bp_data_pipeline:AzimuthTrackMismatch` 报错说明，并明确默认值以配置文件注释为准

## Verification

- MATLAB batch 轻量 smoke 通过：
  - `cfg = default_config(); bp_validate_config(cfg);`
  - `csCfg = cs_default_config(); assert(isstruct(csCfg.project));`
- 结果输出：`doc-comment-smoke-ok`

## Notes

- 本次修改没有改变算法逻辑，只增强了文档结构和解释性注释
- 新人第一次进入项目时，推荐先读 `docs/getting_started.md`，再运行 `examples/*.m`
