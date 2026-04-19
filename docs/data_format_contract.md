# 自定义数据集接入指南

这份文档专门回答一个问题：  
如果你的数据不是默认 GOTCHA 命名，怎样才能最稳妥地接进这个项目。

## 1. 先理解项目内部真正需要什么

无论你原始 `.mat` 文件长什么样，项目真正需要的内部信息只有三类：

1. 平台轨迹
   - `track.X`
   - `track.Y`
   - `track.Z`
2. 回波矩阵
   - `echoData`
3. 距离向频率定义
   - `radar.freqVectorHz`

`bp_data_pipeline.m` 的作用，就是把各种外部 `.mat` 命名方式统一整理成这三类内部对象。  
所以你接入新数据集时，重点不是改算法，而是把“原始字段名”和“内部需要的信息”对上。

## 2. 默认 GOTCHA 契约是什么

项目默认假设每个数据文件满足下面这组规则：

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

也就是说，默认情况下项目会去找：

- 文件名类似 `data_3dsar_pass1_az001_VV.mat`
- 顶层变量名叫 `data`
- 轨迹字段叫 `x/y/z`
- 回波字段叫 `fp`
- 频率字段叫 `freq`

如果你的数据不是这套命名，就要显式覆盖。

## 3. 接入新数据集前先做一次最小检查

先选一个样例文件，在 MATLAB 里确认三件事：

### 第一步：看顶层变量名

```matlab
whos('-file', 'E:/path/to/your_dataset_root/sample_01.mat')
```

你需要知道 `.mat` 里面顶层变量到底叫什么，比如：

- `data`
- `sarData`
- `raw`

### 第二步：看内部字段名

```matlab
tmp = load('E:/path/to/your_dataset_root/sample_01.mat');
fieldnames(tmp)
fieldnames(tmp.sarData)
```

你需要确认：

- `x` 对应哪个字段
- `y` 对应哪个字段
- `z` 对应哪个字段
- `echo` 对应哪个字段
- `freq` 对应哪个字段

### 第三步：看尺寸

```matlab
size(tmp.sarData.echo_matrix)
size(tmp.sarData.freq_hz)
size(tmp.sarData.platform_x)
size(tmp.sarData.platform_y)
size(tmp.sarData.platform_z)
```

你需要确认：

- 回波矩阵是二维矩阵
- 频率是向量
- 轨迹 `x/y/z` 都是一维向量

## 4. 你需要填写哪些配置

接入自定义数据集时，核心只改下面四项：

- `general.numDataFiles`
- `general.dataFilePattern`
- `general.dataVariableName`
- `general.dataFieldMap`

## 5. 主流程接入模板

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

## 6. 恢复流程接入模板

恢复流程复用主流程同一套数据契约，只是挂在 `csCfg.project` 下面：

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

## 7. 单文件必须满足的要求

对于每个 `.mat` 文件，项目会检查下面这些条件。

### 顶层变量要求

- 必须存在 `cfg.general.dataVariableName` 指定的变量
- 这个变量必须是标量 `struct`

### 字段要求

`cfg.general.dataFieldMap` 必须能映射出下面五类信息：

- `x`
- `y`
- `z`
- `echo`
- `freq`

### 尺寸要求

- `x/y/z` 必须都是非空数值向量
- `x/y/z` 的长度必须一致
- `freq` 必须是非空数值向量
- `echo` 必须是非空二维数值矩阵
- `size(echo, 1)` 必须等于 `numel(freq)`
- `size(echo, 2)` 必须等于轨迹长度，也就是 `numel(x)`

换句话说，项目默认把回波矩阵理解成：

- 行方向：距离向
- 列方向：方位向

如果你的数据不是这个布局，就需要先在数据准备阶段转换好。

## 8. 多文件拼接要求

如果 `numDataFiles > 1`，项目会按文件顺序把多个文件沿方位向拼起来。

这时还必须满足：

- 每个文件的频率向量长度一致
- 每个文件的频率向量数值一致
- 各文件拼接后，回波矩阵总列数等于轨迹总长度

这意味着项目支持“按文件分块存储的方位向数据”，但默认不支持不同文件使用不同距离向采样定义。

## 9. 如何理解 `dataFieldMap`

`dataFieldMap` 的左边是项目内部逻辑名，右边是你数据文件里的真实字段名。

例如：

```matlab
cfg.general.dataFieldMap = struct( ...
    'x', 'platform_x', ...
    'y', 'platform_y', ...
    'z', 'platform_z', ...
    'echo', 'echo_matrix', ...
    'freq', 'freq_hz');
```

这表示：

- 内部需要的 `x`，去你的数据里找 `platform_x`
- 内部需要的 `echo`，去你的数据里找 `echo_matrix`
- 内部需要的 `freq`，去你的数据里找 `freq_hz`

## 10. 最推荐的接入顺序

如果你是第一次接入新数据集，推荐按下面顺序做：

1. 只拿一个样例文件，确认变量名和字段名
2. 写出最小 `userCfg.general`
3. 只跑 `main_gotha_bp(userCfg)`
4. 主流程跑通后，再接恢复流程

这样定位问题会快很多。

## 11. 常见错误怎么理解

### `bp_data_pipeline:MissingDatasetVariable`

含义：`.mat` 文件里没有你配置的顶层变量名。  
先检查 `general.dataVariableName`。

### `bp_data_pipeline:InvalidDatasetVariable`

含义：顶层变量存在，但不是标量 `struct`。  
先检查你的 `.mat` 文件组织方式。

### `bp_data_pipeline:MissingDatasetFields`

含义：`dataFieldMap` 中至少有一个字段映射不到真实字段。  
先 `load` 样例文件，再 `fieldnames(...)`。

### `bp_data_pipeline:TrackLengthMismatch`

含义：`x/y/z` 三个轨迹字段长度不一致。  
这是数据本身的问题，不是恢复算法的问题。

### `bp_data_pipeline:RangeFrequencyMismatch`

含义：回波矩阵距离向尺寸和频率向量长度不一致。  
先确认 `echo` 的第一维是不是距离向。

### `bp_data_pipeline:AzimuthTrackMismatch`

含义：回波矩阵方位向尺寸和轨迹长度不一致。  
先确认 `echo` 的第二维是不是方位向，并检查轨迹采样数是否匹配。

### `bp_data_pipeline:FrequencyVectorMismatch`

含义：多个文件之间的频率向量不一致。  
这通常说明多文件并不能直接按当前方式拼接。

## 12. 如果你还是不确定自己的数据能不能接

可以先用下面这个最小检查清单：

1. 我能明确写出文件名模式
2. 我知道顶层变量名
3. 我知道轨迹、回波、频率字段名
4. 我确认 `echo` 是二维矩阵
5. 我确认 `x/y/z` 是一维向量且长度一致
6. 我确认 `size(echo, 1) == numel(freq)`
7. 我确认 `size(echo, 2) == numel(x)`

只要这七件事都成立，这个项目大概率就能直接接住你的数据。
