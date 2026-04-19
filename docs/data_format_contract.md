# 自定义数据集接入指南

## 项目真正需要什么

无论原始 `.mat` 文件怎么命名，项目最终只需要三类信息：

1. 轨迹：`track.X / track.Y / track.Z`
2. 回波矩阵：`echoData`
3. 频率向量：`radar.freqVectorHz`

`bp_data_pipeline.m` 的作用就是把外部字段名映射成这三类内部对象。

## 默认 GOTCHA 契约

```matlab
cfg.general.numDataFiles = 9;
cfg.general.dataFilePattern = 'data_3dsar_pass1_az%03d_VV.mat';
cfg.general.dataVariableName = 'data';
cfg.general.dataFieldMap = struct( ...
    'x', 'x', ...
    'y', 'y', ...
    'z', 'z', ...
    'echo', 'fp', ...
    'freq', 'freq');
```

如果你的数据不是这套命名，就显式覆盖。

## 接入前最小检查

先拿一个样例文件确认三件事：

1. 顶层变量名

```matlab
whos('-file', 'E:/path/to/your_dataset_root/sample_01.mat')
```

2. 内部字段名

```matlab
tmp = load('E:/path/to/your_dataset_root/sample_01.mat');
fieldnames(tmp)
fieldnames(tmp.sarData)
```

3. 尺寸

```matlab
size(tmp.sarData.echo_matrix)
size(tmp.sarData.freq_hz)
size(tmp.sarData.platform_x)
size(tmp.sarData.platform_y)
size(tmp.sarData.platform_z)
```

## 需要改哪些配置

接入新数据集时，核心只改：

- `general.numDataFiles`
- `general.dataFilePattern`
- `general.dataVariableName`
- `general.dataFieldMap`

## 主流程模板

```matlab
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

## 恢复流程模板

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

## 单文件要求

- 顶层变量必须存在，且是标量 `struct`
- `dataFieldMap` 必须映射出 `x/y/z/echo/freq`
- `x/y/z` 必须是非空数值向量，且长度一致
- `freq` 必须是非空数值向量
- `echo` 必须是非空二维数值矩阵
- `size(echo, 1) == numel(freq)`
- `size(echo, 2) == numel(x)`

项目默认把：

- 行方向当作距离向
- 列方向当作方位向

## 多文件要求

如果 `numDataFiles > 1`，文件会按方位向顺序拼接。此时还要求：

- 各文件频率向量长度一致
- 各文件频率向量数值一致
- 拼接后回波总列数等于轨迹总长度

## `dataFieldMap` 怎么看

左边是项目内部逻辑名，右边是你文件里的真实字段名。

```matlab
cfg.general.dataFieldMap = struct( ...
    'x', 'platform_x', ...
    'y', 'platform_y', ...
    'z', 'platform_z', ...
    'echo', 'echo_matrix', ...
    'freq', 'freq_hz');
```

表示：

- 内部 `x` 对应 `platform_x`
- 内部 `echo` 对应 `echo_matrix`
- 内部 `freq` 对应 `freq_hz`

## 推荐接入顺序

1. 先检查样例文件
2. 写最小 `userCfg.general`
3. 先跑 `main_gotha_bp(userCfg)`
4. 主流程通了再接恢复流程

## 常见错误

### `bp_data_pipeline:MissingDatasetVariable`

顶层变量名不对。先检查 `general.dataVariableName`。

### `bp_data_pipeline:InvalidDatasetVariable`

顶层变量存在，但不是标量 `struct`。

### `bp_data_pipeline:MissingDatasetFields`

`dataFieldMap` 映射不到真实字段。

### `bp_data_pipeline:TrackLengthMismatch`

`x/y/z` 长度不一致。

### `bp_data_pipeline:RangeFrequencyMismatch`

回波第一维和频率向量长度不一致。

### `bp_data_pipeline:AzimuthTrackMismatch`

回波第二维和轨迹长度不一致。

### `bp_data_pipeline:FrequencyVectorMismatch`

多文件之间的频率向量不一致。

## 最小检查清单

1. 我知道文件名模式
2. 我知道顶层变量名
3. 我知道轨迹、回波、频率字段名
4. 我确认 `echo` 是二维矩阵
5. 我确认 `x/y/z` 是一维向量且长度一致
6. 我确认 `size(echo, 1) == numel(freq)`
7. 我确认 `size(echo, 2) == numel(x)`
