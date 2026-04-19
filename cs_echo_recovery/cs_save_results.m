function files = cs_save_results(result, projectCfg, ~, runDir)
%CS_SAVE_RESULTS 保存恢复结果、对比图和点目标分析输出。
% 输入：
%   result      cs_recovery_pipeline 返回的结果结构体。
%   projectCfg  现有 GOTCHA BP 工程配置。
%   csCfg       新模块配置。
%   runDir      当前实验输出目录。
% 输出：
%   files       各类输出文件路径。

caseNames = {'original', 'interrupted', 'recovered_1d', 'recovered_2d'};
files = localEmptyFiles(caseNames);
if ~localIsOutputEnabled(result.csConfig.output) || isempty(runDir)
    return;
end

summaryDir = fullfile(runDir, 'summary');
localEnsureDir(summaryDir);

files.summary.matFile = fullfile(summaryDir, 'recovery_result.mat');
save(files.summary.matFile, 'result', '-v7.3');

files.summary.textFile = fullfile(summaryDir, 'recovery_metrics.txt');
localWriteSummary(files.summary.textFile, result, caseNames);

files.summary.echoFigure = fullfile(summaryDir, 'echo_comparison.jpg');
localWriteComparisonFigure(files.summary.echoFigure, result.cases, caseNames, 'echo', ...
    'Echo Comparison');

if result.csConfig.compare.runImaging
    files.summary.imageFigure = fullfile(summaryDir, 'image_comparison.jpg');
    localWriteComparisonFigure(files.summary.imageFigure, result.cases, caseNames, 'image', ...
        'Image Comparison');
else
    files.summary.imageFigure = '';
end

saveCfg = localBuildPointSaveConfig(projectCfg);
for idx = 1:numel(caseNames)
    name = caseNames{idx};
    caseDir = fullfile(runDir, name);
    localEnsureDir(caseDir);
    files.cases.(name) = struct( ...
        'dir', caseDir, ...
        'imageFile', '', ...
        'pointFiles', struct(), ...
        'statusFile', '');

    if ~isfield(result.cases, name)
        continue;
    end

    caseData = result.cases.(name);
    if strcmp(caseData.status, 'skipped')
        files.cases.(name).statusFile = fullfile(caseDir, 'skipped.txt');
        localWriteText(files.cases.(name).statusFile, ...
            sprintf('%s is skipped in current configuration.\n', name));
        continue;
    end

    if ~isempty(caseData.image)
        files.cases.(name).imageFile = fullfile(caseDir, 'image.jpg');
        localWriteMagnitudeImage(files.cases.(name).imageFile, caseData.image);
    else
        files.cases.(name).statusFile = fullfile(caseDir, 'image_not_generated.txt');
        localWriteText(files.cases.(name).statusFile, ...
            sprintf('%s image was not generated because imaging is disabled.\n', name));
    end

    if result.csConfig.compare.runPointAnalysis && isfield(caseData.pointMeta, 'enabled')
        if caseData.pointMeta.enabled && ~isempty(caseData.pointAnalysis)
            files.cases.(name).pointFiles = bp_output_pipeline( ...
                'save_point_analysis', caseData.pointAnalysis, caseData.pointMeta, saveCfg, caseDir);
        else
            pointErrFile = fullfile(caseDir, 'point_analysis_error.txt');
            errMsg = 'Point analysis did not produce a valid result.';
            if isfield(caseData.pointMeta, 'errorMessage')
                errMsg = caseData.pointMeta.errorMessage;
            end
            localWriteText(pointErrFile, sprintf('%s\n', errMsg));
            files.cases.(name).pointFiles = struct( ...
                'matFile', '', ...
                'textFile', pointErrFile, ...
                'imageFile', '', ...
                'imageFiles', struct());
        end
    end
end
end

function saveCfg = localBuildPointSaveConfig(projectCfg)
saveCfg = projectCfg;
saveCfg.output.enableOutput = true;
saveCfg.output.savePointAnalysisMat = true;
saveCfg.output.savePointAnalysisText = true;
saveCfg.output.savePointAnalysisImage = true;

if ~isfield(saveCfg, 'analysis') || ~isstruct(saveCfg.analysis)
    saveCfg.analysis = struct();
end
if ~isfield(saveCfg.analysis, 'pointAnaCfg') || ~isstruct(saveCfg.analysis.pointAnaCfg)
    saveCfg.analysis.pointAnaCfg = struct();
end
saveCfg.analysis.pointAnaCfg.showFigures = true;
end

function files = localEmptyFiles(caseNames)
files = struct();
files.summary = struct( ...
    'matFile', '', ...
    'textFile', '', ...
    'echoFigure', '', ...
    'imageFigure', '');
files.cases = struct();
for idx = 1:numel(caseNames)
    name = caseNames{idx};
    files.cases.(name) = struct( ...
        'dir', '', ...
        'imageFile', '', ...
        'pointFiles', localEmptyPointFiles(), ...
        'statusFile', '');
end
end

function pointFiles = localEmptyPointFiles()
pointFiles = struct( ...
    'matFile', '', ...
    'textFile', '', ...
    'imageFile', '', ...
    'imageFiles', struct( ...
        'upslice', '', ...
        'contour', '', ...
        'rangeProfile', '', ...
        'azimuthProfile', ''));
end

