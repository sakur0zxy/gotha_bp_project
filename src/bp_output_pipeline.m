function varargout = bp_output_pipeline(action, varargin)
%BP_OUTPUT_PIPELINE 统一处理输出目录、图片和摘要文件保存。
% 用法：
%   runOutput = bp_output_pipeline('prepare_run_dir', config, pathInfo, cutInfo)
%   files = bp_output_pipeline('save_interruption', cutInfo, config, runDir)
%   imageFile = bp_output_pipeline('save_image', imageBP, config, runDir)
%   files = bp_output_pipeline('save_point_analysis', anaResult, anaInfo, config, runDir)

switch action
    case 'prepare_run_dir'
        varargout{1} = localPrepareRunDir(varargin{:});
    case 'save_interruption'
        varargout{1} = localSaveInterruption(varargin{:});
    case 'save_image'
        varargout{1} = localSaveImage(varargin{:});
    case 'save_point_analysis'
        varargout{1} = localSavePointAnalysis(varargin{:});
    otherwise
        error('bp_output_pipeline:UnsupportedAction', '不支持的输出动作：%s', action);
end
end

function runOutput = localPrepareRunDir(cfg, context, cutInfo)
if ~localIsOutputEnabled(cfg)
    runOutput = localEmptyRunOutput();
    return;
end

baseDir = fullfile(context.workspaceRoot, cfg.output.outputDirName);
localEnsureDir(baseDir);

if cfg.output.separateRunFolder
    timeStamp = datetime('now', 'Format', cfg.output.runFolderTimestampFormat);
    runName = sprintf('%s_%s', cfg.output.runFolderPrefix, char(timeStamp));
    if strcmp(char(string(cutInfo.mode)), 'random_gap') && ~isempty(cutInfo.randomSeedUsed)
        runName = sprintf('%s_seed%.0f', runName, cutInfo.randomSeedUsed);
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

function savedFile = localSaveInterruption(cutInfo, config, runDir)
savedFile = struct('textFile', '', 'imageFile', '');
if ~localIsOutputEnabled(config) || isempty(runDir)
    return;
end

localEnsureDir(runDir);

if localShouldSave(config, 'saveInterruptionText', true)
    savedFile.textFile = fullfile(runDir, 'interruption_summary.txt');
    localWriteInterruptionSummary(savedFile.textFile, cutInfo);
end

if localShouldSave(config, 'saveInterruptionImage', true)
    savedFile.imageFile = fullfile(runDir, 'interruption_layout.jpg');
    imwrite(localBuildLayoutImage(cutInfo), savedFile.imageFile, 'jpg');
end
end

function outputFile = localSaveImage(imgBP, cfg, outputDir)
if ~localIsOutputEnabled(cfg) || isempty(outputDir)
    outputFile = '';
    return;
end

localEnsureDir(outputDir);

baseName = sprintf('%s_%s_%d_%g', ...
    cfg.output.filePrefix, ...
    cfg.interruption.mode, ...
    cfg.interruption.numSegments, ...
    cfg.interruption.missingRatio);

if cfg.output.appendTimestamp
    timeStamp = datetime('now', 'Format', cfg.output.timestampFormat);
    fileName = sprintf('%s_%s.jpg', baseName, char(timeStamp));
else
    fileName = sprintf('%s.jpg', baseName);
end

outputFile = fullfile(outputDir, fileName);
outputImage = abs(imgBP);
outputScale = mean(outputImage(:));
if outputScale > 0
    outputImage = outputImage / (outputScale * cfg.display.outputScale);
end
imwrite(outputImage, outputFile, 'jpg');
end

function savedFile = localSavePointAnalysis(anaResult, anaInfo, config, runDir)
savedFile = struct( ...
    'matFile', '', ...
    'textFile', '', ...
    'imageFile', '', ...
    'imageFiles', struct( ...
        'upslice', '', ...
        'contour', '', ...
        'rangeProfile', '', ...
        'azimuthProfile', ''));
if ~localIsOutputEnabled(config) || isempty(runDir)
    return;
