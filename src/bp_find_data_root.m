function dataRoot = bp_find_data_root(cfg, context)
%BP_FIND_DATA_ROOT 自动探测数据根目录
% 探测逻辑：
% 1) 在 cfg.path.dataRootCandidates 中按顺序查找；
% 2) 候选路径相对于 workspaceRoot；
% 3) 以第 1 个分段数据文件是否存在作为判据。

firstFileName = sprintf(cfg.general.dataFilePattern, 1);
candidateRelPaths = cfg.path.dataRootCandidates;

dataRoot = '';
for idx = 1:numel(candidateRelPaths)
    relPath = candidateRelPaths{idx};
    candidateRoot = fullfile(context.workspaceRoot, relPath);
    candidateFile = fullfile(candidateRoot, firstFileName);
    if exist(candidateFile, 'file') == 2
        dataRoot = candidateRoot;
        break;
    end
end

assert(~isempty(dataRoot), ...
    '未找到数据文件 %s，请检查 cfg.path.dataRootCandidates。', firstFileName);
end
