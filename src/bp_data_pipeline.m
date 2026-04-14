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
candidateRelPaths = cfg.path.dataRootCandidates;

dataRoot = '';
for idx = 1:numel(candidateRelPaths)
    candidateRoot = fullfile(context.workspaceRoot, candidateRelPaths{idx});
    candidateFile = fullfile(candidateRoot, firstFileName);
    if exist(candidateFile, 'file') == 2
        dataRoot = candidateRoot;
        break;
    end
end

assert(~isempty(dataRoot), ...
    '未找到数据文件 %s，请检查 cfg.path.dataRootCandidates。', firstFileName);
end

function [track, echoData, radar] = localLoadData(cfg, dataRoot)
numFiles = cfg.general.numDataFiles;
xCells = cell(1, numFiles);
yCells = cell(1, numFiles);
zCells = cell(1, numFiles);
echoCells = cell(1, numFiles);

firstFreqVec = [];
requiredFields = {'x', 'y', 'z', 'fp', 'freq'};

for fileIdx = 1:numFiles
    dataFile = fullfile(dataRoot, sprintf(cfg.general.dataFilePattern, fileIdx));
    assert(exist(dataFile, 'file') == 2, '数据文件不存在：%s', dataFile);

    loaded = load(dataFile);
    assert(isfield(loaded, 'data'), '文件中缺少变量 data：%s', dataFile);
    data = loaded.data;
    assert(all(isfield(data, requiredFields)), '数据字段不完整：%s', dataFile);

    if fileIdx == 1
        firstFreqVec = data.freq(:).';
    end

    xCells{fileIdx} = data.x(:).';
    yCells{fileIdx} = data.y(:).';
    zCells{fileIdx} = data.z(:).';
    echoCells{fileIdx} = data.fp;
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
