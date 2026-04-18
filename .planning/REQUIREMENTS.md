# Requirements: GOTCHA BP 间断方位向采样压缩感知恢复实验项目

**Defined:** 2026-04-18
**Core Value:** 在方位向数据间断条件下，压缩感知恢复后的成像结果必须以图像质量为准尽可能接近完整数据 BP 成像结果，尤其是主瓣宽度接近且旁瓣不明显恶化。

## v1 Requirements

### Baseline Imaging

- [ ] **IMG-01**: 研究者可以从统一的 MATLAB 入口运行方位向数据间断条件下的 GOTCHA BP 成像流程
- [x] **IMG-02**: 研究者可以通过配置覆盖设置间断模式、分段数、缺失率、间断长度约束和随机种子，而不需要修改生产源码
- [ ] **IMG-03**: 每次基线成像运行都会生成独立输出目录，并保存间断摘要、成像结果和关键运行元数据

### Recovery

- [ ] **RCV-01**: 研究者可以从统一的恢复入口对间断回波执行压缩感知恢复，并产出可用于完整信号成像的恢复后回波
- [ ] **RCV-02**: 恢复流程在重建缺失方位向样本时保留观测到的真实样本，不覆盖已观测数据
- [ ] **RCV-03**: 单次实验运行可以同时产出 `original`、`interrupted` 和 `recovered` 条件下的对比结果

### Evaluation

- [ ] **EVL-01**: 恢复效果以完整数据 BP 成像结果为基线，在图像域而不是仅在回波域进行主比较
- [ ] **EVL-02**: 系统可以为完整、间断和恢复后的成像结果执行点目标分析并保存分析产物
- [ ] **EVL-03**: 系统可以明确判断恢复后图像主瓣宽度是否接近完整数据基线
- [ ] **EVL-04**: 系统可以明确判断恢复后图像旁瓣是否相对完整数据基线出现明显恶化
- [ ] **EVL-05**: 系统可以导出用于科研记录的核心比较图和摘要指标

### Quality Assurance

- [x] **QLT-01**: 非法或不一致的配置在进入昂贵计算前就会被校验并报错
- [ ] **QLT-02**: 开发者可以运行自动化检查来覆盖配置校验、间断布局逻辑、随机种子复现和关键链路 smoke path
- [ ] **QLT-03**: 开发者可以在不修改生产源码的前提下运行缩小数据规模的恢复与对比回归用例

### Reproducibility

- [x] **REP-01**: 研究者只依赖仓库内文档即可了解数据放置方式、运行命令和预期输出
- [ ] **REP-02**: 保存的运行目录和元数据足以复现一次 `random_gap` 实验

## v2 Requirements

### Recovery Extensions

- **RCV-04**: 研究者可以在同一框架下比较多种压缩感知恢复策略，而不止当前的单一流程
- **RCV-05**: 研究者可以批量扫描恢复超参数并输出可比较的实验汇总

### Performance

- **PERF-01**: 研究者可以对 BP 成像或恢复阶段启用更高性能实现，例如 GPU、并行或 MEX 热点优化

## Out of Scope

| Feature | Reason |
|---------|--------|
| GUI 图形界面 | v1 聚焦算法链路、结果可信度和实验可复现性，不引入界面工作量 |
| Python 重写 | 当前阶段优先复用已有 MATLAB 资产，而不是迁移语言 |
| 在线服务化 / Web API | 项目定位为本地科研实验，不是服务化产品 |
| 与 GOTCHA 无关的通用化产品平台 | v1 先把当前科研问题做扎实，不扩展到无关场景 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| IMG-01 | Phase 2 | Pending |
| IMG-02 | Phase 1 | Complete |
| IMG-03 | Phase 2 | Pending |
| RCV-01 | Phase 3 | Pending |
| RCV-02 | Phase 3 | Pending |
| RCV-03 | Phase 4 | Pending |
| EVL-01 | Phase 4 | Pending |
| EVL-02 | Phase 4 | Pending |
| EVL-03 | Phase 4 | Pending |
| EVL-04 | Phase 4 | Pending |
| EVL-05 | Phase 4 | Pending |
| QLT-01 | Phase 1 | Complete |
| QLT-02 | Phase 5 | Pending |
| QLT-03 | Phase 5 | Pending |
| REP-01 | Phase 1 | Complete |
| REP-02 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 (all mapped)

---
*Requirements defined: 2026-04-18*
*Last updated: 2026-04-18 after Phase 1 completion*
