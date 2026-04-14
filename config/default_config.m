function config = default_config()
%DEFAULT_CONFIG GOTCHA BP 项目的默认配置。

%% 基础设置
config.general.useSinglePrecision = true;
config.general.numDataFiles = 9;
config.general.dataFilePattern = 'data_3dsar_pass1_az%03d_VV.mat';

%% 雷达参数
config.radar.c = 3e8;
config.radar.w0 = 2 * pi * 9.6e9;
config.radar.tau = 1e-5;
config.radar.rangeUpsampleFactor = 8;

%% 成像网格
config.image.numPixels = 512;
config.image.xLimits = [-50, 50];
config.image.yLimits = [-50, 50];

%% 间断采样
config.interruption.mode = 'random_gap';
config.interruption.numSegments = 5;
config.interruption.missingRatio = 0.07;
config.interruption.gapMinMeters = 0;
config.interruption.gapMaxMeters = 50;
config.interruption.randomSeed = [];

%% 迭代权重
config.iteration.J = 117 * 4;

%% 显示控制
config.display.showInterruptedEcho = true;
config.display.showProgress = true;
config.display.progressScale = 6;
config.display.progressUpdateInterval = 20;
config.display.outputScale = 7;

%% 输出控制
config.output.outputDirName = 'img';
config.output.filePrefix = 'gotha';
config.output.appendTimestamp = true;
config.output.timestampFormat = 'yyyyMMdd_HHmmss';
config.output.separateRunFolder = true;
config.output.runFolderPrefix = 'run';
config.output.runFolderTimestampFormat = 'yyyyMMdd_HHmmss';
config.output.savePointAnalysisMat = true;
config.output.savePointAnalysisText = true;
config.output.savePointAnalysisImage = true;
config.output.saveInterruptionText = true;
config.output.saveInterruptionImage = true;

%% 数据路径
config.path.dataRootCandidates = {'.', 'gotcha_BP'};

%% 点目标分析
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
