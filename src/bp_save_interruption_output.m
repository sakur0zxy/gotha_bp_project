function savedFile = bp_save_interruption_output(cutInfo, config, runDir)
%BP_SAVE_INTERRUPTION_OUTPUT 保存间断布局摘要和示意图

savedFile = struct('textFile', '', 'imageFile', '');

if exist(runDir, 'dir') ~= 7
    mkdir(runDir);
end

if localShouldSave(config, 'saveInterruptionText', true)
    textFile = fullfile(runDir, 'interruption_summary.txt');
    localWriteSummary(textFile, cutInfo);
    savedFile.textFile = textFile;
end

if localShouldSave(config, 'saveInterruptionImage', true)
    imageFile = fullfile(runDir, 'interruption_layout.jpg');
    layoutImage = localBuildLayoutImage(cutInfo);
    imwrite(layoutImage, imageFile, 'jpg');
    savedFile.imageFile = imageFile;
end
end

function tf = localShouldSave(config, fieldName, defaultValue)
tf = defaultValue;
if isstruct(config) && isfield(config, 'output') ...
        && isstruct(config.output) && isfield(config.output, fieldName)
    tf = config.output.(fieldName);
end
end

function localWriteSummary(filePath, cutInfo)
fid = fopen(filePath, 'w');
if fid < 0
    error('无法写入文件：%s', filePath);
end
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

function txt = localToText(value)
if ischar(value)
    txt = value;
elseif isstring(value)
    txt = char(value);
else
    txt = char(string(value));
end
end
