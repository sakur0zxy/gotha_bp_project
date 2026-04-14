# GOTCHA 间断采样 BP 成像项目说明

## 1. 项目简介
本项目将原始单文件脚本 `InterceptSAR_BP_20231018_Gotha.m` 模块化为可维护的 MATLAB 工程。  
核心功能是在间断采样条件下，对 GOTCHA 数据执行 BP（Back Projection）成像，并输出结果图像。

项目目标：
- 保留原算法主流程和实验参数逻辑；
- 提升代码可读性、可维护性和可扩展性；
- 支持通过配置文件统一管理参数；
- 保留原脚本名作为兼容入口。

## 2. 目录结构
```text
matlab_gocha_分布式SAR成像/
├─ InterceptSAR_BP_20231018_Gotha.m                # 兼容入口（旧文件名）
├─ InterceptSAR_BP_20231018_Gotha.backup_*.m       # 原始备份
├─ gotcha_BP/                                      # 原始数据目录（示例）
├─ img/                                            # 输出图像目录
└─ gotha_bp_project/
   ├─ main_gotha_bp.m                              # 主入口
   ├─ README.md                                    # 项目说明
   ├─ config/
   │  └─ default_config.m                          # 默认配置
   └─ src/
      ├─ point_analysis.m                          # 项目内点目标分析脚本（新版）
      ├─ bp_setup_paths.m                          # 路径初始化
      ├─ bp_merge_config.m                         # 配置合并
      ├─ bp_get_numeric_class.m                    # 精度类型选择
      ├─ bp_validate_config.m                      # 配置合法性校验
      ├─ bp_find_data_root.m                       # 数据目录探测
      ├─ bp_load_data.m                            # 数据读取与拼接
      ├─ bp_build_radar_params.m                   # 雷达参数构建
      ├─ bp_apply_interruption.m                   # 间断采样处理
      ├─ bp_create_iteration_weights.m             # 迭代权重生成
      ├─ bp_run_imaging.m                          # BP 核心成像
      ├─ bp_prepare_run_output_dir.m               # 本次运行输出目录创建
      ├─ bp_save_image_output.m                    # 成像图保存
      ├─ bp_run_point_analysis.m                   # 点目标分析调用
      └─ bp_save_point_analysis_output.m           # 点目标分析结果保存
```

## 3. 快速开始
### 方式 A：保持原习惯（推荐迁移期使用）
直接运行根目录脚本：
```matlab
InterceptSAR_BP_20231018_Gotha
```
该脚本会自动调用 `gotha_bp_project/main_gotha_bp.m`。

### 方式 B：直接调用项目主函数
```matlab
addpath('gotha_bp_project');
results = main_gotha_bp();
```

运行成功后，默认会在 `img` 下创建本次运行独立目录，并把成像图和点目标分析结果都输出到该目录：
```text
img/run_20260408_110530/
  ├─ gotha_tail_gap_6_0.2_20260408_110530.jpg
  ├─ point_analysis_result.mat
  ├─ point_analysis_summary.txt
  └─ point_analysis_upslice.jpg
```

## 4. 配置说明
默认参数在 `config/default_config.m` 中集中管理，主要包括：
- `general`：精度、数据文件数量、文件名模式；
- `radar`：雷达常量与距离向零填充倍数；
- `image`：成像范围与网格尺寸；
- `interruption`：间断模式、分段数、整体缺失率与随机间断参数；
- `display`：中间图显示、归一化和过程刷新间隔；
- `output`：输出目录、运行文件夹策略、文件名前缀和时间戳策略；
- `analysis`：成像后点目标分析开关、物理参数与旋转分析配置；
- `path`：数据目录候选列表（自动探测）。

## 5. 自定义参数示例
```matlab
addpath('gotha_bp_project');

userCfg = struct();
userCfg.interruption = struct( ...
    'mode', 'tail_gap', ...
    'missingRatio', 0.3, ...
    'numSegments', 8);
userCfg.image = struct('numPixels', 600, 'xLimits', [-60, 60], 'yLimits', [-60, 60]);
userCfg.general = struct('useSinglePrecision', false);

results = main_gotha_bp(userCfg);
```

随机间断示例：
```matlab
userCfg = struct();
userCfg.interruption = struct( ...
    'mode', 'random_gap', ...
    'missingRatio', 0.2, ...
    'numSegments', 4, ...
    'gapMinMeters', 2, ...
    'gapMaxMeters', 50, ...
    'randomSeed', 42);

results = main_gotha_bp(userCfg);
```

## 6. 成像后点目标分析
主流程已集成 `gotha_bp_project/src/point_analysis.m`，默认在成像完成后自动执行。  
若只想做成像、不做点目标分析，可在配置中关闭：

```matlab
userCfg = struct();
userCfg.analysis = struct('enablePointAnalysis', false);
results = main_gotha_bp(userCfg);
```

常用可调项：
- `analysis.physics`：`Br/Fr/PRF/vc/squintAngleDeg/lambda`（留空则自动推导或走默认值）  
- `analysis.pointAnaCfg`：透传到 `point_analysis.m`，常用如 `showFigures`、`enableTiltAlign`、`tiltApplyThresholdDeg`
## 7. 主要处理流程
1. 初始化路径与配置；
2. 读取并拼接 9 份分段数据；
3. 按 `tail_gap` 或 `random_gap` 模式生成方位向缺失样本；
4. 计算三阶迭代权重；
5. 执行 BP 核心成像（距离映射、相位补偿、历史图像迭代）；
6. （可选）执行点目标剖面与旁瓣分析（含旋转目标分析）；
7. 归一化并保存图像。

## 8. 常见问题
- 报错“未找到数据文件”：  
  检查 `gotcha_BP` 目录是否存在，或在 `default_config.m` 中调整 `path.dataRootCandidates`。

- 想加速运行：  
  可保持 `useSinglePrecision = true`，并减少 `image.numPixels`。

- 想看成像过程图：  
  保持 `display.showProgress = true`；若不需要可设为 `false` 以降低绘图开销。

## 9. 2026-04 rotation and random-gap notes
- Point-target tilt correction now uses a coarse-to-fine separability search on the upsampled target patch. The search evaluates angles in three stages and maximizes the first-singular-value energy ratio after rotation.
- For `random_gap`, when `gapMinMeters` or `gapMaxMeters` is not feasible, the runtime error now reports both sample-domain and meter-domain limits, including the feasible meter ranges implied by `missingRatio`, `numSegments`, and the track mean step.
