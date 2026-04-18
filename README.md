# GOTCHA BP 间断采样与压缩感知恢复实验项目

本项目用于把现有 GOTCHA BP MATLAB 工程整理成一个可复现、可验证的科研实验项目。v1 重点不是重写算法，而是把已有的方位向间断 BP 成像和压缩感知恢复流程收敛成稳定的实验基线。

当前正式目标：

- 在方位向数据间断条件下稳定运行 GOTCHA BP 成像
- 通过配置覆盖控制实验参数，而不是修改生产源码
- 将压缩感知恢复流程整理进统一入口
- 以图像域结果作为恢复效果的主要判断依据
- 让主瓣宽度尽量接近完整数据，旁瓣不明显恶化

当前明确不做：

- GUI 图形界面
- Python 重写
- 在线服务化 / Web API

## 正式入口

- 主流程入口：`main_gotha_bp.m`
- 恢复流程入口：`cs_echo_recovery/run_cs_echo_recovery_demo.m`
- 随机间断种子复用工具：`src/bp_read_seed_from_run_dir.m`
- notebook：`main_gotha_bp.ipynb`
  说明：只作为交互式 wrapper 调用 `main_gotha_bp.m`，不再持有第二套主流程实现。

## 项目结构

```text
gotha_bp_project/
├─ config/
│  └─ default_config.m
├─ src/
│  ├─ bp_data_pipeline.m
│  ├─ bp_imaging_pipeline.m
│  ├─ bp_interruption_pipeline.m
│  ├─ bp_merge_config.m
│  ├─ bp_output_pipeline.m
│  ├─ bp_read_seed_from_run_dir.m
│  ├─ bp_run_point_analysis.m
│  ├─ bp_validate_config.m
│  ├─ point_analysis.m
│  └─ point_analysis_algorithm.md
├─ cs_echo_recovery/
│  ├─ run_cs_echo_recovery_demo.m
│  ├─ cs_default_config.m
│  ├─ cs_recovery_pipeline.m
│  ├─ cs_recover_azimuth_fft_ista.m
│  ├─ cs_recover_echo_fft2_ista.m
│  ├─ cs_build_full_cutinfo.m
│  ├─ cs_save_results.m
│  └─ README.md
├─ docs/
│  └─ config_contract.md
├─ examples/
│  ├─ run_bp_minimal.m
│  └─ run_cs_recovery_minimal.m
├─ main_gotha_bp.m
└─ main_gotha_bp.ipynb
```

## 数据放置方式

推荐方式是显式指定数据根目录。主流程现在支持：

1. `cfg.path.dataRoot`
   说明：首选方式。显式指定 GOTCHA 数据根目录，最适合正式实验复现。
2. `cfg.path.dataRootCandidates`
   说明：只有 `cfg.path.dataRoot` 为空时才会启用的兜底查找逻辑。

默认兜底候选目录是工作区根目录下的：

- `.`
- `gotcha_BP`

注意：

- 这些路径是相对工作区根目录解析，不是相对 `gotha_bp_project/` 目录。
- 如果设置了显式 `cfg.path.dataRoot`，程序不会再回退到 `dataRootCandidates`。
- 如果显式路径错误，会立即报错并指出缺失文件和错误位置。

## 配置契约

默认配置在 [config/default_config.m](/E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project/config/default_config.m)。

主流程和恢复流程都采用严格配置覆盖语义：

- 未知字段立即报错
- 错拼字段立即报错
- 错误层级立即报错
- 错误信息必须包含完整字段路径和错误原因

例如：

- 合法：`cfg.display.showProgress = true`
- 非法：`cfg.display.showProgess = true`

更完整的配置说明见 [docs/config_contract.md](/E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project/docs/config_contract.md)。

## 快速开始

### 1. 主流程最小示例

推荐直接参考 [examples/run_bp_minimal.m](/E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project/examples/run_bp_minimal.m)。

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);

userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/gotcha_BP');

result = main_gotha_bp(userCfg);
```

### 2. 恢复流程最小示例

推荐直接参考 [examples/run_cs_recovery_minimal.m](/E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project/examples/run_cs_recovery_minimal.m)。

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);
addpath(fullfile(projectRoot, 'cs_echo_recovery'));

csCfg = struct();
csCfg.project = struct('path', struct('dataRoot', 'E:/path/to/gotcha_BP'));

result = run_cs_echo_recovery_demo(csCfg);
```

## 运行默认值

正式主流程默认采用 headless 方式：

- `config.display.showInterruptedEcho = false`
- `config.display.showProgress = false`
- `config.analysis.pointAnaCfg.showFigures = false`

这意味着：

- 正式实验默认不依赖图窗交互
- 更适合批处理、回归和远程运行
- 如果你需要在 notebook 或手工调试时看图，可以用配置覆盖重新打开显示

## 输出目录

### 主流程输出

主流程输出目录默认位于工作区根目录下的 `img/`，也就是 `gotha_bp_project/` 的上一级目录。

常见产物包括：

- `gotha_*.jpg`
- `interruption_summary.txt`
- `interruption_layout.jpg`
- `point_analysis_result.mat`
- `point_analysis_summary.txt`
- `point_analysis_upslice.jpg`
- `point_analysis_contour.jpg`
- `point_analysis_range_profile.jpg`
- `point_analysis_azimuth_profile.jpg`

### 恢复流程输出

恢复流程输出目录位于：

- `cs_echo_recovery/results/run_yyyyMMdd_HHmmss/`

常见产物包括：

- `summary/recovery_result.mat`
- `summary/recovery_metrics.txt`
- `summary/echo_comparison.jpg`
- `summary/image_comparison.jpg`
- `original/`
- `interrupted/`
- `recovered_1d/`
- `recovered_2d/`

## 版本控制约定

运行产物默认不纳入版本控制。

当前仓库忽略规则至少覆盖：

- `/img/`
- `/cs_echo_recovery/results/`

也就是说：

- 源码、文档、配置和最小示例应纳入版本控制
- 大量 `.mat` / `.jpg` / `.txt` 实验输出不应作为日常提交内容

## 随机间断种子复用

如果一次 `random_gap` 运行已经生成了输出目录，可以通过 `bp_read_seed_from_run_dir` 回读该次实验使用的随机种子：

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);
addpath(fullfile(projectRoot, 'src'));

seed = bp_read_seed_from_run_dir( ...
    'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/img/run_20260418_215852_seed735816719');
```

## notebook 说明

`main_gotha_bp.ipynb` 现在只承担三件事：

- 准备路径
- 让你在 cell 里编辑 `userCfg`
- 调用 `main_gotha_bp(userCfg)`

如果你要修主流程逻辑，请改 `main_gotha_bp.m`，不要在 notebook 里再维护一份实现。

## 本地辅助脚本

`open_vscode_matlab_notebook.cmd` 可以作为本机辅助工具使用，但它不是正式实验入口，也不应成为可复现实验的唯一依赖。正式实验请优先使用：

- `main_gotha_bp.m`
- `run_cs_echo_recovery_demo.m`
- `examples/*.m`

## 下一步

Phase 1 完成后，建议继续：

- 固定间断 BP 成像基线
- 收敛压缩感知恢复链路
- 建立完整 / 间断 / 恢复三类成像的图像域对比判据
- 补自动化测试和缩小规模回归用例
