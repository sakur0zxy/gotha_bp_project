# BP 间断采样与压缩感知恢复实验项目

这是一个面向个人科研实验的 MATLAB 项目。它把现有的 GOTCHA BP 工程整理成一套更容易复现、验证和扩展的实验流程，并且已经支持“任意满足输入契约的数据集”。

项目当前最关心的问题只有一个：  
在方位向数据间断条件下，压缩感知恢复后的成像结果，能否在图像域上尽可能接近完整数据 BP 成像结果。

## 这个仓库适合谁

- 你第一次接触这个项目，想先跑通一遍
- 你已经能跑 GOTCHA，想接入自己的数据集
- 你想调实验参数，但不想直接改源码
- 你想知道主流程、恢复流程和输出目录分别在哪里

## 第一次上手先看什么

如果你是第一次打开这个仓库，推荐按下面顺序阅读：

1. [docs/getting_started.md](docs/getting_started.md)  
   说明：第一次运行指南。按步骤告诉你先准备什么、先跑哪个脚本、看到什么算正常。
2. [examples/run_bp_minimal.m](examples/run_bp_minimal.m)  
   说明：最小主流程示例。适合先跑完整数据加载、间断采样和 BP 成像。
3. [examples/run_cs_recovery_minimal.m](examples/run_cs_recovery_minimal.m)  
   说明：最小恢复流程示例。适合在主流程跑通后继续做压缩感知恢复。
4. [docs/data_format_contract.md](docs/data_format_contract.md)  
   说明：如果你的数据不是默认 GOTCHA 命名，先看这里。
5. [docs/config_contract.md](docs/config_contract.md)  
   说明：如果你想改参数、不确定该改哪里、或者遇到配置报错，查看这里。

## 30 秒理解项目流程

可以把整个项目理解成一条固定流水线：

1. 从磁盘读取完整回波数据，并标准化成内部统一格式
2. 在方位向上人为制造数据间断
3. 用 BP 算法对间断数据成像，得到基线结果
4. 对图像做点目标分析，用主瓣和旁瓣评价成像质量
5. 用压缩感知方法恢复缺失回波，再重新成像并和完整/间断结果对比

如果你只想先跑成像，看主流程入口。  
如果你要做恢复实验，看恢复流程入口。

## 两个正式入口

- 主流程入口：`main_gotha_bp.m`
  作用：完成“加载数据 -> 制造间断 -> BP 成像 -> 点目标分析 -> 保存结果”
- 恢复流程入口：`cs_echo_recovery/run_cs_echo_recovery_demo.m`
  作用：在主流程基础上继续完成“压缩感知恢复 -> 恢复后成像 -> 多结果对比”

`main_gotha_bp.ipynb` 只是交互式 wrapper。  
如果你要改正式逻辑，请改 `.m` 文件，不要在 notebook 里维护第二套实现。

## 最快运行方式

### 场景 A：你手里就是默认 GOTCHA 数据

这是最简单的路径。你通常只需要指定数据根目录：

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);

userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/gotcha_BP');

result = main_gotha_bp(userCfg);
```

第一次建议先跑主流程。  
主流程跑通后，再运行恢复流程：

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);
addpath(fullfile(projectRoot, 'cs_echo_recovery'));

csCfg = struct();
csCfg.project = struct('path', struct('dataRoot', 'E:/path/to/gotcha_BP'));

result = run_cs_echo_recovery_demo(csCfg);
```

### 场景 B：你的数据不是默认 GOTCHA 命名

这时不要改算法源码，先改数据契约配置：

```matlab
userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/your_dataset_root');
userCfg.general = struct( ...
    'numDataFiles', 2, ...
    'dataFilePattern', 'sar_pass_%02d.mat', ...
    'dataVariableName', 'sarData', ...
    'dataFieldMap', struct( ...
        'x', 'platform_x', ...
        'y', 'platform_y', ...
        'z', 'platform_z', ...
        'echo', 'echo_matrix', ...
        'freq', 'freq_hz'));

result = main_gotha_bp(userCfg);
```

这五个字段的尺寸和含义要求见 [docs/data_format_contract.md](docs/data_format_contract.md)。

## 你最常改的配置在哪里

如果你只是正常做实验，通常只会碰下面这些配置：

