function result = cs_recovery_pipeline(csCfg)
%CS_RECOVERY_PIPELINE 串联回波恢复、成像和点目标分析实验流程。
% 输入：
%   csCfg  恢复模块配置，通常来自 cs_default_config。
%          包含 project / method / recovery / compare / data / output 六块。
% 输出：
%   result 恢复结果、对比指标和输出文件路径。

if nargin < 1 || isempty(csCfg)
    csCfg = cs_default_config();
end

localValidateCsConfig(csCfg);

assert(~csCfg.compare.runPointAnalysis || csCfg.compare.runImaging, ...
    '启用点目标分析前必须先启用成像对比。');

paths = localSetupPaths();
projectCfg = localBuildProjectConfig(csCfg);

% 先复用主流程统一数据入口，再按 csCfg.data 可选裁剪一个更小的实验子集。
[pathInfo, trackFull, echoFull, radarFull, dataRoot] = bp_data_pipeline(projectCfg);
[track, echoRef, radar, selectInfo] = localSelectData(trackFull, echoFull, radarFull, csCfg.data);

% 根据主流程间断配置生成观测数据和掩膜；恢复算法只看 echoCut + maskObs。
[echoCut, cutInfo] = bp_interruption_pipeline(echoRef, track, projectCfg.interruption);
[maskAz, maskObs] = localBuildObservedMask(size(echoRef), cutInfo.activeAzIndices);
cutInfoFull = cs_build_full_cutinfo(track, size(echoRef, 2));
% 输出目录管理只影响文件写入，不影响恢复与成像数值结果。
runDir = localPrepareRunDir(paths.csRoot, csCfg.output);

cases = localInitCases(csCfg.method);
cases.original.echo = echoRef;
cases.interrupted.echo = echoCut;
cases.original.status = 'completed';
cases.interrupted.status = 'completed';
cases.original.echoMetrics = localBuildEchoMetrics(echoRef, echoRef, echoCut, maskObs);
cases.interrupted.echoMetrics = localBuildEchoMetrics(echoCut, echoRef, echoCut, maskObs);

if csCfg.method.run1D
    fprintf('Running 1D azimuth sparse recovery...\n');
    [cases.recovered_1d.echo, cases.recovered_1d.recoveryInfo] = ...
        cs_recover_azimuth_fft_ista(echoCut, maskObs, csCfg.recovery);
    cases.recovered_1d.echoMetrics = ...
        localBuildEchoMetrics(cases.recovered_1d.echo, echoRef, echoCut, maskObs);
    cases.recovered_1d.status = 'completed';
end

if csCfg.method.run2D
    fprintf('Running 2D echo sparse recovery...\n');
    [cases.recovered_2d.echo, cases.recovered_2d.recoveryInfo] = ...
        cs_recover_echo_fft2_ista(echoCut, maskObs, csCfg.recovery);
    cases.recovered_2d.echoMetrics = ...
        localBuildEchoMetrics(cases.recovered_2d.echo, echoRef, echoCut, maskObs);
    cases.recovered_2d.status = 'completed';
end

if csCfg.compare.runImaging
    fprintf('Running imaging comparison...\n');
    [cases.original.image, cases.original.imageInfo] = ...
        bp_imaging_pipeline(track, echoRef, radar, projectCfg, cutInfoFull);
    [cases.interrupted.image, cases.interrupted.imageInfo] = ...
        bp_imaging_pipeline(track, echoCut, radar, projectCfg, cutInfo);

    if strcmp(cases.recovered_1d.status, 'completed')
        [cases.recovered_1d.image, cases.recovered_1d.imageInfo] = ...
            bp_imaging_pipeline(track, cases.recovered_1d.echo, radar, projectCfg, cutInfoFull);
    end

    if strcmp(cases.recovered_2d.status, 'completed')
        [cases.recovered_2d.image, cases.recovered_2d.imageInfo] = ...
            bp_imaging_pipeline(track, cases.recovered_2d.echo, radar, projectCfg, cutInfoFull);
    end

    imageRef = cases.original.image;
    cases.original.imageMetrics = localBuildImageMetrics(imageRef, imageRef);
    cases.interrupted.imageMetrics = localBuildImageMetrics(cases.interrupted.image, imageRef);

    if ~isempty(cases.recovered_1d.image)
        cases.recovered_1d.imageMetrics = localBuildImageMetrics(cases.recovered_1d.image, imageRef);
    end
    if ~isempty(cases.recovered_2d.image)
        cases.recovered_2d.imageMetrics = localBuildImageMetrics(cases.recovered_2d.image, imageRef);
    end
