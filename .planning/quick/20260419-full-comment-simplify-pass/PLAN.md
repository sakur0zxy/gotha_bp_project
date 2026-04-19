---
status: complete
created: 2026-04-19
slug: full-comment-simplify-pass
---

# Quick Task: Full Comment Simplify Pass

## Objective

继续为 `src/` 深层成像与间断链路补充必要注释，并对整个项目的文档与代码注释做一次全量精简：删掉重复解释、口语化废话和同义反复，保留新手仍能快速理解所需的最小信息量。

## Scope

- `src/*.m`
- `src/point_analysis_algorithm.md`
- `config/default_config.m`
- `cs_echo_recovery/*.m`
- `*.md`
- `examples/*.m`
- `tests/*.m`
- `main_gotha_bp.m`
- `AGENTS.md` 仅巡检，不改 workflow 规则

## Execution Plan

1. 盘点项目内所有源码与文档文件，锁定注释密度高且容易歧义的文件
2. 为 `src/` 成像、间断、输出和点目标分析链路补齐必要参数/阶段注释
3. 统一压缩全项目文档和注释表述，确保更短、更准、不丢关键信息
4. 做一次全项目巡检和 MATLAB 轻量校验
