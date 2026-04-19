function [pathInfo, track, echoData, radar, dataRoot] = bp_data_pipeline(cfg)
%BP_DATA_PIPELINE 初始化路径并加载轨迹、回波和雷达参数。
% 输入：
%   cfg       运行配置。
% 输出：
%   pathInfo  路径上下文。
%   track     轨迹数据。
%   echoData  回波矩阵。
%   radar     雷达参数。
%   dataRoot  数据根目录。
%
% 这是项目唯一的原始数据入口。它负责做两件事：
% 1. 根据路径配置找到数据文件；
% 2. 把不同数据集的变量名/字段名统一整理成内部标准表示。
%
% 后续 BP 成像和恢复流程都只依赖 track / echoData / radar，
% 不再关心原始 .mat 文件里实际使用的命名方式。

pathInfo = localSetupPaths();
dataRoot = localFindDataRoot(cfg, pathInfo);
[track, echoData, radar] = localLoadData(cfg, dataRoot);
end

function context = localSetupPaths()
thisFile = mfilename('fullpath');
srcRoot = fileparts(thisFile);
projectRoot = fileparts(srcRoot);
workspaceRoot = fileparts(projectRoot);

context = struct();
context.srcRoot = srcRoot;
context.projectRoot = projectRoot;
context.workspaceRoot = workspaceRoot;
end

function dataRoot = localFindDataRoot(cfg, context)
firstFileName = sprintf(cfg.general.dataFilePattern, 1);

if ~isempty(cfg.path.dataRoot)
    dataRoot = localResolveDataRoot(cfg.path.dataRoot, context.workspaceRoot);
    candidateFile = fullfile(dataRoot, firstFileName);
    if exist(candidateFile, 'file') ~= 2
        error('bp_data_pipeline:ExplicitDataRootMissing', ...
            '显式数据根目录 %s 中未找到数据文件 %s；不会回退到 cfg.path.dataRootCandidates。', ...
            dataRoot, firstFileName);
    end
    return;
end

candidateRelPaths = cfg.path.dataRootCandidates;

dataRoot = '';
for idx = 1:numel(candidateRelPaths)
    candidateRoot = localResolveDataRoot(candidateRelPaths{idx}, context.workspaceRoot);
    candidateFile = fullfile(candidateRoot, firstFileName);
    if exist(candidateFile, 'file') == 2
        dataRoot = candidateRoot;
        break;
    end
end

if isempty(dataRoot)
    error('bp_data_pipeline:DataRootNotFound', ...
        '未找到数据文件 %s。请设置 cfg.path.dataRoot，或检查 cfg.path.dataRootCandidates。', ...
        firstFileName);
end
end

function dataRoot = localResolveDataRoot(rawPath, workspaceRoot)
pathText = char(string(rawPath));
if localIsAbsolutePath(pathText)
    dataRoot = pathText;
else
    dataRoot = fullfile(workspaceRoot, pathText);
end
end

function tf = localIsAbsolutePath(pathText)
tf = startsWith(pathText, '\') || startsWith(pathText, '/') ...
    || ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]', 'once'));
end

function [track, echoData, radar] = localLoadData(cfg, dataRoot)
numFiles = cfg.general.numDataFiles;
% datasetContract 是“原始文件如何映射到内部标准字段”的配置摘要。
datasetContract = localResolveDatasetContract(cfg);
xCells = cell(1, numFiles);
yCells = cell(1, numFiles);
zCells = cell(1, numFiles);
echoCells = cell(1, numFiles);

firstFreqVec = [];

for fileIdx = 1:numFiles
    dataFile = fullfile(dataRoot, sprintf(cfg.general.dataFilePattern, fileIdx));
    assert(exist(dataFile, 'file') == 2, '数据文件不存在：%s', dataFile);

    sample = localLoadSingleFile(dataFile, datasetContract);

    if fileIdx == 1
        firstFreqVec = sample.freq;
    else
        localValidateFrequencyConsistency(sample.freq, firstFreqVec, dataFile);
    end

    xCells{fileIdx} = sample.x;
    yCells{fileIdx} = sample.y;
    zCells{fileIdx} = sample.z;
    echoCells{fileIdx} = sample.echo;
