---
status: complete
created: 2026-04-19
slug: generic-dataset-contract
---

# Quick Task: Generic Dataset Contract

## Objective

把当前项目从“默认面向 GOTCHA 数据”扩展为“面向任意满足输入契约的数据集”，要求主流程和压缩感知恢复流程都能通过配置接入，且数据格式要求、路径设置和失败语义明确可查。

## Scope

- `config/default_config.m`
- `src/bp_validate_config.m`
- `src/bp_data_pipeline.m`
- `README.md`
- `docs/config_contract.md`
- `docs/data_format_contract.md`
- `examples/run_bp_minimal.m`
- `examples/run_cs_recovery_minimal.m`
- `tests/test_data_pipeline_contract.m`

## Execution Plan

1. 为主流程默认配置增加数据集容器变量名和字段映射契约，默认保持 GOTCHA 行为不变
2. 在数据加载入口增加严格校验，遇到变量缺失、字段缺失、尺寸不一致或频率向量不一致时立即报错并说明原因
3. 补充通用数据格式文档、路径配置说明和主流程/恢复流程最小示例
4. 增加最小自动化测试，验证自定义容器名与字段映射可以正常加载
