function runOutput = bp_prepare_run_output_dir(cfg, context)
%BP_PREPARE_RUN_OUTPUT_DIR 创建本次运行的独立输出目录
% 输出：
%   runOutput.baseDir   输出根目录
%   runOutput.runDir    本次运行目录
%   runOutput.runName   本次运行目录名

baseDir = fullfile(context.workspaceRoot, cfg.output.outputDirName);
if exist(baseDir, 'dir') ~= 7
    mkdir(baseDir);
end

if cfg.output.separateRunFolder
    timeStamp = datetime('now', 'Format', cfg.output.runFolderTimestampFormat);
    runName = sprintf('%s_%s', cfg.output.runFolderPrefix, char(timeStamp));
    if strcmp(char(string(cfg.interruption.mode)), 'random_gap')
        seedValue = bp_resolve_random_seed(cfg.interruption.randomSeed);
        runName = sprintf('%s_seed%.0f', runName, seedValue);
    end
else
    runName = '';
end

if isempty(runName)
    runDir = baseDir;
else
    runDir = fullfile(baseDir, runName);
    suffix = 1;
    while exist(runDir, 'dir') == 7
        runDir = fullfile(baseDir, sprintf('%s_%02d', runName, suffix));
        suffix = suffix + 1;
    end
    mkdir(runDir);
    [~, runName] = fileparts(runDir);
end

runOutput = struct();
runOutput.baseDir = baseDir;
runOutput.runDir = runDir;
runOutput.runName = runName;
end
