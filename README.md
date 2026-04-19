# BP 间断采样与压缩感知恢复实验项目

用于整理 GOTCHA BP 工程的 MATLAB 实验项目。核心问题只有一个：
方位向数据间断后，恢复图像能否尽量接近完整数据 BP 图像。

## 先看什么

1. [docs/getting_started.md](docs/getting_started.md)
2. [examples/run_bp_minimal.m](examples/run_bp_minimal.m)
3. [examples/run_cs_recovery_minimal.m](examples/run_cs_recovery_minimal.m)
4. [docs/data_format_contract.md](docs/data_format_contract.md)
5. [docs/config_contract.md](docs/config_contract.md)

## 流程

1. 读取完整回波并标准化
2. 制造方位向间断
3. 对间断数据做 BP 成像
4. 做点目标分析
5. 恢复缺失回波并重新成像对比

## 正式入口

- `main_gotha_bp.m`
  主流程：加载数据、制造间断、BP 成像、点目标分析、保存结果
- `cs_echo_recovery/run_cs_echo_recovery_demo.m`
  恢复流程：恢复缺失回波、重新成像、做结果对比

`main_gotha_bp.ipynb` 只是交互式 wrapper，不是主实现。

## 最快运行

### 默认 GOTCHA 数据

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);

userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/gotcha_BP');

result = main_gotha_bp(userCfg);
```

恢复流程：

```matlab
projectRoot = 'E:/博士文件/工作整理/2026/matlab_gocha_分布式SAR成像/gotha_bp_project';
addpath(projectRoot);
addpath(fullfile(projectRoot, 'cs_echo_recovery'));

csCfg = struct();
csCfg.project = struct('path', struct('dataRoot', 'E:/path/to/gotcha_BP'));

result = run_cs_echo_recovery_demo(csCfg);
```

### 自定义数据集

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

字段要求见 [docs/data_format_contract.md](docs/data_format_contract.md)。

## 常改配置

| 需求 | 主流程 | 恢复流程 |
|---|---|---|
| 数据目录 | `userCfg.path.dataRoot` | `csCfg.project.path.dataRoot` |
| 自定义数据集 | `userCfg.general.*` | `csCfg.project.general.*` |
| 间断参数 | `userCfg.interruption.*` | `csCfg.project.interruption.*` |
| 成像网格 | `userCfg.image.*` | `csCfg.project.image.*` |
| 显示 | `userCfg.display.*` | `csCfg.project.display.*` |
| 关闭文件输出 | `userCfg.output.enableOutput` | `csCfg.output.enableOutput` |
| 恢复参数 | 不适用 | `csCfg.recovery.*` |
| 只跑 1D/2D | 不适用 | `csCfg.method.*` |

默认值以：

- [config/default_config.m](config/default_config.m)
- [cs_echo_recovery/cs_default_config.m](cs_echo_recovery/cs_default_config.m)

中的实际赋值和注释为准。

## 常看结果

主流程：

- `result.image`
- `result.interruptionInfo`
- `result.pointAnalysis`
- `result.meta.runOutput.runDir`

恢复流程：

- `result.cases.original`
- `result.cases.interrupted`
- `result.cases.recovered_1d`
- `result.cases.recovered_2d`
- `result.paths.runDir`

## 输出目录

- 主流程：`img/`
- 恢复流程：`cs_echo_recovery/results/run_yyyyMMdd_HHmmss/`

## 仓库地图

- [main_gotha_bp.m](main_gotha_bp.m)
- [cs_echo_recovery/run_cs_echo_recovery_demo.m](cs_echo_recovery/run_cs_echo_recovery_demo.m)
- [src/bp_data_pipeline.m](src/bp_data_pipeline.m)
- [src/bp_interruption_pipeline.m](src/bp_interruption_pipeline.m)
- [src/bp_imaging_pipeline.m](src/bp_imaging_pipeline.m)
- [src/bp_run_point_analysis.m](src/bp_run_point_analysis.m)
- [tests/test_data_pipeline_contract.m](tests/test_data_pipeline_contract.m)

## 不做

- GUI
- Python 重写
- 在线服务化 / Web API
