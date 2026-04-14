function savedFile = bp_save_point_analysis_output(anaResult, anaInfo, config, runDir)
%BP_SAVE_POINT_ANALYSIS_OUTPUT 保存点目标分析结果文件

savedFile = struct( ...
    'matFile', '', ...
    'textFile', '', ...
    'imageFile', '', ...
    'imageFiles', struct( ...
        'upslice', '', ...
        'contour', '', ...
        'rangeProfile', '', ...
        'azimuthProfile', ''));

if exist(runDir, 'dir') ~= 7
    mkdir(runDir);
end

%% 保存 MAT
if config.output.savePointAnalysisMat
    matFile = fullfile(runDir, 'point_analysis_result.mat');
    pointResult = anaResult; %#ok<NASGU>
    pointMeta = anaInfo; %#ok<NASGU>
    save(matFile, 'pointResult', 'pointMeta');
    savedFile.matFile = matFile;
end

%% 保存文本摘要
if config.output.savePointAnalysisText
    txtFile = fullfile(runDir, 'point_analysis_summary.txt');
    localWriteSummary(txtFile, anaResult, anaInfo);
    savedFile.textFile = txtFile;
end

%% 保存上采样图
if localShouldSavePointImages(config) ...
        && isstruct(anaResult) ...
        && isfield(anaResult, 'upSlice') ...
        && ~isempty(anaResult.upSlice)
    savedFile.imageFiles = localSavePointImages(runDir, anaResult);
    savedFile.imageFile = savedFile.imageFiles.upslice;
end
end

function tf = localShouldSavePointImages(config)
tf = config.output.savePointAnalysisImage;
if tf && isfield(config, 'analysis') ...
        && isstruct(config.analysis) ...
        && isfield(config.analysis, 'pointAnaCfg') ...
        && isstruct(config.analysis.pointAnaCfg) ...
        && isfield(config.analysis.pointAnaCfg, 'showFigures')
    tf = tf && config.analysis.pointAnaCfg.showFigures;
end
end

function imageFiles = localSavePointImages(runDir, anaResult)
imageFiles = struct( ...
    'upslice', fullfile(runDir, 'point_analysis_upslice.jpg'), ...
    'contour', fullfile(runDir, 'point_analysis_contour.jpg'), ...
    'rangeProfile', fullfile(runDir, 'point_analysis_range_profile.jpg'), ...
    'azimuthProfile', fullfile(runDir, 'point_analysis_azimuth_profile.jpg'));

localWriteUpslice(imageFiles.upslice, anaResult.upSlice);
localWriteContour(imageFiles.contour, anaResult.upSlice);
localWriteProfile(imageFiles.rangeProfile, anaResult.range.profile, '距离向剖面图', '距离向（采样点）');
localWriteProfile(imageFiles.azimuthProfile, anaResult.azimuth.profile, '方位向剖面图', '方位向（采样点）');
end

function localWriteUpslice(filePath, upSlice)
upSliceAbs = abs(upSlice);
maxVal = max(upSliceAbs(:));
if maxVal > 0
    upSliceAbs = upSliceAbs / maxVal;
end
imwrite(upSliceAbs, filePath, 'jpg');
end

function localWriteContour(filePath, upSlice)
fig = figure('Visible', 'off', 'Color', 'w');
closeGuard = onCleanup(@() close(fig)); %#ok<NASGU>

contour(abs(upSlice));
axis image;
colormap jet;
xlabel('距离向（采样点）');
ylabel('方位向（采样点）');
title('目标轮廓图');

localExportFigure(fig, filePath);
end

function localWriteProfile(filePath, profile, figName, xLabelText)
profileDb = localToDb(profile);
[peakValues, peakIndices] = localPeakMark(profileDb);

fig = figure('Visible', 'off', 'Color', 'w');
closeGuard = onCleanup(@() close(fig)); %#ok<NASGU>

plot(profileDb, 'b');
hold on;
plot(peakIndices, peakValues, 'r*');
hold off;
grid on;
axis tight;
xlabel(xLabelText);
ylabel('幅度（dB）');
title(figName);

localExportFigure(fig, filePath);
end

function localWriteSummary(filePath, result, meta)
fid = fopen(filePath, 'w');
if fid < 0
    error('无法写入文件：%s', filePath);
end
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

if isfield(result, 'rotated') && isstruct(result.rotated) ...
        && isfield(result.rotated, 'enabled') && result.rotated.enabled
    rot = result.rotated;
    fprintf(fid, '[Rotated]\n');
    localWriteField(fid, rot, 'rangeLikeAngleDeg', '%.6f');
    localWriteField(fid, rot, 'azimuthLikeAngleDeg', '%.6f');

    if isfield(rot, 'rangeLikeMetrics')
        m = rot.rangeLikeMetrics;
        fprintf(fid, 'rangeLike.PSLR_dB = %.6f\n', m.PSLR_dB);
        fprintf(fid, 'rangeLike.ISLR_dB = %.6f\n', m.ISLR_dB);
        fprintf(fid, 'rangeLike.IRW_m   = %.6f\n', m.IRW_m);
    end
    if isfield(rot, 'azimuthLikeMetrics')
        m = rot.azimuthLikeMetrics;
        fprintf(fid, 'azLike.PSLR_dB = %.6f\n', m.PSLR_dB);
        fprintf(fid, 'azLike.ISLR_dB = %.6f\n', m.ISLR_dB);
        fprintf(fid, 'azLike.IRW_m   = %.6f\n', m.IRW_m);
    end
    fprintf(fid, '\n');
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

function localExportFigure(fig, filePath)
warnState = warning;
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
warning('off', 'all');
exportgraphics(fig, filePath, 'Resolution', 200);
if exist(filePath, 'file') ~= 2
    error('bp_save_point_analysis_output:ExportFailed', ...
        '未能导出点目标分析图片：%s', filePath);
end
end

function localWriteField(fid, s, fieldName, valueFmt)
if isfield(s, fieldName)
    fprintf(fid, ['%s = ' valueFmt '\n'], fieldName, s.(fieldName));
end
end

function txt = localToText(v)
if ischar(v)
    txt = v;
elseif isstring(v)
    txt = char(v);
else
    txt = char(string(v));
end
end