| 你要做的事 | 主流程改哪里 | 恢复流程改哪里 |
|---|---|---|
| 指定数据目录 | `userCfg.path.dataRoot` | `csCfg.project.path.dataRoot` |
| 接入自己的数据集 | `userCfg.general.*` | `csCfg.project.general.*` |
| 调整间断比例/模式 | `userCfg.interruption.*` | `csCfg.project.interruption.*` |
| 调整成像网格 | `userCfg.image.*` | `csCfg.project.image.*` |
| 控制显示 | `userCfg.display.*` | `csCfg.project.display.*` |
| 关闭文件输出 | `userCfg.output.enableOutput` | `csCfg.output.enableOutput` |
| 调整恢复迭代参数 | 不适用 | `csCfg.recovery.*` |
| 控制是否跑 1D/2D 恢复 | 不适用 | `csCfg.method.*` |

默认配置文件在：

- [config/default_config.m](config/default_config.m)
- [cs_echo_recovery/cs_default_config.m](cs_echo_recovery/cs_default_config.m)

但正式实验推荐在 `userCfg` 或 `csCfg` 中覆盖，不要直接改默认配置文件。

## 运行后你会得到什么

### 主流程结果

主流程返回的 `result` 里，最常用的是：

- `result.image`  
  说明：BP 成像结果矩阵
- `result.interruptionInfo`  
  说明：本次方位向间断布局、随机种子等元数据
- `result.pointAnalysis`  
  说明：点目标分析结果
- `result.meta.runOutput.runDir`  
  说明：本次结果输出目录

### 恢复流程结果

恢复流程返回的 `result` 里，最常用的是：

- `result.cases.original`  
  说明：完整数据成像结果
- `result.cases.interrupted`  
  说明：间断数据成像结果
- `result.cases.recovered_1d` / `result.cases.recovered_2d`  
  说明：恢复后成像结果
- `result.paths.runDir`  
  说明：恢复实验输出目录
- `result.summary`  
  说明：本次恢复实验的摘要信息

## 输出目录在哪里

- 主流程输出：工作区根目录下的 `img/`
- 恢复流程输出：`cs_echo_recovery/results/run_yyyyMMdd_HHmmss/`

如果你只想拿返回值、不想落盘，可以关闭输出总开关：

```matlab
userCfg.output = struct('enableOutput', false);
```

或：

```matlab
csCfg.output = struct('enableOutput', false);
```

## 仓库地图

下面这些文件是最值得先认识的：

- [main_gotha_bp.m](main_gotha_bp.m)  
  主流程入口
- [cs_echo_recovery/run_cs_echo_recovery_demo.m](cs_echo_recovery/run_cs_echo_recovery_demo.m)  
  恢复流程入口
- [src/bp_data_pipeline.m](src/bp_data_pipeline.m)  
  数据入口。负责把原始 `.mat` 数据转成内部统一格式
- [src/bp_interruption_pipeline.m](src/bp_interruption_pipeline.m)  
  方位向间断采样逻辑
- [src/bp_imaging_pipeline.m](src/bp_imaging_pipeline.m)  
  BP 成像主计算
- [src/bp_run_point_analysis.m](src/bp_run_point_analysis.m)  
  点目标分析入口
- [tests/test_data_pipeline_contract.m](tests/test_data_pipeline_contract.m)  
  数据契约最小自动化测试

## 常见问题

### 1. 我应该先跑哪个脚本？

先跑主流程 `main_gotha_bp.m`。  
只有主流程跑通以后，再继续看恢复流程。

### 2. 我想换实验参数，应该改哪里？

优先改 `userCfg` 或 `csCfg`。  
不要为了改一个实验参数直接去改 `default_config.m` 或算法源码。

### 3. 我有自己的数据集，最先该确认什么？

先确认三件事：

1. `.mat` 文件名模式是什么
2. 顶层变量名是什么
3. 轨迹、回波、频率字段分别叫什么

然后按 [docs/data_format_contract.md](docs/data_format_contract.md) 中的模板填 `userCfg.general`。

### 4. 如果运行直接报错，先看哪里？

优先看：

1. 报错标识符，例如 `bp_data_pipeline:MissingDatasetFields`
2. 报错文件路径
3. 你传入的 `userCfg` / `csCfg`
4. [docs/config_contract.md](docs/config_contract.md) 和 [docs/data_format_contract.md](docs/data_format_contract.md)

## 当前版本明确不做

- GUI 图形界面
- Python 重写
- 在线服务化 / Web API

## 下一步建议

如果你现在刚把项目跑通，推荐下一步做下面三件事：

1. 先固定一组可复现的间断 BP 基线结果
2. 再调压缩感知恢复参数，让恢复后图像主瓣尽量接近完整数据
3. 用点目标分析和图像对比一起判断恢复是否真的改进
