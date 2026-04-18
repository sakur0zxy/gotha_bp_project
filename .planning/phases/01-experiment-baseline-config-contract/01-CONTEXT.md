# Phase 1: 实验基线与配置契约 - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

本 phase 只负责把现有 GOTCHA BP MATLAB 工程整理成可复现实验项目的“基线壳层”，即固定数据入口、配置边界、运行入口和基础文档约定。它不新增恢复算法能力、不扩展 GUI、不做 Python 重写，也不进入图像域评估细节本身。

</domain>

<decisions>
## Implementation Decisions

### 配置覆盖与失败语义
- **D-01:** 用户配置覆盖采用严格失败策略。任何未知字段、错拼字段或错误层级都必须立即报错并停止运行。
- **D-02:** 配置错误信息必须同时包含错误位置和错误原因，不能只给模糊的 “invalid config” 类提示。

### 数据集定位
- **D-03:** 数据集定位采用“显式路径优先，约定查找兜底”的规则。
- **D-04:** 当配置中明确提供数据根目录时，运行流程直接使用该目录；只有没有显式路径时，才回退到当前候选目录查找逻辑。

### 默认运行模式
- **D-05:** 正式主流程默认采用 headless 模式，不默认弹出图窗或依赖交互界面。
- **D-06:** notebook 和 demo 入口可以保持交互体验，用于探索、演示或手工查看结果，但不应定义正式实验默认值。

### 入口统一策略
- **D-07:** `main_gotha_bp.m` 是唯一真实入口，正式逻辑只保留在 `.m` 文件中。
- **D-08:** `main_gotha_bp.ipynb`、demo 或辅助脚本只能调用 `main_gotha_bp.m`，不能再复制主实现逻辑。

### 结果产物管理
- **D-09:** `img/`、`results/` 以及大多数 `.mat` / `.jpg` / `.txt` 实验输出默认不纳入版本控制。
- **D-10:** 仓库主要保留代码、文档、配置和极少量必要样例；可复现实验依赖明确的运行约定和元数据，而不是整批提交运行结果。

### the agent's Discretion
- 配置错误的内部实现方式可由后续 planner 决定，例如是在 `bp_merge_config.m` 阶段拦截未知字段，还是引入单独的 schema/allowlist 校验层。
- headless 默认值的具体字段落点可由后续 planner 决定，但必须保证正式主流程默认不依赖 GUI。
- notebook 变成薄包装的具体形式可由后续 planner 决定，例如单 cell 调用、参数示例 cell、或最小实验演示模板。
- 结果产物忽略策略的具体规则可由后续 planner 决定，但必须覆盖 `img/` 与 `cs_echo_recovery/results/`。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目边界与验收目标
- `.planning/PROJECT.md` - 项目目标、核心价值、约束和 v1 范围；锁定“以图像域结果为准”的科研目标
- `.planning/REQUIREMENTS.md` - Phase 1 对应的 `IMG-02`、`QLT-01`、`REP-01` 需求定义
- `.planning/ROADMAP.md` - Phase 1 目标、成功标准和计划分解的来源
- `.planning/STATE.md` - 当前项目位置与本轮讨论前的全局状态

### 现有代码模式与风险
- `.planning/codebase/ARCHITECTURE.md` - 当前函数式流水线结构、入口与模块边界
- `.planning/codebase/CONVENTIONS.md` - MATLAB 文件组织、配置/错误处理和入口风格
- `.planning/codebase/STRUCTURE.md` - 当前目录布局、推荐放置位置和生成产物位置
- `.planning/codebase/CONCERNS.md` - 与本 phase 直接相关的技术债：配置宽松合并、入口重复、结果产物跟踪、数据路径约定

### Phase 1 直接相关的实现文件
- `README.md` - 当前用户文档和运行说明基线，需要在本 phase 中整理
- `config/default_config.m` - 当前默认配置，含交互显示默认值和数据路径候选配置
- `src/bp_merge_config.m` - 当前宽松递归合并实现，是严格失败策略的直接落点之一
- `src/bp_validate_config.m` - 当前配置校验入口，是错误位置与错误原因设计的直接落点之一
- `src/bp_data_pipeline.m` - 当前数据根目录发现逻辑，实现“显式路径优先、约定兜底”时必须修改
- `main_gotha_bp.m` - 正式主入口，应被固定为唯一真实入口
- `main_gotha_bp.ipynb` - 当前含重复主逻辑的 notebook，需要改为薄包装
- `open_vscode_matlab_notebook.cmd` - notebook 启动辅助脚本，后续只应服务于演示/探索入口

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `config/default_config.m`: 已经集中定义了主流程默认参数，是引入显式 `dataRoot` 和 headless 默认值的自然位置
- `src/bp_validate_config.m`: 已经承担主配置契约校验，可以继续作为正式错误出口
- `src/bp_data_pipeline.m`: 已经有路径上下文和候选目录逻辑，可在这里扩展“显式路径优先”
- `src/bp_read_seed_from_run_dir.m`: 已具备随机间断复现辅助能力，后续文档可引用它说明复现实验方法
- `main_gotha_bp.m`: 已经是清晰的主入口编排器，适合被进一步固定为唯一真实入口

### Established Patterns
- 主流程与恢复流程都依赖 `struct` 配置对象，而不是命令行参数或配置文件解析器
- 错误处理主要依赖 `assert(...)` 和显式 `error(...)`，而不是容错式自动修复
- 输出目录由 `src/bp_output_pipeline.m` 和 `cs_echo_recovery/cs_recovery_pipeline.m` 管理，当前已经有“每次运行生成独立目录”的模式
- notebook 和 `.cmd` 只是辅助入口，不应继续定义和维护独立业务逻辑

### Integration Points
- 严格配置覆盖会同时影响 `main_gotha_bp.m` 和 `cs_echo_recovery/run_cs_echo_recovery_demo.m` 的用户配置入口
- 数据路径策略会影响 `config/default_config.m` 与 `src/bp_data_pipeline.m`
- headless 默认策略会影响 `config/default_config.m`、`main_gotha_bp.m` 以及 demo/notebook 调用方式
- 结果产物管理会影响仓库级忽略规则和 README 的运行说明

</code_context>

<specifics>
## Specific Ideas

- 这是科研项目，不是产品化项目；文档和入口设计应优先服务“可复现实验”和“结果可信度”
- 正式实验默认值必须偏向稳定批处理，而不是偏向手工看图
- 配置错误不允许静默失败，否则实验记录会失真
- 运行结果默认不进版本库，但复现实验所需的路径、参数与元数据必须保留和说明清楚

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 01-experiment-baseline-config-contract*
*Context gathered: 2026-04-18*
