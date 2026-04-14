function seed = bp_read_seed_from_run_dir(runDir)
%BP_READ_SEED_FROM_RUN_DIR 从历史运行目录读取 random_gap 使用的种子。

runDir = char(string(runDir));
if exist(runDir, 'dir') ~= 7
    error('bp_read_seed_from_run_dir:MissingDir', '运行目录不存在：%s', runDir);
end

[~, runName] = fileparts(runDir);
token = regexp(runName, '_seed(\d+)$', 'tokens', 'once');
if ~isempty(token)
    seed = str2double(token{1});
    if isfinite(seed)
        return;
    end
end

summaryFile = fullfile(runDir, 'interruption_summary.txt');
if exist(summaryFile, 'file') ~= 2
    error('bp_read_seed_from_run_dir:MissingSeed', ...
        '目录名中没有 random_gap 种子，且未找到摘要文件：%s', runDir);
end

summaryText = fileread(summaryFile);
modeToken = regexp(summaryText, 'mode\s*=\s*(\S+)', 'tokens', 'once');
if isempty(modeToken) || ~strcmp(modeToken{1}, 'random_gap')
    error('bp_read_seed_from_run_dir:NotRandomGap', ...
        '该目录不是 random_gap 运行目录：%s', runDir);
end

seedToken = regexp(summaryText, 'randomSeedUsed\s*=\s*(\d+)', 'tokens', 'once');
if isempty(seedToken)
    error('bp_read_seed_from_run_dir:MissingSeed', ...
        '未能从摘要文件中解析 random gap 种子：%s', summaryFile);
end

seed = str2double(seedToken{1});
if ~isfinite(seed)
    error('bp_read_seed_from_run_dir:InvalidSeed', ...
        '摘要文件中的 random gap 种子无效：%s', summaryFile);
end
end