end

track = struct();
track.X = [xCells{:}];
track.Y = [yCells{:}];
track.Z = [zCells{:}];

echoData = [echoCells{:}];

numAzSamples = numel(track.X);
assert(numel(track.Y) == numAzSamples && numel(track.Z) == numAzSamples, ...
    '轨迹长度不一致。');
assert(size(echoData, 2) == numAzSamples, ...
    '回波矩阵的方位向长度与轨迹长度不一致。');

radar = localBuildRadarParams(cfg, size(echoData, 1), firstFreqVec);
end

function contract = localResolveDatasetContract(cfg)
fieldMap = cfg.general.dataFieldMap;
contract = struct();
contract.variableName = char(string(cfg.general.dataVariableName));
% 左边是项目内部逻辑名，右边是原始数据文件里的真实字段名。
contract.fieldMap = struct( ...
    'x', char(string(fieldMap.x)), ...
    'y', char(string(fieldMap.y)), ...
    'z', char(string(fieldMap.z)), ...
    'echo', char(string(fieldMap.echo)), ...
    'freq', char(string(fieldMap.freq)));
end

function sample = localLoadSingleFile(dataFile, contract)
loaded = load(dataFile);
variableName = contract.variableName;

if ~isfield(loaded, variableName)
    error('bp_data_pipeline:MissingDatasetVariable', ...
        ['数据文件 %s 缺少顶层变量 "%s"。' ...
        '请检查 cfg.general.dataVariableName 是否与数据实际变量名一致。'], ...
        dataFile, variableName);
end

dataStruct = loaded.(variableName);
if ~isstruct(dataStruct) || ~isscalar(dataStruct)
    error('bp_data_pipeline:InvalidDatasetVariable', ...
        '数据文件 %s 中的变量 "%s" 必须是标量 struct。', ...
        dataFile, variableName);
end

missingFields = localFindMissingFields(dataStruct, contract.fieldMap);
if ~isempty(missingFields)
    error('bp_data_pipeline:MissingDatasetFields', ...
        ['数据文件 %s 中的变量 "%s" 缺少必需字段：%s。' ...
        '请检查 cfg.general.dataFieldMap 与数据实际字段名是否一致。'], ...
        dataFile, variableName, strjoin(missingFields, ', '));
end

sample = struct();
sample.x = dataStruct.(contract.fieldMap.x);
sample.y = dataStruct.(contract.fieldMap.y);
sample.z = dataStruct.(contract.fieldMap.z);
sample.echo = dataStruct.(contract.fieldMap.echo);
sample.freq = dataStruct.(contract.fieldMap.freq);

sample = localValidateAndNormalizeSample(sample, dataFile);
end

function missingFields = localFindMissingFields(dataStruct, fieldMap)
mapKeys = fieldnames(fieldMap);
missingFields = {};

for idx = 1:numel(mapKeys)
    key = mapKeys{idx};
    mappedField = fieldMap.(key);
    if ~isfield(dataStruct, mappedField)
        missingFields{end + 1} = sprintf('%s->%s', key, mappedField); %#ok<AGROW>
    end
end
end

function sample = localValidateAndNormalizeSample(sample, dataFile)
% 这里把各种输入形状统一成项目内部习惯使用的行向量/二维矩阵格式，
% 并在最靠近数据入口的位置尽早发现尺寸问题。
xVec = localNormalizeTrackVector(sample.x, 'x', dataFile);
yVec = localNormalizeTrackVector(sample.y, 'y', dataFile);
zVec = localNormalizeTrackVector(sample.z, 'z', dataFile);
freqVec = localNormalizeFrequencyVector(sample.freq, dataFile);
echoMat = localNormalizeEchoMatrix(sample.echo, dataFile);

numAzSamples = numel(xVec);
if numel(yVec) ~= numAzSamples || numel(zVec) ~= numAzSamples
    error('bp_data_pipeline:TrackLengthMismatch', ...
        ['数据文件 %s 的轨迹字段长度不一致：' ...
        'x=%d, y=%d, z=%d。'], ...
        dataFile, numel(xVec), numel(yVec), numel(zVec));
end

