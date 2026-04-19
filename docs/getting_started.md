# 第一次运行指南

这份文档是给第一次接触本项目的人准备的。目标很简单：  
让你在不知道内部实现细节的情况下，也能尽快跑通主流程，并知道下一步该看哪里。

## 1. 先建立最小心智模型

你不需要一开始就理解所有算法细节。先记住下面四件事就够了：

1. 项目先读取完整回波数据
2. 然后在人为设置的方位向位置制造数据缺失
3. 接着用 BP 算法对缺失数据成像
4. 最后再用压缩感知恢复缺失回波，并比较恢复前后成像质量

也就是说，这个项目不是一个“纯成像项目”，而是一套“间断采样 + 恢复 + 成像对比”的实验链路。

## 2. 你需要准备什么

开始前请确认下面几件事：

- MATLAB 可用
- 你已经拿到数据集文件
- 你知道数据集根目录在哪里
- 如果你的数据不是默认 GOTCHA 命名，至少知道：
  - `.mat` 文件名模式
  - 顶层变量名
  - 轨迹字段名
  - 回波字段名
  - 频率字段名

## 3. 两条最常见的上手路径

### 路径 A：直接跑默认 GOTCHA 数据

如果你手里的数据就是默认 GOTCHA 格式，第一步只做一件事：指定数据目录。

把下面代码复制到 MATLAB：

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);

userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/gotcha_BP');

result = main_gotha_bp(userCfg);
```

这段代码成功后，你至少应该能拿到：

- `result.image`
- `result.interruptionInfo`
- `result.meta.runOutput.runDir`

如果你看到输出目录路径，说明主流程已经基本跑通。

### 路径 B：接入你自己的数据集

如果你的数据不是默认 GOTCHA 命名，需要多做一步：告诉项目“这些字段在你的 `.mat` 文件里叫什么名字”。

先用下面代码检查一个样例文件：

```matlab
whos('-file', 'E:/path/to/your_dataset_root/sample_01.mat')
tmp = load('E:/path/to/your_dataset_root/sample_01.mat');
fieldnames(tmp)
```

如果顶层变量叫 `sarData`，继续检查里面的字段：

```matlab
fieldnames(tmp.sarData)
size(tmp.sarData.echo_matrix)
size(tmp.sarData.freq_hz)
```

确认清楚以后，再构造配置：

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

如果这一步报错，优先去看 [data_format_contract.md](data_format_contract.md)。

## 4. 第一次为什么建议先跑主流程

因为恢复流程建立在主流程之上。

如果主流程都还没跑通，你其实还不知道问题出在：

- 数据路径
- 数据格式
- 间断设置
- 成像链路
- 还是恢复链路

先跑主流程能把问题范围缩小到“数据入口 + 间断采样 + BP 成像”。

## 5. 主流程跑通后接着做什么

主流程跑通以后，再跑恢复流程：

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);
addpath(fullfile(projectRoot, 'cs_echo_recovery'));

csCfg = struct();
csCfg.project = struct('path', struct('dataRoot', 'E:/path/to/gotcha_BP'));

result = run_cs_echo_recovery_demo(csCfg);
```

如果你用的是自定义数据集，把主流程中的 `general` 覆盖直接放到 `csCfg.project.general` 即可。

## 6. 运行结果怎么看

### 主流程

主流程的返回值里，先看这几个字段：

- `result.image`
  说明：当前间断条件下的 BP 图像
- `result.interruptionInfo`
  说明：这次间断发生在什么位置、用了什么随机种子
- `result.pointAnalysis`
  说明：主瓣宽度、旁瓣等分析结果
- `result.meta.runOutput.runDir`
  说明：输出目录

### 恢复流程

恢复流程里，重点看这几组图像：

- `result.cases.original`
- `result.cases.interrupted`
- `result.cases.recovered_1d`
- `result.cases.recovered_2d`

理解方式很直接：

- `original` 是完整数据参考结果
- `interrupted` 是缺失数据直接成像结果
- `recovered_*` 是恢复后重新成像结果

