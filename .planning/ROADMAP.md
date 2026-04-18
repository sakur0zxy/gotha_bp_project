# Roadmap: GOTCHA BP 间断方位向采样压缩感知恢复实验项目

## Overview

本路线图从现有 brownfield MATLAB 工程出发，不做推倒重写，而是把已经存在的数据加载、间断采样、BP 成像、点目标分析和压缩感知恢复雏形收敛为一个可复现的科研实验项目。v1 的推进顺序遵循“先把输入和配置边界收紧，再固定间断 BP 基线，再整合恢复链路，最后用图像域评估和自动化回归把结果钉牢”的原则。

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: 实验基线与配置契约** - 固化数据入口、配置边界和基础运行说明
- [ ] **Phase 2: 间断 BP 成像基线** - 稳定方位向间断条件下的 BP 成像与可追溯输出
- [ ] **Phase 3: 压缩感知恢复链路** - 将恢复算法整理进统一实验入口并保证观测样本约束
- [ ] **Phase 4: 图像域评估与结果对比** - 以完整数据成像为基线建立恢复效果判据和对比产物
- [ ] **Phase 5: 自动化验证与回归** - 用测试和缩小规模回归用例封装 v1 可复现实验

## Phase Details

### Phase 1: 实验基线与配置契约
**Goal**: 让研究者在不修改源码的情况下理解数据放置方式、配置边界和运行入口，并在非法配置时获得快速且明确的失败反馈。
**Depends on**: Nothing (first phase)
**Requirements**: IMG-02, QLT-01, REP-01
**Success Criteria** (what must be TRUE):
1. 研究者可以通过配置覆盖调整间断实验参数，而不需要直接修改生产源码
2. 非法或不一致的配置会在进入昂贵计算前报错并指出问题位置
3. 仓库文档清楚说明数据放置方式、入口命令和基础输出内容
**Plans**: 3 plans

Plans:
- [x] 01-01: 收紧主流程与恢复流程的配置模型，明确允许覆盖的字段和失败语义
- [x] 01-02: 规范数据路径发现、运行入口和输出目录约定
- [x] 01-03: 补齐基线实验说明文档与最小运行示例

### Phase 2: 间断 BP 成像基线
**Goal**: 把方位向间断条件下的 BP 成像固定为可信、可追溯、可复现的实验基线。
**Depends on**: Phase 1
**Requirements**: IMG-01, IMG-03, REP-02
**Success Criteria** (what must be TRUE):
1. 研究者可以从统一入口运行间断条件下的 GOTCHA BP 成像
2. 每次运行都生成独立输出目录，保存成像结果、间断摘要和关键运行元数据
3. `random_gap` 运行可以根据保存下来的元数据复现实验
**Plans**: 3 plans

Plans:
- [ ] 02-01: 固化间断 BP 成像入口、配置传递和运行目录结构
- [ ] 02-02: 强化 `cutInfo`、随机种子和输出元数据的可追溯性
- [ ] 02-03: 建立间断 BP 基线结果的人工验收清单

### Phase 3: 压缩感知恢复链路
**Goal**: 将压缩感知恢复整理为统一实验链路的一部分，并保证恢复输出满足后续完整信号成像需要。
**Depends on**: Phase 2
**Requirements**: RCV-01, RCV-02
**Success Criteria** (what must be TRUE):
1. 研究者可以从统一恢复入口运行压缩感知恢复，而不需要临时拼接脚本
2. 恢复后的完整回波保留真实观测样本，不覆盖原始已观测数据
3. 恢复输出可以直接进入后续 BP 成像与比较流程
**Plans**: 3 plans

Plans:
- [ ] 03-01: 统一恢复模块配置、case 组织和共享主流程接口
- [ ] 03-02: 明确恢复后回波的数据契约与观测样本保真约束
- [ ] 03-03: 打通恢复到完整信号成像的主链路

### Phase 4: 图像域评估与结果对比
**Goal**: 用完整数据成像作为基线，建立恢复效果的图像域判据和标准化对比产物。
**Depends on**: Phase 3
**Requirements**: RCV-03, EVL-01, EVL-02, EVL-03, EVL-04, EVL-05
**Success Criteria** (what must be TRUE):
1. 单次实验可以同时得到 `original`、`interrupted` 和 `recovered` 的成像对比结果
2. 输出摘要能够明确回答“主瓣宽度是否接近完整数据、旁瓣是否明显恶化”
3. 点目标分析结果、图像对比图和核心指标可以直接用于科研记录
**Plans**: 3 plans

Plans:
- [ ] 04-01: 建立完整/间断/恢复三类 case 的统一对比结构
- [ ] 04-02: 收敛点目标分析和图像域比较指标的输出格式
- [ ] 04-03: 明确恢复效果的验收摘要与科研记录产物

### Phase 5: 自动化验证与回归
**Goal**: 用自动化测试和缩小规模的回归用例守住 v1 实验链路，减少后续改动造成的隐性退化。
**Depends on**: Phase 4
**Requirements**: QLT-02, QLT-03
**Success Criteria** (what must be TRUE):
1. 开发者可以运行自动化检查来验证配置校验、间断逻辑、随机种子复现和关键 smoke path
2. 开发者可以在不修改生产源码的前提下运行缩小规模的恢复与对比回归用例
3. v1 主链路出现退化时，回归检查能够尽早暴露问题
**Plans**: 2 plans

Plans:
- [ ] 05-01: 增加配置校验、间断布局和种子复现的自动化测试
- [ ] 05-02: 增加可快速运行的恢复与对比回归用例

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. 实验基线与配置契约 | 3/3 | Complete | 2026-04-18 |
| 2. 间断 BP 成像基线 | 0/3 | Not started | - |
| 3. 压缩感知恢复链路 | 0/3 | Not started | - |
| 4. 图像域评估与结果对比 | 0/3 | Not started | - |
| 5. 自动化验证与回归 | 0/2 | Not started | - |