if size(echoMat, 1) ~= numel(freqVec)
    error('bp_data_pipeline:RangeFrequencyMismatch', ...
        ['数据文件 %s 的回波矩阵距离向尺寸与频率向量长度不一致：' ...
        'size(echo,1)=%d, numel(freq)=%d。'], ...
        dataFile, size(echoMat, 1), numel(freqVec));
end

if size(echoMat, 2) ~= numAzSamples
    error('bp_data_pipeline:AzimuthTrackMismatch', ...
        ['数据文件 %s 的回波矩阵方位向尺寸与轨迹长度不一致：' ...
        'size(echo,2)=%d, trackLength=%d。'], ...
        dataFile, size(echoMat, 2), numAzSamples);
end

sample.x = xVec;
sample.y = yVec;
sample.z = zVec;
sample.echo = echoMat;
sample.freq = freqVec;
end

function vec = localNormalizeTrackVector(value, logicalName, dataFile)
if ~isnumeric(value) || isempty(value) || ~isvector(value)
    error('bp_data_pipeline:InvalidTrackField', ...
        '数据文件 %s 中的轨迹字段 "%s" 必须是非空数值向量。', ...
        dataFile, logicalName);
end
vec = value(:).';
end

function freqVec = localNormalizeFrequencyVector(value, dataFile)
if ~isnumeric(value) || isempty(value) || ~isvector(value)
    error('bp_data_pipeline:InvalidFrequencyVector', ...
        '数据文件 %s 中的频率字段必须是非空数值向量。', dataFile);
end
freqVec = value(:).';
end

function echoMat = localNormalizeEchoMatrix(value, dataFile)
if ~isnumeric(value) || isempty(value) || ndims(value) ~= 2
    error('bp_data_pipeline:InvalidEchoMatrix', ...
        '数据文件 %s 中的回波字段必须是非空二维数值矩阵。', dataFile);
end
echoMat = value;
end

function localValidateFrequencyConsistency(freqVec, refFreqVec, dataFile)
if numel(freqVec) ~= numel(refFreqVec)
    error('bp_data_pipeline:FrequencyVectorMismatch', ...
        ['数据文件 %s 的频率向量长度与首个文件不一致：' ...
        'current=%d, reference=%d。'], ...
        dataFile, numel(freqVec), numel(refFreqVec));
end

freqDelta = abs(double(freqVec(:)) - double(refFreqVec(:)));
scale = max([1; abs(double(refFreqVec(:)))]);
tol = max(eps(scale) * 64, 1e-9);
maxDelta = max(freqDelta);

if maxDelta > tol
    error('bp_data_pipeline:FrequencyVectorMismatch', ...
        ['数据文件 %s 的频率向量与首个文件不一致：' ...
        '最大差值为 %.12g。'], ...
        dataFile, maxDelta);
end
end

function radar = localBuildRadarParams(cfg, numRangeSamples, freqVec)
c = cfg.radar.c;
w0 = cfg.radar.w0;
tau = cfg.radar.tau;
rangeUpsampleFactor = cfg.radar.rangeUpsampleFactor;

assert(~isempty(freqVec), '频率向量不能为空。');
freqVec = freqVec(:).';
firstFreq = freqVec(1);

if numel(freqVec) >= 2
    freqStepHz = mean(diff(freqVec));
    bandwidthHz = abs(freqVec(end) - freqVec(1));
else
    freqStepHz = NaN;
    bandwidthHz = NaN;
end

Ts = tau / numRangeSamples;
numRangeSamplesUp = rangeUpsampleFactor * numRangeSamples;
y0 = (w0 - firstFreq * 2 * pi) / tau * 2;
deltaR = c * pi / (y0 * Ts * numRangeSamplesUp);

radar = struct();
radar.c = c;
radar.w0 = w0;
radar.tau = tau;
radar.Ts = Ts;
radar.y0 = y0;
radar.firstFreq = firstFreq;
radar.freqVectorHz = freqVec;
radar.freqStepHz = freqStepHz;
radar.bandwidthHz = bandwidthHz;
radar.numRangeSamples = numRangeSamples;
radar.numRangeSamplesUp = numRangeSamplesUp;
radar.deltaR = deltaR;
end
