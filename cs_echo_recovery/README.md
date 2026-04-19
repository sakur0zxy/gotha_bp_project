# 压缩感知恢复模块

这个目录负责主流程之后的恢复实验：

1. 生成方位向间断数据
2. 恢复缺失回波
3. 对完整、间断、恢复后回波分别成像
4. 做图像对比和点目标分析

## 入口

- `run_cs_echo_recovery_demo.m`
  推荐入口
- `cs_default_config.m`
  恢复模块默认配置
- `cs_recovery_pipeline.m`
  恢复主流水线

## 最小运行

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);
addpath(fullfile(projectRoot, 'cs_echo_recovery'));

csCfg = struct();
csCfg.project = struct('path', struct('dataRoot', 'E:/path/to/gotcha_BP'));

result = run_cs_echo_recovery_demo(csCfg);
```

主流程没通之前，不建议直接跑恢复流程。

## 自定义数据集

恢复流程复用主流程的数据契约，只是挂在 `csCfg.project` 下：

```matlab
csCfg = struct();
csCfg.project = struct( ...
    'path', struct('dataRoot', 'E:/path/to/your_dataset_root'), ...
    'general', struct( ...
        'numDataFiles', 2, ...
        'dataFilePattern', 'sample_%02d.mat', ...
        'dataVariableName', 'sarData', ...
        'dataFieldMap', struct( ...
            'x', 'platform_x', ...
            'y', 'platform_y', ...
            'z', 'platform_z', ...
            'echo', 'echo_matrix', ...
            'freq', 'freq_hz')));

result = run_cs_echo_recovery_demo(csCfg);
```

## 两种恢复方法

- `1D 方位向恢复`
  对每个距离单元沿方位向做 FFT 稀疏恢复
- `2D 整幅回波恢复`
  对整幅回波矩阵做二维 FFT 稀疏恢复

默认两种都跑。只跑一种时改：

```matlab
csCfg.method = struct('run1D', true, 'run2D', false);
```

## 常改参数

- `csCfg.project`
- `csCfg.method.run1D`
- `csCfg.method.run2D`
- `csCfg.compare.runImaging`
- `csCfg.compare.runPointAnalysis`
- `csCfg.recovery.maxIter`
- `csCfg.recovery.tol`
- `csCfg.recovery.lambda1D`
- `csCfg.recovery.lambda2D`
- `csCfg.data.rangeIndexRange`
- `csCfg.data.azimuthIndexRange`
- `csCfg.output.enableOutput`

默认值和参数说明见 [cs_default_config.m](cs_default_config.m)。

## 输出目录

默认输出到 `cs_echo_recovery/results/run_yyyyMMdd_HHmmss/`，常见内容有：

- `summary/recovery_result.mat`
- `summary/recovery_metrics.txt`
- `summary/echo_comparison.jpg`
- `summary/image_comparison.jpg`
- `original/`
- `interrupted/`
- `recovered_1d/`
- `recovered_2d/`

## 建议

- 先固定间断参数，再调恢复参数
- 只想验证流程时，先裁一小块 `csCfg.data`
- 判断恢复效果时，同时看回波误差、成像图和点目标分析
