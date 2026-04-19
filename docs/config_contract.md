# 配置修改指南

这份文档回答的是一个很实际的问题：  
当你想改实验参数时，到底应该改哪里，哪些改法是正式做法，哪些改法会被项目立即拒绝。

## 1. 先记住一条总原则

正式实验里，参数应当通过配置覆盖传入，而不是直接修改生产源码。

也就是说，优先改：

- `userCfg`
- `csCfg`

不优先改：

- `config/default_config.m`
- `cs_echo_recovery/cs_default_config.m`
- `main_gotha_bp.m`
- `cs_echo_recovery/run_cs_echo_recovery_demo.m`

默认配置文件的角色是“项目默认 schema”，不是“每次实验都去手改的参数文件”。

## 2. 配置从哪里进入项目

项目有两个正式入口，对应两套覆盖入口：

### 主流程

```matlab
result = main_gotha_bp(userCfg);
```

这里的 `userCfg` 会覆盖 `config/default_config.m` 中的默认值。

### 恢复流程

```matlab
result = run_cs_echo_recovery_demo(csCfg);
```

这里的 `csCfg` 分两层：

1. `csCfg.project`
   说明：传给主流程的配置覆盖
2. `csCfg.method / recovery / compare / data / output`
   说明：恢复流程自己使用的配置

可以把它简单理解成：

- `csCfg.project` 管“主流程怎么跑”
- `csCfg.recovery` 管“恢复算法怎么跑”

## 3. 你最常改的字段

下面这张表对应最常见的实验需求。

| 你要做的事 | 主流程怎么改 | 恢复流程怎么改 |
|---|---|---|
| 指定数据目录 | `userCfg.path.dataRoot` | `csCfg.project.path.dataRoot` |
| 接入自定义数据集 | `userCfg.general.*` | `csCfg.project.general.*` |
| 调整间断方式 | `userCfg.interruption.*` | `csCfg.project.interruption.*` |
| 调整图像大小 | `userCfg.image.*` | `csCfg.project.image.*` |
| 关闭文件输出 | `userCfg.output.enableOutput` | `csCfg.output.enableOutput` |
| 打开图窗显示 | `userCfg.display.*` | `csCfg.project.display.*` |
| 调整恢复迭代次数 | 不适用 | `csCfg.recovery.maxIter` |
| 只跑 1D 或 2D 恢复 | 不适用 | `csCfg.method.run1D / run2D` |

## 4. 最推荐的写法

### 主流程推荐模板

```matlab
userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/your_dataset_root');

result = main_gotha_bp(userCfg);
```

如果要调更多参数，就继续往 `userCfg` 里补字段：

```matlab
userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/your_dataset_root');
userCfg.interruption = struct( ...
    'mode', 'random_gap', ...
    'numSegments', 5, ...
    'missingRatio', 0.07, ...
    'randomSeed', 42);
userCfg.output = struct('enableOutput', true);

result = main_gotha_bp(userCfg);
```

### 恢复流程推荐模板

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

## 5. 严格失败语义是什么意思

本项目对配置采用严格失败策略。  
这不是“麻烦”，而是为了减少科研实验里那种“参数没生效但你自己没发现”的风险。

严格失败意味着：

- 未知字段立即报错
- 错拼字段立即报错
- 层级不对立即报错
- 不会静默忽略
- 不会偷偷回退到某个宽松默认行为

## 6. 哪些写法会被立即拒绝

### 情况 A：字段名拼错

```matlab
userCfg = struct();
userCfg.display = struct('showProgess', true);
```

这里 `showProgess` 拼错了。  
正确字段是 `showProgress`。

### 情况 B：层级放错

```matlab
userCfg = struct();
userCfg.display = true;
```

这里 `display` 应该是一个结构体，不是单个逻辑值。

### 情况 C：恢复流程顶层字段拼错

```matlab
csCfg = struct();
csCfg.methd = struct('run1D', false);
```

这里 `methd` 拼错了。  
正确字段是 `method`。

### 情况 D：只给了半套自定义数据契约

```matlab
userCfg = struct();
userCfg.general = struct( ...
    'dataFieldMap', struct('echo', 'echo_matrix'));
```

这会失败，因为 `dataFieldMap` 必须至少包含：

- `x`
- `y`
- `z`
- `echo`
- `freq`

## 7. 路径配置怎么理解

数据路径解析顺序固定如下：

1. `cfg.path.dataRoot`
2. `cfg.path.dataRootCandidates`

解释：

- 如果你显式提供了 `dataRoot`，项目只会相信这个路径
- 如果这个路径不对，项目会立即报错
- 它不会再自动去猜别的目录
- 只有当 `dataRoot` 为空时，才会遍历候选目录

因此，正式实验最推荐的写法始终是：

```matlab
userCfg.path = struct('dataRoot', 'E:/path/to/your_dataset_root');
```

## 8. 自定义数据集应该改哪里

如果你的数据不是默认 GOTCHA 格式，需要改下面这些字段：

- `general.numDataFiles`
- `general.dataFilePattern`
- `general.dataVariableName`
- `general.dataFieldMap`

主流程写在：

```matlab
userCfg.general = struct(...);
```

恢复流程写在：

```matlab
csCfg.project.general = struct(...);
```

字段具体怎么填，见 [data_format_contract.md](data_format_contract.md)。

## 9. 几个很有用的配置习惯

### 习惯 1：先只改最少字段

第一次跑项目时，先只改：

- `path.dataRoot`

如果是自定义数据集，再加：

- `general.*`

不要一开始就同时调很多参数。

### 习惯 2：把实验差异都写进 `userCfg` / `csCfg`

这样你以后回看脚本时，一眼就知道这次实验和默认配置差在哪里。

### 习惯 3：先让主流程稳定，再调恢复参数

恢复流程更长，出问题时更难定位。  
先保证主流程输出稳定，后面调恢复会轻松很多。

## 10. 什么时候应该看默认配置文件

默认配置文件更适合拿来做三件事：

1. 查当前项目支持哪些字段
2. 查某个字段的默认值
3. 理解配置树长什么样

对应文件是：

- [../config/default_config.m](../config/default_config.m)
- [../cs_echo_recovery/cs_default_config.m](../cs_echo_recovery/cs_default_config.m)

## 11. 如果你只想记住一句话

每次实验都新建或修改 `userCfg` / `csCfg`，不要为了改参数直接改算法源码。  
如果项目拒绝你的配置，优先相信报错信息，因为它通常已经指出了真实问题所在。