你真正关心的是：`recovered_*` 能否比 `interrupted` 更接近 `original`。

## 7. 你最常修改的几个参数

第一次上手时，最常修改的是这几类参数：

### 数据相关

- `path.dataRoot`
- `general.numDataFiles`
- `general.dataFilePattern`
- `general.dataVariableName`
- `general.dataFieldMap`

### 间断相关

- `interruption.mode`
- `interruption.numSegments`
- `interruption.missingRatio`
- `interruption.randomSeed`

### 成像相关

- `image.numPixels`
- `image.xLimits`
- `image.yLimits`

### 恢复相关

- `csCfg.method.run1D`
- `csCfg.method.run2D`
- `csCfg.recovery.maxIter`
- `csCfg.recovery.lambda1D`
- `csCfg.recovery.lambda2D`

### 输出相关

- `output.enableOutput`
- `display.showProgress`
- `analysis.pointAnaCfg.showFigures`

## 8. 新手最容易踩的坑

### 坑 1：为了改实验参数去改源码

不推荐。  
优先在 `userCfg` 或 `csCfg` 里覆盖。

### 坑 2：自定义数据集只改了路径，没有改字段映射

如果你的 `.mat` 文件里不是默认的：

- 顶层变量 `data`
- 回波字段 `fp`
- 频率字段 `freq`

那就必须补 `general.dataVariableName` 和 `general.dataFieldMap`。

### 坑 3：一上来就跑恢复流程

恢复流程问题更多、链路更长。  
先跑通主流程，定位会快很多。

### 坑 4：不知道报错该看哪里

优先看三样东西：

1. 报错标识符
2. 报错消息里的字段路径或文件路径
3. 你自己传入的配置

这个项目的配置和数据入口都采用“立即失败”的策略，所以报错通常已经很接近真实原因。

## 9. 发生报错时怎么排查

### 报错是 `bp_data_pipeline:ExplicitDataRootMissing`

说明：你给的 `dataRoot` 路径下，连第一个必需文件都没找到。  
先检查路径，再检查 `general.dataFilePattern`。

### 报错是 `bp_data_pipeline:MissingDatasetVariable`

说明：`.mat` 文件里没有你配置的顶层变量名。  
先用 `whos -file(...)` 检查实际变量名。

### 报错是 `bp_data_pipeline:MissingDatasetFields`

说明：你配置的字段映射对不上真实字段。  
先 `load` 一个样例文件，再 `fieldnames(...)` 看里面到底叫什么。

### 报错是 `bp_data_pipeline:TrackLengthMismatch`

说明：`x/y/z` 三个轨迹字段长度不一致。  
这是数据契约问题，不是成像算法问题。

### 报错是 `bp_data_pipeline:RangeFrequencyMismatch`

说明：`size(echo, 1)` 和 `numel(freq)` 不一致。  
先确认回波矩阵的行到底是不是距离向。

### 报错是配置未知字段

说明：字段拼错了，或者放错层级了。  
看 [config_contract.md](config_contract.md) 中的覆盖规则。

## 10. 推荐的最小工作流

如果你只是想尽快进入实验状态，推荐按这个顺序做：

1. 先复制 `examples/run_bp_minimal.m`
2. 只改 `path.dataRoot`
3. 主流程跑通后，再决定是否需要自定义数据契约
4. 主流程稳定后，再复制 `examples/run_cs_recovery_minimal.m`
5. 最后再去调恢复参数和对比指标

## 11. 下一份该看的文档

当你完成第一次运行以后，下一步通常是下面三种情况之一：

- 你想接入自己的数据集  
  去看 [data_format_contract.md](data_format_contract.md)
- 你想系统地改参数  
  去看 [config_contract.md](config_contract.md)
- 你想看最小代码模板  
  去看 [../examples/run_bp_minimal.m](../examples/run_bp_minimal.m) 和 [../examples/run_cs_recovery_minimal.m](../examples/run_cs_recovery_minimal.m)
