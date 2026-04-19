---
status: complete
completed: 2026-04-19
slug: generic-dataset-contract
---

# Quick Task Summary

## Outcome

项目的数据入口已经从“默认 GOTCHA 命名”扩展为“任意满足契约的数据集”。主流程与压缩感知恢复流程都可以通过配置指定数据根目录、文件模式、顶层变量名和字段映射，并在数据入口对容器缺失、字段缺失、尺寸不一致和频率向量不一致进行立即失败校验。

## Changes

- 在 `config/default_config.m` 中新增 `config.general.dataVariableName` 和 `config.general.dataFieldMap`
- 在 `src/bp_validate_config.m` 中为数据文件模式、顶层变量名和字段映射增加严格校验
- 在 `src/bp_data_pipeline.m` 中把数据加载逻辑改为配置驱动，并补充清晰的错误标识与原因说明
- 新增 `docs/data_format_contract.md`，明确数据格式、尺寸要求、路径规则和常见错误
- 更新 `README.md`、`docs/config_contract.md` 和最小示例，说明如何接入非 GOTCHA 数据集
- 新增 `tests/test_data_pipeline_contract.m`，覆盖自定义容器名/字段映射的成功路径与失败路径

## Verification

- MATLAB batch 通过：
  - `addpath('config'); addpath('src'); cfg = default_config(); bp_validate_config(cfg);`
  - `results = runtests('tests/test_data_pipeline_contract.m'); assert(all([results.Passed]), 'Tests failed.');`
- 自动化测试验证了：
  - 自定义容器变量名和字段映射可以正确加载
  - 缺少映射字段时会以 `bp_data_pipeline:MissingDatasetFields` 立即失败

## Notes

- 默认 GOTCHA 行为保持不变；不覆盖新字段时仍按原始 GOTCHA 契约加载
- 恢复流程通过 `csCfg.project.general` 复用同一份数据契约，不额外维护并行入口
