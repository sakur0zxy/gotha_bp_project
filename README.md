# GOTCHA 间断采样 BP 成像项目

## 项目简介
该项目将原始单脚本流程整理为可维护的 MATLAB 工程，核心功能包括：

- 读取 GOTCHA 数据并执行 BP 成像
- 按配置生成 `tail_gap` 或 `random_gap` 间断采样
- 输出成像图、间断摘要和点目标分析结果

## 公开入口
- 根目录兼容入口：`InterceptSAR_BP_20231018_Gotha`
- 项目主函数：`gotha_bp_project/main_gotha_bp.m`
- 工具函数：`gotha_bp_project/src/bp_read_seed_from_run_dir.m`

项目运行时只会把 `gotha_bp_project`、`config` 和 `src` 加入 MATLAB 路径。`gotcha_BP` 仅作为默认数据目录候选，不再作为代码搜索路径；`常用` 目录也不再参与回退调用。

## 目录结构
```text
matlab_gocha_分布式SAR成像/
├─ InterceptSAR_BP_20231018_Gotha.m
├─ gotcha_BP/
├─ img/
└─ gotha_bp_project/
   ├─ main_gotha_bp.m
   ├─ README.md
   ├─ config/
   │  └─ default_config.m
   └─ src/
      ├─ bp_data_pipeline.m
      ├─ bp_interruption_pipeline.m
      ├─ bp_imaging_pipeline.m
      ├─ bp_output_pipeline.m
      ├─ bp_read_seed_from_run_dir.m
      ├─ bp_run_point_analysis.m
      └─ point_analysis.m
```

## 快速开始
方式 1：保持历史调用方式。

```matlab
InterceptSAR_BP_20231018_Gotha
```

方式 2：直接调用主函数。

```matlab
addpath('gotha_bp_project');
result = main_gotha_bp();
```

## 关键配置
默认配置集中在 `gotha_bp_project/config/default_config.m`。

### 数据目录
- `config.path.dataRootCandidates`：数据根目录候选，默认会依次检查 `.` 和 `gotcha_BP`
- `gotcha_BP` 当前只承担数据目录角色，不要求把其中的 `.m` 文件加入路径

### 间断采样
- `mode`：`tail_gap` 或 `random_gap`
- `numSegments`：分段数
- `missingRatio`：总缺失率
- `gapMinMeters` / `gapMaxMeters`：随机间断的单段长度范围
- `randomSeed`：随机间断种子；为空时自动生成

### 点目标分析
- `analysis.enablePointAnalysis`：是否启用点目标分析
- `analysis.failOnPointAnalysisError`：分析失败时是否中止主流程
- `analysis.pointAnaCfg.showFigures`：是否显示点目标分析图窗
- `analysis.pointAnaCfg.enableTiltAlign`：是否启用旋转矫正
- `analysis.pointAnaCfg.tiltApplyThresholdDeg`：触发旋转矫正的最小角度
- `analysis.pointAnaCfg.tiltEdgeFraction`：用于估角的左右边缘列比例

## 配置示例
固定尾部间断：

```matlab
addpath('gotha_bp_project');

userCfg = struct();
userCfg.interruption = struct( ...
    'mode', 'tail_gap', ...
    'numSegments', 8, ...
    'missingRatio', 0.3);

result = main_gotha_bp(userCfg);
```

随机间断：

```matlab
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

## 点目标分析与旋转矫正
点目标分析函数位于 `gotha_bp_project/src/point_analysis.m`，默认在成像后自动执行。

当前角度矫正流程：

1. 在峰值邻域提取点目标切片。
2. 对切片做频域升采样。
3. 在升采样图上逐列寻找最大值行坐标。
4. 只使用左右边缘列做直线拟合，估计倾角。
5. 用估计角对升采样图旋转矫正。
6. 后续剖面、PSLR、ISLR、IRW 和输出图片全部使用矫正后的图像。

未矫正图像仍保留在结果结构的 `raw` 字段中，仅用于参考对比。

## 输出文件
每次运行会在 `img/` 下创建独立目录。`random_gap` 模式会把实际种子写入目录名：

```text
img/run_20260414_181016_seed49393163/
```

常见输出文件包括：

- 成像图：`gotha_*.jpg`
- 间断摘要：`interruption_summary.txt`
- 间断布局图：`interruption_layout.jpg`
- 点目标分析结果：`point_analysis_result.mat`
- 点目标分析摘要：`point_analysis_summary.txt`
- 点目标分析图：
  - `point_analysis_upslice.jpg`
  - `point_analysis_contour.jpg`
  - `point_analysis_range_profile.jpg`
  - `point_analysis_azimuth_profile.jpg`

## 种子复用
如果需要复现某次 `random_gap` 运行，可直接从旧目录读取种子：

```matlab
addpath('gotha_bp_project');
addpath(fullfile('gotha_bp_project', 'src'));
seed = bp_read_seed_from_run_dir('E:\...\img\run_20260414_181016_seed49393163');
```

然后把 `seed` 回填到 `config.interruption.randomSeed` 即可。
