# 配置修改指南

## 原则

正式实验优先改 `userCfg` / `csCfg`，不要直接改默认配置或算法源码。

不推荐直接改：

- `config/default_config.m`
- `cs_echo_recovery/cs_default_config.m`
- `main_gotha_bp.m`
- `cs_echo_recovery/run_cs_echo_recovery_demo.m`

默认配置文件的作用是定义 schema 和默认值，不是每次实验都手改。

## 配置入口

主流程：

```matlab
result = main_gotha_bp(userCfg);
```

恢复流程：

```matlab
result = run_cs_echo_recovery_demo(csCfg);
```

其中：

- `csCfg.project`
  传给主流程的覆盖配置
- `csCfg.method / recovery / compare / data / output`
  恢复流程自己的配置

## 常改字段

| 需求 | 主流程 | 恢复流程 |
|---|---|---|
| 数据目录 | `userCfg.path.dataRoot` | `csCfg.project.path.dataRoot` |
| 自定义数据集 | `userCfg.general.*` | `csCfg.project.general.*` |
| 间断方式 | `userCfg.interruption.*` | `csCfg.project.interruption.*` |
| 图像网格 | `userCfg.image.*` | `csCfg.project.image.*` |
| 关闭文件输出 | `userCfg.output.enableOutput` | `csCfg.output.enableOutput` |
| 显示图窗 | `userCfg.display.*` | `csCfg.project.display.*` |
| 恢复迭代次数 | 不适用 | `csCfg.recovery.maxIter` |
| 只跑 1D/2D | 不适用 | `csCfg.method.run1D / run2D` |

## 推荐写法

主流程：

```matlab
userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/your_dataset_root');
userCfg.interruption = struct( ...
    'mode', 'random_gap', ...
    'numSegments', 5, ...
    'missingRatio', 0.07, ...
    'randomSeed', 42);

result = main_gotha_bp(userCfg);
```

恢复流程：

```matlab
csCfg = struct();
csCfg.project = struct( ...
    'path', struct('dataRoot', 'E:/path/to/your_dataset_root'));
csCfg.method = struct( ...
    'run1D', true, ...
    'run2D', false);
csCfg.recovery = struct( ...
    'maxIter', 200, ...
    'lambda1D', 0.01);

result = run_cs_echo_recovery_demo(csCfg);
```

## 严格失败

配置采用严格失败策略：

- 未知字段报错
- 错拼字段报错
- 层级不对报错
- 不会静默忽略

这样可以避免“参数没生效但自己没发现”。

## 常见错误

字段拼错：

```matlab
userCfg.display = struct('showProgess', true);
```

`showProgess` 应为 `showProgress`。

层级放错：

```matlab
userCfg.display = true;
```

`display` 应该是结构体。

恢复流程顶层字段拼错：

```matlab
csCfg.methd = struct('run1D', false);
```

`methd` 应为 `method`。

数据契约给不全：

```matlab
userCfg.general = struct( ...
    'dataFieldMap', struct('echo', 'echo_matrix'));
```

`dataFieldMap` 至少要包含 `x/y/z/echo/freq`。

## 路径解析

解析顺序固定：

1. `cfg.path.dataRoot`
2. `cfg.path.dataRootCandidates`

如果显式给了 `dataRoot`，找不到就直接报错，不会再猜其它目录。
正式实验建议始终显式设置：

```matlab
userCfg.path = struct('dataRoot', 'E:/path/to/your_dataset_root');
```

## 自定义数据集

如果不是默认 GOTCHA 格式，通常只改：

- `general.numDataFiles`
- `general.dataFilePattern`
- `general.dataVariableName`
- `general.dataFieldMap`

主流程写到 `userCfg.general`，恢复流程写到 `csCfg.project.general`。
具体格式见 [data_format_contract.md](data_format_contract.md)。

## 建议

- 第一次先只改 `path.dataRoot`
- 自定义数据集再补 `general.*`
- 先让主流程稳定，再调恢复参数
- 查字段和默认值时，看 [../config/default_config.m](../config/default_config.m) 和 [../cs_echo_recovery/cs_default_config.m](../cs_echo_recovery/cs_default_config.m)