end

localEnsureDir(runDir);

if config.output.savePointAnalysisMat
    savedFile.matFile = fullfile(runDir, 'point_analysis_result.mat');
    pointResult = anaResult; %#ok<NASGU>
    pointMeta = anaInfo; %#ok<NASGU>
    save(savedFile.matFile, 'pointResult', 'pointMeta');
end

if config.output.savePointAnalysisText
    savedFile.textFile = fullfile(runDir, 'point_analysis_summary.txt');
    localWritePointSummary(savedFile.textFile, anaResult, anaInfo);
end

if localShouldSavePointImages(config) ...
        && isstruct(anaResult) ...
        && isfield(anaResult, 'upSlice') ...
        && ~isempty(anaResult.upSlice)
    savedFile.imageFiles = localSavePointImages(runDir, anaResult);
    savedFile.imageFile = savedFile.imageFiles.upslice;
end
end

function tf = localShouldSave(config, fieldName, defaultValue)
tf = defaultValue;
if isstruct(config) && isfield(config, 'output') ...
        && isstruct(config.output) && isfield(config.output, fieldName)
    tf = config.output.(fieldName);
end
tf = localIsOutputEnabled(config) && tf;
end

function tf = localShouldSavePointImages(config)
tf = localShouldSave(config, 'savePointAnalysisImage', false);
end

function tf = localIsOutputEnabled(config)
tf = true;
if isstruct(config) && isfield(config, 'output') ...
        && isstruct(config.output) && isfield(config.output, 'enableOutput')
    tf = config.output.enableOutput;
end
end

function runOutput = localEmptyRunOutput()
runOutput = struct( ...
    'baseDir', '', ...
    'runDir', '', ...
    'runName', '');
end

function localWriteInterruptionSummary(filePath, cutInfo)
fid = localOpenTextFile(filePath);
closeGuard = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'Interruption Summary\n');
fprintf(fid, '====================\n\n');
fprintf(fid, 'mode = %s\n', localToText(cutInfo.mode));
fprintf(fid, 'numAzSamples = %d\n', cutInfo.numAzSamples);
fprintf(fid, 'numSegments = %d\n', cutInfo.numSegments);
fprintf(fid, 'missingRatio = %.9g\n', cutInfo.missingRatio);
fprintf(fid, 'totalMissingSamples = %d\n', cutInfo.totalMissingSamples);
fprintf(fid, 'totalValidSamples = %d\n', cutInfo.totalValidSamples);
fprintf(fid, 'meanAzimuthStep_m = %.9g\n', cutInfo.meanAzimuthStep_m);

if strcmp(cutInfo.mode, 'random_gap')
    fprintf(fid, 'randomSeedUsed = %.0f\n', cutInfo.randomSeedUsed);
else
    fprintf(fid, 'randomSeedUsed = <not-applicable>\n');
end

fprintf(fid, '\n[Segments]\n');
for idx = 1:numel(cutInfo.segmentStartIndices)
    fprintf(fid, 'segment%02d = %d:%d (%d samples)\n', ...
        idx, ...
        cutInfo.segmentStartIndices(idx), ...
        cutInfo.segmentEndIndices(idx), ...
        cutInfo.segmentLengthsSamples(idx));
end

fprintf(fid, '\n[Gaps]\n');
validGapMask = cutInfo.gapLengthsSamples > 0;
if ~any(validGapMask)
    fprintf(fid, 'none\n');
else
    validGapIdx = find(validGapMask);
    for listIdx = 1:numel(validGapIdx)
        gapIdx = validGapIdx(listIdx);
        fprintf(fid, 'gap%02d = %d:%d (%d samples, %.6f m)\n', ...
            listIdx, ...
            cutInfo.gapStartIndices(gapIdx), ...
            cutInfo.gapEndIndices(gapIdx), ...
            cutInfo.gapLengthsSamples(gapIdx), ...
            cutInfo.gapLengthsMeters(gapIdx));
    end
end
end

