# Phase 1: 实验基线与配置契约 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-04-18T21:37:45+08:00
**Phase:** 01-experiment-baseline-config-contract
**Areas discussed:** 配置覆盖严格度, 数据集定位方式, 运行模式默认值, 入口统一策略, 结果产物管理

---

## 配置覆盖严格度

| Option | Description | Selected |
|--------|-------------|----------|
| 1. 立即报错并停止运行 | 任何未知字段、错拼字段、错误层级都直接失败 | |
| 2. 给 warning，但继续运行 | 提示有无效字段，但已识别部分继续执行 | |
| 3. 主流程严格，实验流程宽松 | `main_gotha_bp` 严格，`cs_echo_recovery` 暂时允许更灵活的实验覆盖 | |
| 4. 其他 | 用户自定义规则 | X |

**User's choice:** 4. 立即报错并停止运行，给出错误位置和错误原因  
**Notes:** 用户没有接受默认“其他即自定义”的宽泛含义，而是明确把规则锁成“严格失败 + 明确定位 + 明确原因”。因此后续不得退化成仅 warning 或仅通用错误文本。

---

## 数据集定位方式

| Option | Description | Selected |
|--------|-------------|----------|
| 1. 显式路径优先，约定查找兜底 | 支持配置里明确指定数据根目录；未指定时回退到当前候选目录逻辑 | X |
| 2. 只允许显式路径 | 必须显式配置数据根目录，不再做约定式查找 | |
| 3. 保持当前约定式查找 | 继续只靠候选目录自动查找 | |
| 4. 其他 | 用户自定义规则 | |

**User's choice:** 1. 显式路径优先，约定查找兜底  
**Notes:** 这意味着项目既要支持严格可控的显式路径，也要保留对当前个人工作流友好的兼容回退。

---

## 运行模式默认值

| Option | Description | Selected |
|--------|-------------|----------|
| 1. 默认 headless，显示全关 | 默认不弹图、不依赖交互窗口 | |
| 2. 默认保持现在的交互模式 | 继续默认弹图和显示进度 | |
| 3. 主流程默认 headless，notebook / demo 保持交互 | 正式实验入口默认无界面，演示入口保留可视化体验 | X |
| 4. 其他 | 用户自定义规则 | |

**User's choice:** 3. 主流程默认 headless，notebook / demo 保持交互  
**Notes:** 这是 Phase 1 的关键分层决策：正式实验入口与演示/探索入口要分开处理，不能共享同一套默认交互值。

---

## 入口统一策略

| Option | Description | Selected |
|--------|-------------|----------|
| 1. `main_gotha_bp.m` 作为唯一真实入口 | 正式逻辑只保留在 `.m` 文件里，notebook / demo 只调用它 | X |
| 2. 主入口拆成“库函数 + 薄入口” | 再下沉一层统一 runner，所有入口都只是薄封装 | |
| 3. 保持双入口并行维护 | 允许 `.m` 和 `ipynb` 各自维护一份实现 | |
| 4. 其他 | 用户自定义规则 | |

**User's choice:** 1. `main_gotha_bp.m` 作为唯一真实入口  
**Notes:** notebook 复制主逻辑的现状已经被否决，后续 planner 必须把 `ipynb` 视为调用者，而不是实现持有者。

---

## 结果产物管理

| Option | Description | Selected |
|--------|-------------|----------|
| 1. 运行产物默认不纳入版本控制 | `img/`、`results/`、大部分 `.mat/.jpg/.txt` 输出默认忽略 | X |
| 2. 主流程产物忽略，恢复实验产物保留 | `img/` 忽略，但 `cs_echo_recovery/results/` 暂时保留 | |
| 3. 全部保留在仓库中 | 继续允许实验结果进入版本控制 | |
| 4. 其他 | 用户自定义规则 | |

**User's choice:** 1. 运行产物默认不纳入版本控制  
**Notes:** 用户明确接受“可复现实验依赖规则和元数据，而不是提交整批产物”的方向，这会直接影响忽略规则、README 和后续目录约定。

---

## the agent's Discretion

- 具体采用 allowlist schema、递归路径跟踪还是分层 validator 来实现“错误位置 + 错误原因”，由后续 planning 决定
- headless 默认值的具体字段落位和 demo/notebook 的覆盖方式由后续 planning 决定
- 结果产物忽略规则的具体 pattern 由后续 planning 决定

## Deferred Ideas

None
