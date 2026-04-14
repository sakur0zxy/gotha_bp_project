# 点目标分析与旋转矫正说明

## 入口
点目标分析实现位于 `point_analysis.m`，函数入口为：

```matlab
pointAnaResult = point_analysis(imgBP, Br, Fr, PRF, vc, squintAngle, lambda, pointAnaCfg)
```

输入包括成像结果、带宽和采样相关物理量，以及可选配置 `pointAnaCfg`。输出为结构体 `pointAnaResult`。

## 主处理流程
当前实现按以下顺序执行：

1. 在整幅成像结果中定位峰值点。
2. 以峰值为中心提取固定大小的点目标切片 `cut`。
3. 对 `cut` 做二维频域零填充升采样，得到 `up`。
4. 在 `up` 上估计目标倾角 `tiltDeg`。
5. 计算旋转角 `rotDeg = -tiltDeg`，对 `up` 旋转得到 `upAligned`。
6. 在 `upAligned` 上再次估计残余角，用于诊断旋转效果。
7. 基于 `upAligned` 提取距离向和方位向剖面，并计算 PSLR、ISLR、IRW。

## 当前倾角估计方法
倾角估计基于升采样后的复图像幅度：

1. 逐列寻找最大幅度点所在的行坐标。
2. 只保留左右边缘列，中间列不参与拟合。
3. 以列索引为自变量、峰值行坐标为因变量做直线拟合。
4. 将拟合斜率换算为倾角 `tiltDeg`。
5. 若 `abs(tiltDeg)` 小于 `tiltApplyThresholdDeg`，则不执行旋转。

相关配置项：

- `cutH`：切片高度
- `cutW`：切片宽度
- `upN`：升采样倍数
- `enableTiltAlign`：是否启用旋转矫正
- `tiltApplyThresholdDeg`：最小触发角度
- `tiltEdgeFraction`：左右边缘列所占比例

## 结果结构
`pointAnaResult` 的主要字段如下：

- `peakInImage`：原始成像图中的峰值位置
- `peakInUpSlice`：旋转后的升采样图峰值位置
- `peakInUpSliceRaw`：未旋转升采样图峰值位置
- `cut`：原始点目标切片
- `upSlice`：旋转后的升采样图，是主分析数据源
- `upSliceRaw`：未旋转的升采样图，仅作参考
- `range`：旋转后距离向剖面与指标
- `azimuth`：旋转后方位向剖面与指标
- `raw.range`：未旋转距离向参考结果
- `raw.azimuth`：未旋转方位向参考结果
- `rotated`：旋转相关信息

## 旋转信息
`pointAnaResult.rotated` 中包含：

- `enabled`：是否启用旋转矫正
- `estimatedTiltDeg`：估计得到的原始倾角
- `appliedRotationDeg`：实际应用的旋转角
- `residualTiltDeg`：旋转后的残余角
- `tiltInfo`：主估角诊断信息
- `residualTiltInfo`：残余角诊断信息
- `resultIsPrimary`：主结果标记
- `resultImageSource`：主结果图像来源说明

## 主结果与参考结果
主输出统一基于旋转后的 `upSlice`：

- 距离向剖面
- 方位向剖面
- PSLR
- ISLR
- IRW
- `point_analysis_upslice.jpg`
- `point_analysis_contour.jpg`
- `point_analysis_range_profile.jpg`
- `point_analysis_azimuth_profile.jpg`

未旋转结果只保存在 `upSliceRaw` 和 `raw.*` 字段中，用于对照，不参与主输出。