function layoutImage = localBuildLayoutImage(cutInfo)
numAzSamples = cutInfo.numAzSamples;
mask = false(1, numAzSamples);
mask(cutInfo.activeAzIndices) = true;

imageHeight = 80;
gapColor = uint8([220, 83, 83]);
keepColor = uint8([45, 166, 111]);
layoutImage = zeros(imageHeight, numAzSamples, 3, 'uint8');

for channel = 1:3
    colorRow = gapColor(channel) * ones(imageHeight, numAzSamples, 'uint8');
    colorRow(:, mask) = keepColor(channel);
    layoutImage(:, :, channel) = colorRow;
end

validGapMask = cutInfo.gapLengthsSamples > 0;
boundaryIdx = unique([ ...
    cutInfo.segmentStartIndices, ...
    cutInfo.segmentEndIndices + 1, ...
    cutInfo.gapStartIndices(validGapMask), ...
    cutInfo.gapEndIndices(validGapMask) + 1]);
boundaryIdx = boundaryIdx(boundaryIdx >= 1 & boundaryIdx <= numAzSamples);
layoutImage(:, boundaryIdx, :) = 255;
end

function imageFiles = localSavePointImages(runDir, anaResult)
imageFiles = struct( ...
    'upslice', fullfile(runDir, 'point_analysis_upslice.jpg'), ...
    'contour', fullfile(runDir, 'point_analysis_contour.jpg'), ...
    'rangeProfile', fullfile(runDir, 'point_analysis_range_profile.jpg'), ...
    'azimuthProfile', fullfile(runDir, 'point_analysis_azimuth_profile.jpg'));

localWriteUpslice(imageFiles.upslice, anaResult.upSlice);
localWriteFigure(imageFiles.contour, @() localRenderContour(anaResult.upSlice));
localWriteFigure(imageFiles.rangeProfile, ...
    @() localRenderProfile(anaResult.range.profile, '距离向剖面图', '距离向（采样点）'));
localWriteFigure(imageFiles.azimuthProfile, ...
    @() localRenderProfile(anaResult.azimuth.profile, '方位向剖面图', '方位向（采样点）'));
end

function localWriteUpslice(filePath, upSlice)
upSliceAbs = abs(upSlice);
maxVal = max(upSliceAbs(:));
if maxVal > 0
    upSliceAbs = upSliceAbs / maxVal;
end
imwrite(upSliceAbs, filePath, 'jpg');
end

function localWritePointSummary(filePath, result, meta)
fid = localOpenTextFile(filePath);
closeGuard = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'Point Analysis Summary\n');
fprintf(fid, '======================\n\n');

if isstruct(meta)
    fprintf(fid, '[Input Physics]\n');
    localWriteField(fid, meta, 'Br_Hz', '%.9g');
    localWriteField(fid, meta, 'Fr_Hz', '%.9g');
    localWriteField(fid, meta, 'PRF_Hz', '%.9g');
    localWriteField(fid, meta, 'vc_mps', '%.9g');
    localWriteField(fid, meta, 'squintAngle_deg', '%.9g');
    localWriteField(fid, meta, 'lambda_m', '%.9g');
    if isfield(meta, 'prfSource')
        fprintf(fid, 'prfSource = %s\n', localToText(meta.prfSource));
    end
    fprintf(fid, '\n');
end

if ~isstruct(result)
    fprintf(fid, 'No valid point analysis result.\n');
    return;
end

localWriteSourceSection(fid, result);
localWriteMetricSection(fid, 'Range', localGetAxisResult(result, 'range'));
localWriteMetricSection(fid, 'Azimuth', localGetAxisResult(result, 'azimuth'));

if isfield(result, 'raw') && isstruct(result.raw)
    localWriteMetricSection(fid, 'Raw Range Reference', localGetAxisResult(result.raw, 'range'));
    localWriteMetricSection(fid, 'Raw Azimuth Reference', localGetAxisResult(result.raw, 'azimuth'));
end
end