function tf = localIsOutputEnabled(outputCfg)
tf = true;
if isstruct(outputCfg) && isfield(outputCfg, 'enableOutput')
    tf = outputCfg.enableOutput;
end
end

function localWriteSummary(filePath, result, caseNames)
fid = fopen(filePath, 'w');
assert(fid >= 0, '无法写入文件：%s', filePath);
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'CS Echo Recovery Summary\n');
fprintf(fid, '========================\n\n');

fprintf(fid, 'Run directory = %s\n', result.paths.runDir);
fprintf(fid, 'Data root = %s\n', result.paths.dataRoot);
fprintf(fid, 'Interruption mode = %s\n', result.cutInfo.interrupted.mode);
fprintf(fid, 'numSegments = %d\n', result.cutInfo.interrupted.numSegments);
fprintf(fid, 'missingRatio = %.9g\n', result.cutInfo.interrupted.missingRatio);
fprintf(fid, 'totalMissingSamples = %d\n', result.cutInfo.interrupted.totalMissingSamples);
fprintf(fid, 'selectedRangeSamples = %d\n', result.selection.numRangeSamples);
fprintf(fid, 'selectedAzimuthSamples = %d\n\n', result.selection.numAzimuthSamples);

for idx = 1:numel(caseNames)
    name = caseNames{idx};
    if ~isfield(result.cases, name)
        continue;
    end

    caseData = result.cases.(name);
    fprintf(fid, '[%s]\n', name);
    fprintf(fid, 'status = %s\n', caseData.status);

    if ~isempty(caseData.echoMetrics)
        fprintf(fid, 'echoWholeRelErr = %.6e\n', caseData.echoMetrics.wholeRelErr);
        fprintf(fid, 'echoMissingRelErr = %.6e\n', caseData.echoMetrics.missingRelErr);
        fprintf(fid, 'observedConsistencyErr = %.6e\n', caseData.echoMetrics.observedConsistencyErr);
        fprintf(fid, 'maxObservedAbsErr = %.6e\n', caseData.echoMetrics.maxObservedAbsErr);
    end

    if isfield(caseData, 'recoveryInfo') && isstruct(caseData.recoveryInfo) ...
            && isfield(caseData.recoveryInfo, 'iterations')
        fprintf(fid, 'recoveryMethod = %s\n', caseData.recoveryInfo.method);
        fprintf(fid, 'iterations = %d\n', caseData.recoveryInfo.iterations);
        fprintf(fid, 'runtimeSec = %.6f\n', caseData.recoveryInfo.runtimeSec);
        fprintf(fid, 'converged = %d\n', caseData.recoveryInfo.converged);
    end

    if ~isempty(caseData.imageMetrics)
        fprintf(fid, 'imageAmplitudeRelErr = %.6e\n', caseData.imageMetrics.amplitudeRelErr);
        fprintf(fid, 'imagePeakAmplitude = %.6e\n', caseData.imageMetrics.peakAmplitude);
        fprintf(fid, 'imageMeanAmplitude = %.6e\n', caseData.imageMetrics.meanAmplitude);
    end

    if isfield(caseData, 'pointMeta') && isstruct(caseData.pointMeta)
        fprintf(fid, 'pointAnalysisEnabled = %d\n', isfield(caseData.pointMeta, 'enabled') && caseData.pointMeta.enabled);
        if isfield(caseData.pointMeta, 'errorMessage')
            fprintf(fid, 'pointAnalysisError = %s\n', caseData.pointMeta.errorMessage);
        end
    end
    fprintf(fid, '\n');
end
end

function localWriteComparisonFigure(filePath, cases, caseNames, fieldName, figureTitle)
hFig = figure('Visible', 'off', 'Color', 'w');
cleanup = onCleanup(@() close(hFig));
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

for idx = 1:numel(caseNames)
    name = caseNames{idx};
    nexttile;
    if isfield(cases, name) && isfield(cases.(name), fieldName) && ~isempty(cases.(name).(fieldName))
        dataValue = cases.(name).(fieldName);
        imagesc(localMagnitudeToDb(dataValue));
        axis image off;
        colormap(gca, jet);
        title(strrep(name, '_', '\_'));
        colorbar;
    else
        axis off;
        text(0.5, 0.5, 'Not available', 'HorizontalAlignment', 'center');
        title(strrep(name, '_', '\_'));
    end
end

sgtitle(figureTitle);
exportgraphics(hFig, filePath, 'Resolution', 180);
end

function localWriteMagnitudeImage(filePath, imageValue)
amp = abs(imageValue);
scaleValue = max(amp(:));
if scaleValue > 0
    amp = amp / scaleValue;
end
imwrite(amp, filePath, 'jpg');
end

function imageDb = localMagnitudeToDb(dataValue)
amp = abs(dataValue);
scaleValue = max(amp(:));
if scaleValue <= 0
    imageDb = zeros(size(amp));
    return;
end

imageDb = 20 * log10(amp / scaleValue + eps);
imageDb(imageDb < -60) = -60;
end

function localWriteText(filePath, textValue)
fid = fopen(filePath, 'w');
assert(fid >= 0, '无法写入文件：%s', filePath);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', textValue);
end

function localEnsureDir(dirPath)
if exist(dirPath, 'dir') ~= 7
    mkdir(dirPath);
end
end
