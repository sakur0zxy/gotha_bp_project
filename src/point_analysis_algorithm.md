# 点目标分析与旋转矫正说明

## 入口

实现位于 `point_analysis.m`：

```matlab
pointAnaResult = point_analysis(imgBP, Br, Fr, PRF, vc, squintAngle, lambda, pointAnaCfg)
```

## 主流程

1. 在整幅图中找峰值
2. 截取峰值邻域 `cut`
3. 对 `cut` 做二维频域零填充升采样，得到 `up`
4. 在 `up` 上估计倾角 `tiltDeg`
5. 按 `rotDeg = -tiltDeg` 旋转，得到 `upAligned`
6. 在 `upAligned` 上提取距离向和方位向剖面
7. 计算 PSLR、ISLR、IRW

## 倾角估计

方法基于升采样后图像的幅度：

1. 每列找峰值行坐标
2. 只取左右边缘列参与拟合
3. 用列索引和峰值行坐标做直线拟合
4. 把拟合斜率换算成倾角
5. 若 `abs(tiltDeg) < tiltApplyThresholdDeg`，则不旋转

## 常用配置

- `cutH`：切片高度
- `cutW`：切片宽度
- `upN`：升采样倍数
- `enableTiltAlign`：是否旋转矫正
- `tiltApplyThresholdDeg`：最小触发角
- `tiltEdgeFraction`：参与估角的左右边缘列比例

## 结果结构

主要字段：

- `peakInImage`
- `peakInUpSlice`
- `peakInUpSliceRaw`
- `cut`
- `upSlice`
- `upSliceRaw`
- `range`
- `azimuth`
- `raw.range`
- `raw.azimuth`
- `rotated`

## `rotated` 字段

- `enabled`
- `estimatedTiltDeg`
- `appliedRotationDeg`
- `residualTiltDeg`
- `tiltInfo`
- `residualTiltInfo`
- `resultIsPrimary`
- `resultImageSource`

## 主结果和参考结果

主输出统一基于旋转后的 `upSlice`。
未旋转结果只保存在 `upSliceRaw` 和 `raw.*` 中作对照。
