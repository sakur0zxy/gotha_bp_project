function [track, sr, radar, dataRoot] = bp_load_data(cfg, context)
%BP_LOAD_DATA 读取并拼接 GOTCHA 分段数据
% 输入：
%   cfg      配置结构体
%   context  路径上下文
% 输出：
%   track    轨迹结构体（X/Y/Z，行向量）
%   sr       回波矩阵（距离向采样点 x 方位向采样点）
%   radar    雷达派生参数
%   dataRoot 数据根目录

dataRoot = bp_find_data_root(cfg, context);

numFiles = cfg.general.numDataFiles;
xCells = cell(1, numFiles);
yCells = cell(1, numFiles);
zCells = cell(1, numFiles);
srCells = cell(1, numFiles);

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

    % 轨迹统一为行向量，便于后续按索引访问
    xCells{fileIdx} = data.x(:).';
    yCells{fileIdx} = data.y(:).';
    zCells{fileIdx} = data.z(:).';
    srCells{fileIdx} = data.fp;
end

track = struct();
track.X = [xCells{:}];
track.Y = [yCells{:}];
track.Z = [zCells{:}];

sr = [srCells{:}];

numAzSamples = numel(track.X);
assert(numel(track.Y) == numAzSamples && numel(track.Z) == numAzSamples, ...
    '轨迹长度不一致。');
assert(size(sr, 2) == numAzSamples, '回波方位向长度与轨迹长度不一致。');

radar = bp_build_radar_params(cfg, size(sr, 1), firstFreqVec);
end
