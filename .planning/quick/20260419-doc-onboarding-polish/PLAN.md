---
status: complete
created: 2026-04-19
slug: doc-onboarding-polish
---

# Quick Task: Doc Onboarding Polish

## Objective

把项目的注释和文档说明优化到“没接触过该项目的人也能立刻上手”的程度，重点提升 README、首次运行说明、配置解释和关键入口函数注释的可读性。

## Scope

- `README.md`
- `docs/getting_started.md`
- `docs/config_contract.md`
- `docs/data_format_contract.md`
- `config/default_config.m`
- `main_gotha_bp.m`
- `src/bp_data_pipeline.m`
- `cs_echo_recovery/cs_default_config.m`
- `cs_echo_recovery/run_cs_echo_recovery_demo.m`
- `examples/run_bp_minimal.m`
- `examples/run_cs_recovery_minimal.m`

## Execution Plan

1. 把 README 改成新手入口导航，明确先读什么、先跑什么、遇到什么问题看哪里
2. 新增面向第一次运行的详细上手文档，分别覆盖 GOTCHA 默认路径和自定义数据集路径
3. 重写配置契约和数据契约文档，让它们按任务场景讲解而不是只列规则
4. 优化主入口、恢复入口和默认配置中的解释性注释，帮助新读者快速建立流程心智模型
