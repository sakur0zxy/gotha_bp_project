# GOTCHA BP 间断方位向采样压缩感知恢复实验项目

## What This Is

这是一个面向个人科研工作的 MATLAB 实验项目，目标是在现有 GOTCHA BP 成像工程基础上，把“方位向数据间断条件下的 BP 成像 + 压缩感知恢复缺失信号 + 完整信号成像对比”整理为可复现、可验证、可扩展的实验流程。项目聚焦离线科研实验而不是产品化交付，重点是保证恢复后的成像结果能够与完整数据成像结果进行严肃对比。

## Core Value

在方位向数据间断条件下，压缩感知恢复后的成像结果必须以图像质量为准尽可能接近完整数据 BP 成像结果，尤其是主瓣宽度接近且旁瓣不明显恶化。

## Requirements

### Validated

- ✅ 工程已经能够从 GOTCHA 数据文件加载轨迹、回波与雷达参数，并构造 BP 成像所需的基础输入链路 - existing
- ✅ 工程已经能够生成 `tail_gap` / `random_gap` 方位向间断采样，并执行间断条件下的 BP 成像 - existing
- ✅ 工程已经能够输出成像结果、间断摘要、点目标分析结果与运行目录元数据 - existing

### Active

- [ ] 将现有 GOTCHA BP Matlab 工程整理为可复现的实验项目，形成稳定的输入、配置、输出和复现实验约定
- [ ] 将方位向数据间断条件下的 BP 成像流程作为可信实验基线固定下来
- [ ] 将压缩感知恢复流程与 BP 成像主流程整合为单次可重复运行的对比实验
- [ ] 以成像结果为主要验收依据，建立“主瓣宽度接近完整数据、旁瓣不明显恶化”的恢复效果判据
- [ ] 为配置校验、关键算法链路、恢复流程和结果对比补齐测试与回归检查

### Out of Scope

- GUI 图形界面 - 当前项目是科研实验项目，优先级在算法链路、可复现性和结果质量，不在交互界面
- Python 重写 - 现有 MATLAB 代码和实验资产已具备直接科研价值，当前阶段不为语言迁移分散精力
- 在线服务化 / Web API - 项目目标是本地离线实验与科研验证，而不是面向外部用户的服务部署

## Context

- 当前代码库是 brownfield 项目，已经有 `.planning/codebase/` 映射文档，可直接作为后续计划和执行的上下文基线
- 核心执行链路位于 `main_gotha_bp.m` 与 `src/`，现有能力覆盖数据加载、间断采样、BP 成像、点目标分析和结果输出
- 工作区中已经存在 `cs_echo_recovery/` 压缩感知恢复实验模块雏形，但它仍需要被纳入统一的可复现实验约定、测试与结果判据中
- 数据依赖是外部 GOTCHA `.mat` 文件集合，当前路径发现依赖 `config/default_config.m` 和 `src/bp_data_pipeline.m` 的约定式查找
- 成功判据已明确为图像域优先，而不是只看回波域误差：恢复后图像主瓣宽度应接近完整数据，旁瓣不能明显恶化
- 当前工作树里存在与初始化无关的本地改动和未跟踪文件，初始化过程必须只增量写入项目规划文档，不覆盖实验代码

## Constraints

- **Tech stack**: 保持 MATLAB 为主实现语言 - 现有算法、数据接口和实验流程已经建立在 MATLAB 代码资产之上
- **Data dependency**: 依赖外部 GOTCHA 数据文件布局 - 没有数据文件时无法完成真实实验验证
- **Acceptance**: 恢复效果以成像结果为主判定 - 科研目标强调最终成像质量而不是单纯回波拟合
- **Reproducibility**: 必须保留随机间断与运行输出的可追溯信息 - 需要复现实验、复查参数并支持科研记录
- **Scope discipline**: v1 优先做实验链路收敛，不做 GUI 与 Python 重写 - 避免偏离核心科研目标

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 以 brownfield 整理而不是重写方式推进项目 | 现有 MATLAB 算法实现和实验入口已经具备高价值，不应在 v1 阶段推倒重来 | ⏳ Pending |
| 以图像域质量作为压缩感知恢复的主要验收标准 | 用户明确要求以恢复后成像结果为准，核心指标是主瓣宽度与旁瓣表现 | ⏳ Pending |
| v1 聚焦方位向间断 BP、恢复整合、配置校验、测试和结果对比 | 这些任务共同决定项目能否成为可复现实验项目 | ⏳ Pending |
| GUI 不进入 v1 范围 | 当前阶段不需要界面层，算法和实验可信度优先 | ⏳ Pending |
| Python 重写不进入 v1 范围 | 重写会稀释当前科研目标，并破坏对现有 MATLAB 资产的复用效率 | ⏳ Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check → still the right priority?
3. Audit Out of Scope → reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-18 after initialization*
