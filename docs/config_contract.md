# 配置契约说明

本项目的正式配置契约适用于两个入口：

- `main_gotha_bp.m`
- `cs_echo_recovery/run_cs_echo_recovery_demo.m`

核心原则只有一条：**实验参数通过配置覆盖调整，不通过修改生产源码调整。**

## 1. 严格失败语义

配置覆盖采用严格失败策略：

- 未知字段立即报错
- 错拼字段立即报错
- 错误层级立即报错
- 不会静默忽略配置
- 不会自动回退成“看起来还能跑”的宽松模式

错误信息必须同时包含：

- 错误位置
- 错误原因

例如：

- `cfg.display.showProgess`
  说明：字段名拼错，程序会明确指出该路径不存在。
- `cfg.display = true`
  说明：默认这里是结构体，若用户用标量覆盖，会被识别为层级类型不匹配。

## 2. 主流程配置覆盖

主流程入口：

```matlab
result = main_gotha_bp(userCfg);
```

最常用的主流程覆盖位置包括：

- `userCfg.path`
- `userCfg.interruption`
- `userCfg.display`
- `userCfg.analysis`
- `userCfg.output`

### 合法示例

```matlab
userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/gotcha_BP');
userCfg.display = struct('showProgress', true);
userCfg.analysis = struct('pointAnaCfg', struct('showFigures', true));

result = main_gotha_bp(userCfg);
```

### 非法示例：错拼字段

```matlab
userCfg = struct();
userCfg.display = struct('showProgess', true);

result = main_gotha_bp(userCfg);
```

期望行为：

- 立即失败
- 错误路径包含 `cfg.display.showProgess`

### 非法示例：错误层级

```matlab
userCfg = struct();
userCfg.display = true;

result = main_gotha_bp(userCfg);
```

期望行为：

- 立即失败
- 错误原因说明默认值是 `struct`，用户覆盖不是 `struct`

## 3. 恢复流程配置覆盖

恢复入口：

```matlab
result = run_cs_echo_recovery_demo(csCfg);
```

恢复流程配置由两部分组成：

1. `csCfg.project`
   说明：传递给主流程的配置覆盖，例如数据路径、间断参数、显示参数。
2. `csCfg.method / compare / recovery / data / output`
   说明：恢复模块自身的配置。

### 合法示例

```matlab
csCfg = struct();
csCfg.project = struct( ...
    'path', struct('dataRoot', 'E:/path/to/gotcha_BP'));
csCfg.method = struct('run1D', true, 'run2D', false);

result = run_cs_echo_recovery_demo(csCfg);
```

### 非法示例：顶层错拼字段

```matlab
csCfg = struct();
csCfg.methd = struct('run1D', false);

result = run_cs_echo_recovery_demo(csCfg);
```

期望行为：

- 立即失败
- 错误路径包含 `cfg.methd`

## 4. 数据路径规则

现在的数据路径解析顺序是：

1. `cfg.path.dataRoot`
2. `cfg.path.dataRootCandidates`

解释如下：

- 如果 `cfg.path.dataRoot` 非空，则优先使用它。
- 如果显式路径错误，不会回退到 `dataRootCandidates`。
- 只有 `cfg.path.dataRoot` 为空时，才会启用候选目录查找。

### 推荐写法

```matlab
userCfg = struct();
userCfg.path = struct('dataRoot', 'E:/path/to/gotcha_BP');
```

### 显式路径错误时的期望行为

```matlab
userCfg = struct();
userCfg.path = struct('dataRoot', 'definitely_missing_path');
```

期望行为：

- 立即失败
- 错误信息指出显式路径
- 错误信息指出缺失的首个必需文件
- 错误信息说明不会回退到 `cfg.path.dataRootCandidates`

## 5. headless 默认值

正式主流程默认值现在偏向批处理：

- `config.display.showInterruptedEcho = false`
- `config.display.showProgress = false`
- `config.analysis.pointAnaCfg.showFigures = false`

这不影响正式输出的保存：

- 成像图仍可保存
- 点目标分析文本仍可保存
- 点目标分析图片在 `savePointAnalysisImage=true` 时仍可保存

如果你在 notebook 或手工调试时需要看图，可以显式打开：

```matlab
userCfg = struct();
userCfg.display = struct( ...
    'showInterruptedEcho', true, ...
    'showProgress', true);
userCfg.analysis = struct( ...
    'pointAnaCfg', struct('showFigures', true));
```

## 6. notebook 的角色

`main_gotha_bp.ipynb` 只是交互式 wrapper：

- 准备路径
- 允许你在 cell 里编辑 `userCfg`
- 调用 `main_gotha_bp(userCfg)`

不要在 notebook 中再维护一份主流程函数体。正式逻辑只能保留在：

- `main_gotha_bp.m`

## 7. 产物与版本控制

运行产物默认不纳入版本控制：

- `/img/`
- `/cs_echo_recovery/results/`

应纳入版本控制的是：

- 代码
- 文档
- 默认配置
- 最小示例

不应作为日常提交内容的是：

- 大量 `.mat`
- 大量 `.jpg`
- 大量 `.txt` 实验输出

## 8. 推荐工作流

### 主流程

1. 构造 `userCfg`
2. 显式设置 `userCfg.path.dataRoot`
3. 用覆盖字段调整实验参数
4. 调用 `main_gotha_bp(userCfg)`

### 恢复流程

1. 构造 `csCfg`
2. 在 `csCfg.project.path.dataRoot` 中设置数据根目录
3. 在 `csCfg.project` 中覆盖主流程参数
4. 在 `csCfg.recovery / method / compare / data / output` 中覆盖恢复参数
5. 调用 `run_cs_echo_recovery_demo(csCfg)`

## 9. 一条底线

如果你发现自己准备直接修改：

- `config/default_config.m`
- `cs_echo_recovery/cs_default_config.m`
- `main_gotha_bp.m`
- `run_cs_echo_recovery_demo.m`

只是为了换一个实验参数，那通常说明你没有先走配置覆盖这条正式路径。优先把调整写进 `userCfg` 或 `csCfg`。
