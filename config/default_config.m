function config = default_config()
%DEFAULT_CONFIG BP 成像实验项目的默认配置。
% 定义完整配置 schema。
% 正式实验优先通过 userCfg / csCfg 覆盖。
% 第一次上手通常先看 path、general、interruption。

%% 基础设置
% 定义“如何找到并解释原始数据”。
% 默认 GOTCHA 通常只改 path.dataRoot。
% 其它数据集再改 dataFilePattern / dataVariableName / dataFieldMap。
% true: 节省内存并减少大矩阵计算开销；false: 全程使用双精度。
config.general.useSinglePrecision = true;
% 需要顺序拼接的原始数据文件数量。
config.general.numDataFiles = 9;
% 数据文件命名模板，内部会从 1 开始逐个 sprintf。
config.general.dataFilePattern = 'data_3dsar_pass1_az%03d_VV.mat';
% .mat 文件顶层变量名，例如默认是 data。
config.general.dataVariableName = 'data';
% 左边是项目内部逻辑名，右边是原始文件里的真实字段名。
config.general.dataFieldMap = struct( ...
    'x', 'x', ...
    'y', 'y', ...
    'z', 'z', ...
    'echo', 'fp', ...
    'freq', 'freq');

%% 雷达参数
% 这些参数主要影响 BP 成像内部物理量计算。
% 除非你明确知道数据对应的雷达体制不同，否则不要随意修改。
% 电磁波传播速度，通常保持 3e8。
config.radar.c = 3e8;
% 载频角频率，对应雷达中心频率。
config.radar.w0 = 2 * pi * 9.6e9;
% 发射脉冲时宽，用于距离向参数推导。
config.radar.tau = 1e-5;
% 距离向零填充倍数；越大插值越细，但时间和内存也更高。
config.radar.rangeUpsampleFactor = 8;

%% 成像网格
% 控制最终图像的空间范围和像素数。
% 新手最常改的是 numPixels、xLimits 和 yLimits。
% 输出图像大小为 numPixels x numPixels。
config.image.numPixels = 512;
% 图像 x 方向范围，单位与轨迹坐标一致，通常是米。
config.image.xLimits = [-50, 50];
% 图像 y 方向范围，单位与轨迹坐标一致，通常是米。
config.image.yLimits = [-50, 50];

%% 间断采样
% 这一组参数决定“缺失数据是怎样人为制造出来的”。
% 恢复实验里最常调的是 mode、missingRatio 和 randomSeed。
% 缺失模式；默认 random_gap 表示随机挖掉若干连续方位段。
config.interruption.mode = 'random_gap';
% 缺失段数量，仅对按段缺失模式生效。
config.interruption.numSegments = 5;
% 总缺失比例，0.07 表示约 7% 的方位样本缺失。
config.interruption.missingRatio = 0.07;
% 单段缺口的最小长度，单位通常是米。
config.interruption.gapMinMeters = 0;
% 单段缺口的最大长度，单位通常是米。
config.interruption.gapMaxMeters = 50;
% 随机种子；空表示每次重新随机，固定数值便于复现实验。
config.interruption.randomSeed = [];

%% 迭代权重
% BP 累加时使用的迭代权重长度，通常保持默认即可。
config.iteration.J = 117 * 4;

%% 显示控制
% 只影响是否显示图窗和进度，不改变算法结果本身。
% 是否显示被间断后的回波图。
config.display.showInterruptedEcho = false;
% 是否在成像过程中显示进度图和文本进度。
config.display.showProgress = true;
% 进度图显示缩放因子，只影响图窗亮度观感。
config.display.progressScale = 6;
% 每处理多少个方位采样更新一次进度显示。
config.display.progressUpdateInterval = 20;
% 保存图像时的显示缩放因子，只影响导出图亮度。
config.display.outputScale = 7;

%% 输出控制
% 只影响是否创建目录、保存图片和文本，不影响函数返回值。
% 输出总开关；false 时不创建目录、不写文件，但仍返回结果结构体。
config.output.enableOutput = true;
% 主流程结果根目录名，相对工作区根目录创建。
config.output.outputDirName = 'img';
% 输出文件名前缀，例如 gotha_xxx.jpg。
config.output.filePrefix = 'gotha';
% 是否在单个输出文件名后追加时间戳。
config.output.appendTimestamp = true;
% 单文件时间戳格式。
config.output.timestampFormat = 'yyyyMMdd_HHmmss';
% 是否为每次运行单独创建 run_xxx 子目录。
config.output.separateRunFolder = true;
% 运行目录名前缀。
config.output.runFolderPrefix = 'run';
% 运行目录时间戳格式。
config.output.runFolderTimestampFormat = 'yyyyMMdd_HHmmss';
% 是否额外保存点目标分析 mat 结果。
config.output.savePointAnalysisMat = false;
% 是否额外保存点目标分析文字摘要。
config.output.savePointAnalysisText = false;
% 是否保存点目标分析图像。
config.output.savePointAnalysisImage = true;
% 是否保存间断布局文字说明。
config.output.saveInterruptionText = false;
% 是否保存间断布局图像。
config.output.saveInterruptionImage = true;

%% 数据路径
% 正式实验最推荐显式设置 path.dataRoot。
% 只有 dataRoot 为空时，才会回退到 dataRootCandidates。
% 显式数据根目录；一旦填写，找不到文件就直接报错，不再回退。
config.path.dataRoot = '';
% dataRoot 为空时依次尝试的候选相对路径。
config.path.dataRootCandidates = {'.', 'gotcha_BP'};

%% 点目标分析
% 这一组参数用于主瓣宽度、旁瓣等图像域分析。
% 如果你只想先跑通成像链路，可以暂时不动。
% 是否在成像后继续做点目标分析。
config.analysis.enablePointAnalysis = true;
% true: 点目标分析失败时中断主流程；false: 仅告警并继续。
config.analysis.failOnPointAnalysisError = false;
% 距离向带宽；留空时尽量从数据自动推导。
config.analysis.physics.Br = [];
% 距离向采样频率；留空时尽量从数据自动推导。
config.analysis.physics.Fr = [];
% 脉冲重复频率；留空时优先自动估计。
config.analysis.physics.PRF = [];
% 平台速度估计，用于点目标分析模型。
config.analysis.physics.vc = 120;
% 斜视角估计，单位度。
config.analysis.physics.squintAngleDeg = 25;
% 雷达波长；留空时优先根据载频推导。
config.analysis.physics.lambda = [];
% true: 优先根据轨迹间距自动估计 PRF。
config.analysis.autoDerivePRFFromTrack = true;
% 自动估计失败时使用的 PRF 兜底值。
config.analysis.defaultPRF = 1200;
% 点目标分析内部附加配置。
config.analysis.pointAnaCfg = struct( ...
    'showFigures', true, ... % 是否显示点目标分析过程图窗。
    'enableTiltAlign', true, ... % 是否尝试自动校正图像倾斜。
    'tiltApplyThresholdDeg', 0.0, ... % 倾斜角大于该阈值时才实际应用校正。
    'tiltEdgeFraction', 0.2); % 用于估计倾斜方向的边缘区域占比。
end