function localWriteSourceSection(fid, result)
fprintf(fid, '[Analysis Source]\n');
if isfield(result, 'analysisSource')
    fprintf(fid, 'analysisSource = %s\n', localToText(result.analysisSource));
else
    fprintf(fid, 'analysisSource = unknown\n');
end

if isfield(result, 'rotated') && isstruct(result.rotated)
    localWriteField(fid, result.rotated, 'appliedRotationDeg', '%.6f');
    localWriteField(fid, result.rotated, 'residualTiltDeg', '%.6f');
    if isfield(result.rotated, 'resultImageSource')
        fprintf(fid, 'resultImageSource = %s\n', localToText(result.rotated.resultImageSource));
    end
end
fprintf(fid, '\n');
end

function axisResult = localGetAxisResult(result, axisName)
axisResult = [];
if isstruct(result) && isfield(result, axisName)
    axisResult = result.(axisName);
end
end

function localWriteMetricSection(fid, titleText, axisResult)
if ~isstruct(axisResult) || ~isfield(axisResult, 'metrics')
    return;
end

m = axisResult.metrics;
fprintf(fid, '[%s]\n', titleText);
fprintf(fid, 'PSLR_dB = %.6f\n', m.PSLR_dB);
fprintf(fid, 'ISLR_dB = %.6f\n', m.ISLR_dB);
fprintf(fid, 'IRW_m   = %.6f\n', m.IRW_m);
if isfield(axisResult, 'theoryIRW')
    fprintf(fid, 'TheoryIRW_m = %.6f\n', axisResult.theoryIRW);
end
fprintf(fid, '\n');
end

function localWriteFigure(filePath, renderFcn)
fig = figure('Visible', 'off', 'Color', 'w');
closeGuard = onCleanup(@() close(fig)); %#ok<NASGU>
renderFcn();
localExportFigure(fig, filePath);
end

function localRenderContour(upSlice)
contour(abs(upSlice));
axis image;
colormap jet;
xlabel('距离向（采样点）');
ylabel('方位向（采样点）');
title('目标轮廓图');
end

function localRenderProfile(profile, figName, xLabelText)
profileDb = localToDb(profile);
[peakValues, peakIndices] = localPeakMark(profileDb);

plot(profileDb, 'b');
hold on;
plot(peakIndices, peakValues, 'r*');
hold off;
grid on;
axis tight;
xlabel(xLabelText);
ylabel('幅度（dB）');
title(figName);
end

function localExportFigure(fig, filePath)
warnState = warning;
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
warning('off', 'all');
exportgraphics(fig, filePath, 'Resolution', 200);
if exist(filePath, 'file') ~= 2
    error('bp_output_pipeline:ExportFailed', '未能导出图片：%s', filePath);
end
end

function fid = localOpenTextFile(filePath)
fid = fopen(filePath, 'w');
if fid < 0
    error('bp_output_pipeline:FileOpenFailed', '无法写入文件：%s', filePath);
end
end

function localEnsureDir(targetDir)
if exist(targetDir, 'dir') ~= 7
    mkdir(targetDir);
end
end

function profileDb = localToDb(profile)
profileDb = 20 * log10(abs(profile(:)) + eps);
end

function [peakValues, peakIndices] = localPeakMark(profileDb)
numPoints = numel(profileDb);
if numPoints < 3
    peakIndices = (1:numPoints).';
    peakValues = profileDb(peakIndices);
    return;
end

peakIndices = find(profileDb(2:numPoints-1) >= profileDb(1:numPoints-2) ...
    & profileDb(2:numPoints-1) > profileDb(3:numPoints)) + 1;
if isempty(peakIndices)
    [~, peakIndices] = max(profileDb);
end
peakValues = profileDb(peakIndices);
end

function localWriteField(fid, s, fieldName, valueFmt)
if isfield(s, fieldName)
    fprintf(fid, ['%s = ' valueFmt '\n'], fieldName, s.(fieldName));
end
end

function txt = localToText(value)
if ischar(value)
    txt = value;
elseif isstring(value)
    txt = char(value);
else
    txt = char(string(value));
end
end
