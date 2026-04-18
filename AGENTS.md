<!-- GSD:project-start source:PROJECT.md -->
## Project

本项目是一个面向个人科研工作的 MATLAB brownfield 实验项目，目标是把现有 GOTCHA BP 成像工程整理为可复现、可验证、可扩展的实验流程。核心问题是：在方位向数据间断条件下，经过压缩感知恢复后的成像结果能否在图像域上尽可能接近完整数据 BP 成像结果。

当前 v1 聚焦五件事：
- 固化数据入口、配置校验和输出约定
- 稳定间断方位向条件下的 BP 成像基线
- 整合压缩感知恢复与完整信号成像链路
- 用图像域指标和点目标分析判断恢复质量
- 为关键链路补齐自动化测试和缩小规模回归

明确不做：
- GUI 图形界面
- Python 重写
- 在线服务化 / Web API
<!-- GSD:project-end -->

<!-- GSD:stack-start source:STACK.md -->
## Technology Stack

- 主语言是 MATLAB，核心入口是 `main_gotha_bp.m`，核心算法位于 `src/`
- 外部数据依赖是 GOTCHA `.mat` 文件，路径发现逻辑在 `config/default_config.m` 和 `src/bp_data_pipeline.m`
- 压缩感知恢复实验模块位于 `cs_echo_recovery/`
- 无包管理器、无构建系统、无服务端运行时
- 可选 notebook 路径存在于 `main_gotha_bp.ipynb` 和 `open_vscode_matlab_notebook.cmd`

详细栈信息见 `.planning/codebase/STACK.md`。
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

- 一个 `.m` 文件只暴露一个顶层公共函数，文件名与函数名一致
- 公共函数名采用 lower snake case，主流程多用 `bp_` / `cs_` / `main_` / `run_` 前缀
- 私有 helper 使用 `local*` lowerCamelCase
- 主要数据模型是嵌套 `struct`，不要引入 `classdef` 或复杂对象层
- 优先用 `assert(...)`、显式 `error(...)` 和 `warning(...)` 保持失败语义清晰
- 注释和用户可见说明以中文为主，标识符保持 MATLAB 代码当前风格

详细规范见 `.planning/codebase/CONVENTIONS.md`。
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

当前架构是函数式流水线：
- 入口与编排：`main_gotha_bp.m`、`cs_echo_recovery/run_cs_echo_recovery_demo.m`
- 配置与校验：`config/default_config.m`、`src/bp_merge_config.m`、`src/bp_validate_config.m`
- 数据与间断采样：`src/bp_data_pipeline.m`、`src/bp_interruption_pipeline.m`
- 成像与恢复计算：`src/bp_imaging_pipeline.m`、`cs_echo_recovery/cs_recover_*.m`
- 分析与输出：`src/bp_run_point_analysis.m`、`src/point_analysis.m`、`src/bp_output_pipeline.m`

跨模块状态通过 `config`、`track`、`radar`、`cutInfo`、`result` 等 `struct` 传递。修改时优先延续这些契约，而不是新造并行接口。

详细架构说明见 `.planning/codebase/ARCHITECTURE.md`。
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `$gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `$gsd-debug` for investigation and bug fixing
- `$gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `$gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` - do not edit manually.
<!-- GSD:profile-end -->