end

if csCfg.compare.runPointAnalysis
    fprintf('Running point-target analysis comparison...\n');
    cases.original = localRunPointAnalysisCase(cases.original, projectCfg, radar, track, pathInfo, csCfg.compare, 'original');
    cases.interrupted = localRunPointAnalysisCase(cases.interrupted, projectCfg, radar, track, pathInfo, csCfg.compare, 'interrupted');
    cases.recovered_1d = localRunPointAnalysisCase(cases.recovered_1d, projectCfg, radar, track, pathInfo, csCfg.compare, 'recovered_1d');
    cases.recovered_2d = localRunPointAnalysisCase(cases.recovered_2d, projectCfg, radar, track, pathInfo, csCfg.compare, 'recovered_2d');
end

result = struct();
result.csConfig = csCfg;
result.projectConfig = projectCfg;
result.paths = struct( ...
    'csRoot', paths.csRoot, ...
    'projectRoot', paths.projectRoot, ...
    'runDir', runDir, ...
    'dataRoot', dataRoot);
result.selection = selectInfo;
result.mask = struct( ...
    'observedAzimuthMask', maskAz, ...
    'observedMatrixMask', maskObs);
result.cutInfo = struct( ...
    'interrupted', cutInfo, ...
    'full', cutInfoFull);
result.radar = radar;
result.track = track;
result.cases = cases;
result.summary = localBuildSummary(cases, cutInfo, selectInfo);
result.files = cs_save_results(result, projectCfg, csCfg, runDir);

if localIsOutputEnabled(csCfg.output)
    fprintf('CS recovery results saved to: %s\n', runDir);
end
end

function paths = localSetupPaths()
csRoot = fileparts(mfilename('fullpath'));
projectRoot = fileparts(csRoot);
addpath(projectRoot);
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
addpath(csRoot);

paths = struct();
paths.csRoot = csRoot;
paths.projectRoot = projectRoot;
end

function projectCfg = localBuildProjectConfig(csCfg)
% csCfg.project 复用主流程同一份 schema 和校验规则，避免维护并行配置体系。
projectCfg = default_config();
if isfield(csCfg, 'project') && isstruct(csCfg.project) && ~isempty(csCfg.project)
    projectCfg = bp_merge_config(projectCfg, csCfg.project);
end
projectCfg = bp_validate_config(projectCfg);
end

function [trackOut, echoOut, radarOut, selectInfo] = localSelectData(trackIn, echoIn, radarIn, dataCfg)
% 这里的裁剪只用于小规模实验、快速调参或测试，不改变数据契约本身。
rangeIdx = localResolveIndexRange(dataCfg.rangeIndexRange, size(echoIn, 1));
azIdx = localResolveIndexRange(dataCfg.azimuthIndexRange, size(echoIn, 2));

echoOut = echoIn(rangeIdx, azIdx);
trackOut = struct();
trackOut.X = trackIn.X(azIdx);
trackOut.Y = trackIn.Y(azIdx);
trackOut.Z = trackIn.Z(azIdx);

radarOut = radarIn;
if numel(rangeIdx) ~= size(echoIn, 1)
    radarOut = localCropRadar(radarIn, rangeIdx);
end

selectInfo = struct();
selectInfo.rangeIndices = rangeIdx;
selectInfo.azimuthIndices = azIdx;
selectInfo.numRangeSamples = numel(rangeIdx);
selectInfo.numAzimuthSamples = numel(azIdx);
selectInfo.rangeCropped = numel(rangeIdx) ~= size(echoIn, 1);
selectInfo.azimuthCropped = numel(azIdx) ~= size(echoIn, 2);
end

