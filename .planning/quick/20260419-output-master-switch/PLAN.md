---
status: complete
created: 2026-04-19
slug: output-master-switch
---

# Quick Task: Output Master Switch

## Objective

给主流程和恢复流程增加输出总开关，关闭时不创建输出目录，也不写任何实验产物文件。

## Scope

- `config/default_config.m`
- `src/bp_validate_config.m`
- `src/bp_output_pipeline.m`
- `main_gotha_bp.m`
- `cs_echo_recovery/cs_default_config.m`
- `cs_echo_recovery/cs_recovery_pipeline.m`
- `cs_echo_recovery/cs_save_results.m`

## Execution Plan

1. 为主流程配置增加 `config.output.enableOutput`
2. 在 `bp_output_pipeline` 中统一短路目录创建和所有写盘动作
3. 为恢复流程增加 `csCfg.output.enableOutput`
4. 在恢复结果保存链路上统一短路 summary、case image 和点目标分析产物
5. 用 MATLAB smoke 验证关闭后不建目录、不写文件，且错误类型会在配置阶段直接失败
