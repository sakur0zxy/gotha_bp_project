# 第一次运行指南

目标：先跑通主流程，再接恢复流程。

## 先记住流程

1. 读取完整回波
2. 制造方位向间断
3. BP 成像
4. 恢复缺失回波
5. 比较完整、间断、恢复后的图像

## 运行前要知道什么

- MATLAB 可用
- 你有数据集文件
- 你知道数据根目录
- 如果不是默认 GOTCHA 命名，还要知道：
  - 文件名模式
  - 顶层变量名
  - 轨迹字段名
  - 回波字段名
  - 频率字段名

## 路径 A：默认 GOTCHA

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);

userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/gotcha_BP');

result = main_gotha_bp(userCfg);
```

先确认这些字段有值：

- `result.image`
- `result.interruptionInfo`
- `result.meta.runOutput.runDir`

## 路径 B：自定义数据集

先检查样例文件：

```matlab
whos('-file', 'E:/path/to/your_dataset_root/sample_01.mat')
tmp = load('E:/path/to/your_dataset_root/sample_01.mat');
fieldnames(tmp)
fieldnames(tmp.sarData)
size(tmp.sarData.echo_matrix)
size(tmp.sarData.freq_hz)
```

再写配置：

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);

userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/your_dataset_root');
userCfg.general = struct( ...
    'numDataFiles', 2, ...
    'dataFilePattern', 'sample_%02d.mat', ...
    'dataVariableName', 'sarData', ...
    'dataFieldMap', struct( ...
        'x', 'platform_x', ...
        'y', 'platform_y', ...
        'z', 'platform_z', ...
        'echo', 'echo_matrix', ...
        'freq', 'freq_hz'));

result = main_gotha_bp(userCfg);
```

如果报错，先看 [data_format_contract.md](data_format_contract.md)。

## 为什么先跑主流程

主流程只覆盖：

- 数据入口
- 间断采样
- BP 成像

如果一上来就跑恢复流程，问题范围会更大。

## 主流程跑通后

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);
addpath(fullfile(projectRoot, 'cs_echo_recovery'));

csCfg = struct();
csCfg.project = struct('path', struct('dataRoot', 'E:/path/to/gotcha_BP'));

result = run_cs_echo_recovery_demo(csCfg);
```

自定义数据集时，把主流程的 `general` 覆盖改写到 `csCfg.project.general`。

## 结果怎么看

主流程先看：

- `result.image`
- `result.interruptionInfo`
- `result.pointAnalysis`
- `result.meta.runOutput.runDir`

恢复流程先看：

- `result.cases.original`
- `result.cases.interrupted`
- `result.cases.recovered_1d`
- `result.cases.recovered_2d`

重点不是“恢复后有没有变化”，而是“是否比 interrupted 更接近 original”。

## 常改参数

数据：

- `path.dataRoot`
- `general.numDataFiles`
- `general.dataFilePattern`
- `general.dataVariableName`
- `general.dataFieldMap`

间断：

- `interruption.mode`
- `interruption.numSegments`
- `interruption.missingRatio`
- `interruption.randomSeed`

成像：

- `image.numPixels`
- `image.xLimits`
- `image.yLimits`

恢复：

- `csCfg.method.run1D`
- `csCfg.method.run2D`
- `csCfg.recovery.maxIter`
- `csCfg.recovery.lambda1D`
- `csCfg.recovery.lambda2D`

输出：

- `output.enableOutput`
- `display.showProgress`
- `analysis.pointAnaCfg.showFigures`

默认值和参数说明以：

- [../config/default_config.m](../config/default_config.m)
- [../cs_echo_recovery/cs_default_config.m](../cs_echo_recovery/cs_default_config.m)

中的注释为准。

## 常见坑

1. 为改参数直接改源码
2. 自定义数据集只改路径，不改字段映射
3. 主流程没通就直接跑恢复
4. 报错时不看标识符和配置

## 常见报错

### `bp_data_pipeline:ExplicitDataRootMissing`

`dataRoot` 下没找到第一个必需文件。

### `bp_data_pipeline:MissingDatasetVariable`

顶层变量名不对。

### `bp_data_pipeline:MissingDatasetFields`

字段映射不对。

### `bp_data_pipeline:TrackLengthMismatch`

`x/y/z` 长度不一致。

### `bp_data_pipeline:RangeFrequencyMismatch`

`size(echo, 1)` 和 `numel(freq)` 不一致。

### `bp_data_pipeline:AzimuthTrackMismatch`

`size(echo, 2)` 和轨迹长度不一致。

### 配置未知字段

字段拼错或层级放错。见 [config_contract.md](config_contract.md)。

## 最小工作流

1. 复制 `examples/run_bp_minimal.m`
2. 先只改 `path.dataRoot`
3. 主流程跑通后再接恢复流程
4. 最后再调恢复参数
