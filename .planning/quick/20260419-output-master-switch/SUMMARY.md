---
status: complete
completed: 2026-04-19
slug: output-master-switch
---

# Quick Task Summary

## Outcome

为主流程和压缩感知恢复流程都增加了输出总开关，并验证关闭后不会创建输出目录或写出任何结果文件。

## Changes

- 主流程新增 `config.output.enableOutput`
- 恢复流程新增 `csCfg.output.enableOutput`
- `bp_output_pipeline` 在关闭时直接返回空输出，不再创建 run dir 或写图像、文本、MAT 文件
- `main_gotha_bp.m` 在关闭输出时不再打印输出路径和成像文件路径
- `cs_save_results.m` 在关闭输出时直接返回空文件清单，不再写 summary、case image 或点目标分析文件
- `cs_recovery_pipeline.m` 对恢复流程输出开关增加显式校验，并避免在关闭时创建结果目录

## Verification

- MATLAB smoke 通过：
  - `bp_validate_config` 会拒绝非逻辑的 `cfg.output.enableOutput`
  - `cs_recovery_pipeline` 会拒绝非逻辑的 `csCfg.output.enableOutput`
  - 关闭主流程输出后 `bp_output_pipeline` 不建目录、不写文件
  - 关闭恢复流程输出后 `cs_save_results` 不建目录、不写文件

## Notes

- 此次改动只控制文件/目录产物，不改变函数返回值和算法计算过程
- 交互显示仍由现有 `display.*`、`showFigures`、`recovery.verbose` 等配置单独控制