function idx = localResolveIndexRange(rawValue, maxCount)
if isempty(rawValue)
    idx = 1:maxCount;
    return;
end

if islogical(rawValue)
    assert(numel(rawValue) == maxCount, '逻辑索引长度与数据长度不一致。');
    idx = find(rawValue(:).');
else
    idx = double(rawValue(:).');
    if numel(idx) == 2 && all(idx == round(idx)) && idx(1) <= idx(2)
        idx = idx(1):idx(2);
    end
end

assert(~isempty(idx), '索引范围不能为空。');
assert(all(isfinite(idx)) && all(idx == round(idx)), '索引必须是有限整数。');
assert(all(idx >= 1 & idx <= maxCount), '索引超出有效范围。');
idx = unique(idx, 'stable');
end

function radarOut = localCropRadar(radarIn, rangeIdx)
radarOut = radarIn;
freqVec = radarIn.freqVectorHz(:).';
if ~isempty(freqVec)
    freqVec = freqVec(rangeIdx);
end

numRange = numel(rangeIdx);
upFactor = round(double(radarIn.numRangeSamplesUp) / double(radarIn.numRangeSamples));
if upFactor < 1
    upFactor = 1;
end

radarOut.freqVectorHz = freqVec;
radarOut.numRangeSamples = numRange;
radarOut.numRangeSamplesUp = upFactor * numRange;
radarOut.Ts = radarIn.tau / numRange;

if isempty(freqVec)
    radarOut.firstFreq = NaN;
    radarOut.freqStepHz = NaN;
    radarOut.bandwidthHz = NaN;
    radarOut.y0 = radarIn.y0;
    radarOut.deltaR = radarIn.deltaR;
    return;
end

radarOut.firstFreq = freqVec(1);
if numel(freqVec) >= 2
    radarOut.freqStepHz = mean(diff(freqVec));
    radarOut.bandwidthHz = abs(freqVec(end) - freqVec(1));
else
    radarOut.freqStepHz = NaN;
    radarOut.bandwidthHz = NaN;
end

radarOut.y0 = (radarOut.w0 - radarOut.firstFreq * 2 * pi) / radarOut.tau * 2;
radarOut.deltaR = radarOut.c * pi / (radarOut.y0 * radarOut.Ts * radarOut.numRangeSamplesUp);
end

function [maskAz, maskObs] = localBuildObservedMask(dataSize, activeAzIndices)
% maskAz 描述哪些方位位置被观测到，maskObs 是扩展到整幅回波后的二维掩膜。
maskAz = false(1, dataSize(2));
maskAz(activeAzIndices) = true;
maskObs = repmat(maskAz, dataSize(1), 1);
end

function runDir = localPrepareRunDir(csRoot, outputCfg)
if ~localIsOutputEnabled(outputCfg)
    runDir = '';
    return;
end

baseDir = fullfile(csRoot, outputCfg.resultsDirName);
localEnsureDir(baseDir);

timeStamp = char(datetime('now', 'Format', outputCfg.timestampFormat));
runName = sprintf('%s_%s', outputCfg.runFolderPrefix, timeStamp);
runDir = fullfile(baseDir, runName);

suffix = 1;
while exist(runDir, 'dir') == 7
    runDir = fullfile(baseDir, sprintf('%s_%02d', runName, suffix));
    suffix = suffix + 1;
end
mkdir(runDir);
end

function localValidateCsConfig(csCfg)
assert(isfield(csCfg, 'output') && isstruct(csCfg.output), ...
    'csCfg.output 必须是结构体。');
assert(isfield(csCfg.output, 'enableOutput') ...
    && islogical(csCfg.output.enableOutput) ...
    && isscalar(csCfg.output.enableOutput), ...
    'csCfg.output.enableOutput 必须是逻辑标量。');
end

function tf = localIsOutputEnabled(outputCfg)
tf = true;
if isstruct(outputCfg) && isfield(outputCfg, 'enableOutput')
    tf = outputCfg.enableOutput;
end
end

function localEnsureDir(dirPath)
if exist(dirPath, 'dir') ~= 7
    mkdir(dirPath);
end
end

function cases = localInitCases(methodCfg)
cases = struct();
cases.original = localEmptyCase('original', true);
cases.interrupted = localEmptyCase('interrupted', true);
cases.recovered_1d = localEmptyCase('recovered_1d', methodCfg.run1D);
cases.recovered_2d = localEmptyCase('recovered_2d', methodCfg.run2D);
end

function caseInfo = localEmptyCase(name, enabled)
caseInfo = struct();
caseInfo.name = name;
caseInfo.enabled = enabled;
if enabled
    caseInfo.status = 'pending';
else
    caseInfo.status = 'skipped';
end
caseInfo.echo = [];
caseInfo.echoMetrics = [];
caseInfo.recoveryInfo = struct();
caseInfo.image = [];
caseInfo.imageInfo = struct();
caseInfo.imageMetrics = [];
caseInfo.pointAnalysis = [];
caseInfo.pointMeta = struct('enabled', false);
end

function metrics = localBuildEchoMetrics(echoNow, echoRef, echoObserved, maskObs)
maskMiss = ~maskObs;
metrics = struct();
metrics.wholeRelErr = localRelativeError(echoNow, echoRef);

if any(maskMiss(:))
    refMiss = echoRef(maskMiss);
    nowMiss = echoNow(maskMiss);
    metrics.missingRelErr = localRelativeError(nowMiss, refMiss);
else
    metrics.missingRelErr = 0;
end

obsRef = echoObserved(maskObs);
obsNow = echoNow(maskObs);
metrics.observedConsistencyErr = localRelativeError(obsNow, obsRef);
metrics.maxObservedAbsErr = localMaxAbsError(obsNow, obsRef);
metrics.observedFraction = nnz(maskObs) / numel(maskObs);
metrics.missingFraction = 1 - metrics.observedFraction;
end

function metrics = localBuildImageMetrics(imageNow, imageRef)
ampNow = abs(imageNow);
ampRef = abs(imageRef);
metrics = struct();
metrics.amplitudeRelErr = localRelativeError(ampNow, ampRef);
metrics.peakAmplitude = max(ampNow(:));
metrics.meanAmplitude = mean(ampNow(:));
end

function caseInfo = localRunPointAnalysisCase(caseInfo, projectCfg, radar, track, pathInfo, compareCfg, caseName)
if isempty(caseInfo.image) || ~caseInfo.enabled || strcmp(caseInfo.status, 'skipped')
    return;
end

try
    [caseInfo.pointAnalysis, caseInfo.pointMeta] = ...
        bp_run_point_analysis(caseInfo.image, projectCfg, radar, track, pathInfo);
    caseInfo.pointMeta.enabled = true;
catch err
    caseInfo.pointMeta = struct( ...
        'enabled', false, ...
        'errorMessage', err.message, ...
        'caseName', caseName);
    warning('cs_recovery_pipeline:PointAnalysisFailed', ...
        'Point analysis failed for %s: %s', caseName, err.message);
    if compareCfg.failOnPointAnalysisError
        rethrow(err);
    end
end
end

function summary = localBuildSummary(cases, cutInfo, selectInfo)
summary = struct();
summary.numRangeSamples = selectInfo.numRangeSamples;
summary.numAzimuthSamples = selectInfo.numAzimuthSamples;
summary.interruptionMode = cutInfo.mode;
summary.numSegments = cutInfo.numSegments;
summary.missingRatio = cutInfo.missingRatio;
summary.totalMissingSamples = cutInfo.totalMissingSamples;
summary.totalValidSamples = cutInfo.totalValidSamples;
summary.caseNames = fieldnames(cases);
end

function relErr = localRelativeError(valueNow, valueRef)
den = norm(double(valueRef(:)));
if den <= eps
    relErr = norm(double(valueNow(:) - valueRef(:)));
else
    relErr = norm(double(valueNow(:) - valueRef(:))) / den;
end
end

function maxErr = localMaxAbsError(valueNow, valueRef)
diffValue = abs(valueNow(:) - valueRef(:));
if isempty(diffValue)
    maxErr = 0;
else
    maxErr = max(diffValue);
end
end
