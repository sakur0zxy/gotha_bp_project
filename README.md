# GOTCHA 间断采样 BP 成像项目

## 项目简介
该项目实现基于 GOTCHA 数据集的 BP 间断成像，核心功能包括：

- 读取 GOTCHA 数据并按配置生成 `tail_gap` 或 `random_gap` 间断采样
- 执行 BP 成像
- 输出成像图、间断摘要和点目标分析结果

## 公开入口
- 项目主函数：`main_gotha_bp.m`
- 工具函数：`src/bp_read_seed_from_run_dir.m`

## 目录结构
```text
gotha_bp_project/
├─ main_gotha_bp.m
├─ README.md
├─ config/
│  └─ default_config.m
└─ src/
   ├─ bp_data_pipeline.m
   ├─ bp_imaging_pipeline.m
   ├─ bp_interruption_pipeline.m
   ├─ bp_merge_config.m
   ├─ bp_output_pipeline.m
   ├─ bp_read_seed_from_run_dir.m
   ├─ bp_run_point_analysis.m
   ├─ bp_validate_config.m
   ├─ point_analysis.m
   └─ point_analysis_algorithm.md
```

## 快速开始
```matlab
addpath('gotha_bp_project');
result = main_gotha_bp();
```

## 关键配置
默认配置位于 `config/default_config.m`。

### 数据目录
- `config.path.dataRootCandidates`：数据根目录候选，默认检查工作区根目录下的 `.` 和 `gotcha_BP`
- 上述路径相对工作区根目录解析，不相对 `gotha_bp_project` 目录，也不依赖 MATLAB 当前临时工作目录

### 间断采样
- `config.interruption.mode`：`tail_gap` 或 `random_gap` （`固定间断` 或 `随机间断`） 
- `config.interruption.numSegments`：分段数
- `config.interruption.missingRatio`：总缺失率
- `config.interruption.gapMinMeters` / `config.interruption.gapMaxMeters`：随机间断长度范围
- `config.interruption.randomSeed`：随机种子；为空时自动生成

### 点目标分析
- `config.analysis.enablePointAnalysis`：是否启用点目标分析
- `config.analysis.failOnPointAnalysisError`：分析失败时是否中止主流程
- `config.analysis.pointAnaCfg.showFigures`：是否显示图窗
- `config.analysis.pointAnaCfg.enableTiltAlign`：是否启用旋转矫正
- `config.analysis.pointAnaCfg.tiltApplyThresholdDeg`：触发矫正的最小角度
- `config.analysis.pointAnaCfg.tiltEdgeFraction`：用于估角的左右边缘列比例

## 配置示例
```matlab
addpath('gotha_bp_project');

userCfg = struct();
userCfg.interruption = struct( ...
    'mode', 'random_gap', ...
    'numSegments', 4, ...
    'missingRatio', 0.2, ...
    'gapMinMeters', 2, ...
    'gapMaxMeters', 50, ...
    'randomSeed', 42);

result = main_gotha_bp(userCfg);
```

## 点目标分析
点目标分析默认在成像后自动执行。点目标分析的主结果、主指标和输出图片使用旋转矫正后的图像。

详细算法说明见 `src/point_analysis_algorithm.md`。

## 输出文件
每次运行会在工作区根目录下的 `img/` 中创建独立目录。`random_gap` 模式会把实际种子写入目录名。

常见输出文件：

- `gotha_*.jpg`
- `interruption_summary.txt`
- `interruption_layout.jpg`
- `point_analysis_result.mat`
- `point_analysis_summary.txt`
- `point_analysis_upslice.jpg`
- `point_analysis_contour.jpg`
- `point_analysis_range_profile.jpg`
- `point_analysis_azimuth_profile.jpg`

## 随机间断种子复用
```matlab
addpath('gotha_bp_project');
addpath(fullfile('gotha_bp_project', 'src'));
seed = bp_read_seed_from_run_dir('E:\...\img\run_20260414_181016_seed49393163');
```
