function config = default_config()
%DEFAULT_CONFIG BP 成像实验项目的默认配置。
% 说明：
% 1. 这份文件定义项目支持的完整配置 schema。
% 2. 正式实验推荐在 userCfg / csCfg 中覆盖，而不是直接修改这里。
% 3. 第一次上手时，大多数人只需要先看 path、general 和 interruption 三块。

%% 基础设置
% 下面几项共同定义“如何从磁盘找到并解释原始数据”。
% 如果你使用默认 GOTCHA 数据，通常只需要改 path.dataRoot。
% 如果你使用自己的数据集，再继续改 dataFilePattern / dataVariableName / dataFieldMap。
config.general.useSinglePrecision = true;
config.general.numDataFiles = 9;
config.general.dataFilePattern = 'data_3dsar_pass1_az%03d_VV.mat';
config.general.dataVariableName = 'data';
config.general.dataFieldMap = struct( ...
    'x', 'x', ...
    'y', 'y', ...
    'z', 'z', ...
    'echo', 'fp', ...
    'freq', 'freq');

%% 雷达参数
% 这些参数主要影响 BP 成像内部物理量计算。
% 除非你明确知道数据对应的雷达体制不同，否则不要随意修改。
config.radar.c = 3e8;
config.radar.w0 = 2 * pi * 9.6e9;
config.radar.tau = 1e-5;
config.radar.rangeUpsampleFactor = 8;

%% 成像网格
% 控制最终图像的空间范围和像素数。
% 新手最常改的是 numPixels、xLimits 和 yLimits。
config.image.numPixels = 512;
config.image.xLimits = [-50, 50];
config.image.yLimits = [-50, 50];

%% 间断采样
% 这一组参数决定“缺失数据是怎样人为制造出来的”。
% 恢复实验里最常调的是 mode、missingRatio 和 randomSeed。
config.interruption.mode = 'random_gap';
config.interruption.numSegments = 5;
config.interruption.missingRatio = 0.07;
config.interruption.gapMinMeters = 0;
config.interruption.gapMaxMeters = 50;
config.interruption.randomSeed = [];

%% 迭代权重
config.iteration.J = 117 * 4;

%% 显示控制
% 只影响是否显示图窗和进度，不改变算法结果本身。
config.display.showInterruptedEcho = false;
config.display.showProgress = true;
config.display.progressScale = 6;
config.display.progressUpdateInterval = 20;
config.display.outputScale = 7;

%% 输出控制
% 只影响是否创建目录、保存图片和文本，不影响函数返回值。
config.output.enableOutput = true;
config.output.outputDirName = 'img';
config.output.filePrefix = 'gotha';
config.output.appendTimestamp = true;
config.output.timestampFormat = 'yyyyMMdd_HHmmss';
config.output.separateRunFolder = true;
config.output.runFolderPrefix = 'run';
config.output.runFolderTimestampFormat = 'yyyyMMdd_HHmmss';
config.output.savePointAnalysisMat = false;
config.output.savePointAnalysisText = false;
config.output.savePointAnalysisImage = true;
config.output.saveInterruptionText = false;
config.output.saveInterruptionImage = true;

%% 数据路径
% 正式实验最推荐显式设置 path.dataRoot。
% 只有 dataRoot 为空时，才会回退到 dataRootCandidates。
config.path.dataRoot = '';
config.path.dataRootCandidates = {'.', 'gotcha_BP'};

%% 点目标分析
% 这一组参数用于主瓣宽度、旁瓣等图像域分析。
% 如果你只想先跑通成像链路，可以暂时不动。
config.analysis.enablePointAnalysis = true;
config.analysis.failOnPointAnalysisError = false;
config.analysis.physics.Br = [];
config.analysis.physics.Fr = [];
config.analysis.physics.PRF = [];
config.analysis.physics.vc = 120;
config.analysis.physics.squintAngleDeg = 25;
config.analysis.physics.lambda = [];
config.analysis.autoDerivePRFFromTrack = true;
config.analysis.defaultPRF = 1200;
config.analysis.pointAnaCfg = struct( ...
    'showFigures', true, ...
    'enableTiltAlign', true, ...
    'tiltApplyThresholdDeg', 0.0, ...
    'tiltEdgeFraction', 0.2);
end
