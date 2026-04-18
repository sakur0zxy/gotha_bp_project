# 压缩感知回波恢复模块

该目录提供一个独立于主工程的新实验模块，用于在不修改现有代码的前提下，完成以下流程：

- 生成间断采样回波
- 使用压缩感知方法恢复缺失回波
- 对原始、间断和恢复后的回波分别成像
- 对各类成像结果执行点目标分析

## 目录结构

```text
cs_echo_recovery/
├─ run_cs_echo_recovery_demo.m
├─ cs_default_config.m
├─ cs_recovery_pipeline.m
├─ cs_recover_azimuth_fft_ista.m
├─ cs_recover_echo_fft2_ista.m
├─ cs_build_full_cutinfo.m
├─ cs_save_results.m
└─ README.md
```

## 快速开始

```matlab
addpath('gotha_bp_project');
addpath(fullfile('gotha_bp_project', 'cs_echo_recovery'));

result = run_cs_echo_recovery_demo();
```

如需覆盖默认参数，可传入结构体：

```matlab
userCfg = struct();
userCfg.project = struct( ...
    'interruption', struct( ...
        'mode', 'random_gap', ...
        'numSegments', 5, ...
        'missingRatio', 0.1, ...
        'randomSeed', 42));

result = run_cs_echo_recovery_demo(userCfg);
```

## 两种恢复方法

- `1D 方位向恢复`
  - 对每个距离单元沿方位向做 FFT 稀疏恢复
- `2D 整幅回波恢复`
  - 对整幅回波矩阵做二维 FFT 稀疏恢复

默认两种方法都会运行。

## 关键配置

- `project`
  - 传递给现有 GOTCHA BP 工程的覆盖配置
- `method.run1D`
  - 是否运行 1D 方位向恢复
- `method.run2D`
  - 是否运行 2D 整幅恢复
- `compare.runImaging`
  - 是否生成成像对比
- `compare.runPointAnalysis`
  - 是否在成像后继续做点目标分析
- `recovery.maxIter`
  - 恢复最大迭代次数
- `recovery.tol`
  - 收敛阈值
- `recovery.lambda1D`
  - 1D 方法稀疏权重
- `recovery.lambda2D`
  - 2D 方法稀疏权重
- `data.rangeIndexRange`
  - 可选的距离向索引范围
- `data.azimuthIndexRange`
  - 可选的方位向索引范围

## 输出目录

每次运行会在当前目录下创建：

```text
results/run_yyyyMMdd_HHmmss/
├─ summary/
├─ original/
├─ interrupted/
├─ recovered_1d/
└─ recovered_2d/
```

其中：

- `summary/recovery_result.mat`
  - 保存完整结果结构体
- `summary/recovery_metrics.txt`
  - 保存恢复误差、成像误差和运行时间
- `summary/echo_comparison.jpg`
  - 保存回波对比图
- `summary/image_comparison.jpg`
  - 保存成像对比图

每个方法子目录内会保存：

- `image.jpg`
- `point_analysis_result.mat`
- `point_analysis_summary.txt`
- `point_analysis_upslice.jpg`
- `point_analysis_contour.jpg`
- `point_analysis_range_profile.jpg`
- `point_analysis_azimuth_profile.jpg`

## 说明

- 新模块只新增文件，不修改现有主工程。
- 恢复后回波在观测位置会强制保持与原间断回波一致。
- 成像和点目标分析依然复用现有工程中的实现。
