function config = default_config()
%DEFAULT_CONFIG Default configuration for the GOTCHA BP project.

%% General
config.general.useSinglePrecision = true;
config.general.numDataFiles = 9;
config.general.dataFilePattern = 'data_3dsar_pass1_az%03d_VV.mat';

%% Radar
config.radar.c = 3e8;
config.radar.w0 = 2 * pi * 9.6e9;
config.radar.tau = 1e-5;
config.radar.rangeUpsampleFactor = 8;

%% Image grid
config.image.numPixels = 512;
config.image.xLimits = [-50, 50];
config.image.yLimits = [-50, 50];

%% Interruption
config.interruption.mode = 'random_gap';
config.interruption.numSegments = 5;
config.interruption.missingRatio = 0.07;
config.interruption.gapMinMeters = 0;
config.interruption.gapMaxMeters = 50;
config.interruption.randomSeed = [];

%% Iteration weights
config.iteration.J = 117 * 4;

%% Display
config.display.showInterruptedEcho = true;
config.display.showProgress = true;
config.display.progressScale = 6;
config.display.progressUpdateInterval = 20;
config.display.outputScale = 7;

%% Output
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

%% Data paths
config.path.dataRootCandidates = {'.', 'gotcha_BP'};

%% Point analysis
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
    'tiltRowPeakMinDb', -20, ...
    'tiltRowFitMinRows', 6, ...
    'tiltSearchCoarseStepDeg', 1.0, ...
    'tiltSearchMidStepDeg', 0.1, ...
    'tiltSearchFineStepDeg', 0.02, ...
    'tiltSearchMidHalfRangeDeg', 1.0, ...
    'tiltSearchFineHalfRangeDeg', 0.1, ...
    'tiltEvalPatchSize', 41, ...
    'tiltEvalDbFloor', -35, ...
    'tiltOrientDbLow', -24, ...
    'tiltOrientDbHigh', -6, ...
    'tiltOrientGamma', 1.5, ...
    'tiltPcaHalfRangeDeg', 8, ...
    'tiltResidualRefineEnable', true, ...
    'tiltResidualRefineThresholdDeg', 0.25, ...
    'tiltResidualRefineGain', 0.7, ...
    'tiltResidualRefineMaxStepDeg', 2.0, ...
    'tiltResidualMinScoreGain', 1e-4);
end
