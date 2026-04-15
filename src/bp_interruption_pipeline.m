function [echoCut, cutInfo] = bp_interruption_pipeline(echoData, track, interCfg)
%BP_INTERRUPTION_PIPELINE 生成间断采样布局并输出间断后的回波矩阵。
% 输入：
%   echoData  原始回波矩阵。
%   track     轨迹数据。
%   interCfg  间断配置。
% 输出：
%   echoCut   间断后的回波矩阵。
%   cutInfo   间断布局和约束信息。
numAzSamples = size(echoData, 2);
modeName = char(string(interCfg.mode));
numSegments = interCfg.numSegments;
missingRatio = interCfg.missingRatio;
totalMissing = round(numAzSamples * missingRatio);
totalValid = numAzSamples - totalMissing;

assert(totalValid >= numSegments, '缺失率过大，每段至少需要保留 1 个采样点。');

echoCut = echoData;
meanStep = localEstimateMeanStep(track);
constraintInfo = localBuildConstraintInfo(numAzSamples, numSegments, totalMissing, meanStep);
randomSeedUsed = [];

switch modeName
    case 'tail_gap'
        blockLengths = localBalancedLengths(numAzSamples, numSegments);
        gapMaxSamples = blockLengths - 1;
        gapLengths = localDistributeDeterministic(totalMissing, gapMaxSamples);
        segmentLengths = blockLengths - gapLengths;
        layoutInfo = localBuildTailGapLayout(blockLengths, segmentLengths);

    case 'random_gap'
        numGaps = numSegments - 1;
        assert(numGaps >= 1, 'random_gap 模式至少需要 2 段保留数据。');

        constraintInfo = localAnalyzeRandomGapConstraints( ...
            numAzSamples, numSegments, totalMissing, meanStep, ...
            interCfg.gapMinMeters, interCfg.gapMaxMeters);

        if constraintInfo.gapMaxSamples < constraintInfo.gapMinSamples
            error('bp_interruption_pipeline:GapDiscretizationEmpty', '%s', ...
                localBuildDiscretizationError(constraintInfo));
        end

        minTotalMissing = numGaps * constraintInfo.gapMinSamples;
        maxTotalMissing = numGaps * constraintInfo.gapMaxSamples;
        if totalMissing < minTotalMissing || totalMissing > maxTotalMissing
            error('bp_interruption_pipeline:GapRangeMismatch', '%s', ...
                localBuildMissingRatioError(constraintInfo));
        end

        [gapLengths, randomSeedUsed] = localGenerateRandomGaps( ...
            numGaps, totalMissing, constraintInfo.gapMinSamples, ...
            constraintInfo.gapMaxSamples, interCfg.randomSeed);
        segmentLengths = localBalancedLengths(totalValid, numSegments);
        layoutInfo = localBuildRandomGapLayout(segmentLengths, gapLengths);

    otherwise
        error('bp_interruption_pipeline:UnsupportedMode', '不支持的间断模式：%s', modeName);
end

echoCut = localApplyGaps(echoCut, layoutInfo.gapStartIndices, layoutInfo.gapEndIndices);
cutInfo = localBuildCutInfo( ...
    modeName, numAzSamples, numSegments, missingRatio, totalMissing, totalValid, ...
    meanStep, segmentLengths, layoutInfo, randomSeedUsed, constraintInfo);
end

function meanStep = localEstimateMeanStep(track)
x = track.X(:);
y = track.Y(:);
z = track.Z(:);

if numel(x) < 2
    error('轨迹点不足，无法估计平均方位向间距。');
end

stepDist = hypot(hypot(diff(x), diff(y)), diff(z));
stepDist = stepDist(isfinite(stepDist) & stepDist > 0);
assert(~isempty(stepDist), '轨迹步长无效。');
meanStep = mean(stepDist);
end

function constraintInfo = localBuildConstraintInfo(numAzSamples, numSegments, totalMissing, meanStep)
constraintInfo = struct();
constraintInfo.numAzSamples = numAzSamples;
constraintInfo.numSegments = numSegments;
constraintInfo.numGaps = max(numSegments - 1, 0);
constraintInfo.meanStep_m = meanStep;
constraintInfo.totalMissingSamples = totalMissing;
constraintInfo.totalMissingMeters = totalMissing * meanStep;
constraintInfo.gapMinMetersRequested = NaN;
constraintInfo.gapMaxMetersRequested = NaN;
constraintInfo.gapMinSamples = NaN;
constraintInfo.gapMaxSamples = NaN;
constraintInfo.gapMinMetersEffective = NaN;
constraintInfo.gapMaxMetersEffective = NaN;
constraintInfo.maxAllowedGapMinSamples = NaN;
constraintInfo.maxAllowedGapMinMeters = NaN;
constraintInfo.minRequiredGapMaxSamples = NaN;
constraintInfo.minRequiredGapMaxMeters = NaN;
end

function constraintInfo = localAnalyzeRandomGapConstraints( ...
        numAzSamples, numSegments, totalMissing, meanStep, gapMinMeters, gapMaxMeters)
constraintInfo = localBuildConstraintInfo(numAzSamples, numSegments, totalMissing, meanStep);
constraintInfo.gapMinMetersRequested = gapMinMeters;
constraintInfo.gapMaxMetersRequested = gapMaxMeters;
constraintInfo.gapMinSamples = ceil(gapMinMeters / meanStep);
constraintInfo.gapMaxSamples = floor(gapMaxMeters / meanStep);
constraintInfo.gapMinMetersEffective = constraintInfo.gapMinSamples * meanStep;
constraintInfo.gapMaxMetersEffective = constraintInfo.gapMaxSamples * meanStep;

if constraintInfo.numGaps > 0
    constraintInfo.maxAllowedGapMinSamples = floor(totalMissing / constraintInfo.numGaps);
    constraintInfo.maxAllowedGapMinMeters = constraintInfo.maxAllowedGapMinSamples * meanStep;
    constraintInfo.minRequiredGapMaxSamples = ceil(totalMissing / constraintInfo.numGaps);
    constraintInfo.minRequiredGapMaxMeters = constraintInfo.minRequiredGapMaxSamples * meanStep;
end
end

function msg = localBuildDiscretizationError(info)
msg = sprintf([ ...
    'gapMinMeters/gapMaxMeters 离散化后没有有效区间。\n' ...
    'meanStep_m = %.6f\n' ...
    'gapMinMeters = %.6f -> gapMinSamples = %d -> effectiveMinMeters = %.6f\n' ...
    'gapMaxMeters = %.6f -> gapMaxSamples = %d -> effectiveMaxMeters = %.6f\n' ...
    '请满足 gapMinMeters <= %.6f 或 gapMaxMeters >= %.6f。'], ...
    info.meanStep_m, ...
    info.gapMinMetersRequested, info.gapMinSamples, info.gapMinMetersEffective, ...
    info.gapMaxMetersRequested, info.gapMaxSamples, info.gapMaxMetersEffective, ...
    info.gapMaxSamples * info.meanStep_m, ...
    info.gapMinSamples * info.meanStep_m);
end

function msg = localBuildMissingRatioError(info)
msg = sprintf([ ...
    'missingRatio 与随机间断长度约束不匹配。\n' ...
    'M = %d samples, G = %d gaps, meanStep_m = %.6f\n' ...
    'gapMinMeters = %.6f -> gapMinSamples = %d -> effectiveMinMeters = %.6f\n' ...
    'gapMaxMeters = %.6f -> gapMaxSamples = %d -> effectiveMaxMeters = %.6f\n' ...
    'maxAllowedGapMinSamples = %d -> maxAllowedGapMinMeters = %.6f\n' ...
    'minRequiredGapMaxSamples = %d -> minRequiredGapMaxMeters = %.6f\n' ...
    '可行的 gapMinMeters 范围：[0, %.6f]\n' ...
    '可行的 gapMaxMeters 范围：[%.6f, %.6f]'], ...
    info.totalMissingSamples, info.numGaps, info.meanStep_m, ...
    info.gapMinMetersRequested, info.gapMinSamples, info.gapMinMetersEffective, ...
    info.gapMaxMetersRequested, info.gapMaxSamples, info.gapMaxMetersEffective, ...
    info.maxAllowedGapMinSamples, info.maxAllowedGapMinMeters, ...
    info.minRequiredGapMaxSamples, info.minRequiredGapMaxMeters, ...
    info.maxAllowedGapMinMeters, info.minRequiredGapMaxMeters, info.totalMissingMeters);
end

function lengths = localBalancedLengths(totalCount, numParts)
baseLen = floor(totalCount / numParts);
extraCount = mod(totalCount, numParts);

lengths = baseLen * ones(1, numParts);
if extraCount > 0
    lengths(1:extraCount) = lengths(1:extraCount) + 1;
end
end

function gapLengths = localDistributeDeterministic(totalMissing, gapMaxSamples)
numGaps = numel(gapMaxSamples);
gapLengths = zeros(1, numGaps);

if totalMissing == 0
    return;
end

remaining = totalMissing;
while remaining > 0
    progress = false;
    for idx = 1:numGaps
        if remaining == 0
            break;
        end
        if gapLengths(idx) < gapMaxSamples(idx)
            gapLengths(idx) = gapLengths(idx) + 1;
            remaining = remaining - 1;
            progress = true;
        end
    end
    assert(progress, '缺失率过大，无法保证每段至少保留 1 个采样点。');
end
end

function [gapLengths, seedUsed] = localGenerateRandomGaps( ...
        numGaps, totalMissing, minGapSamples, maxGapSamples, randomSeed)
gapLengths = minGapSamples * ones(1, numGaps);
remaining = totalMissing - sum(gapLengths);
capacity = (maxGapSamples - minGapSamples) * ones(1, numGaps);
seedUsed = localResolveRandomSeed(randomSeed);

state = rng;
cleanup = onCleanup(@() rng(state)); %#ok<NASGU>
rng(seedUsed, 'twister');

while remaining > 0
    freeIdx = find(capacity > 0);
    assert(~isempty(freeIdx), '随机间断容量不足。');

    addCount = min(remaining, numel(freeIdx));
    pickOrder = randperm(numel(freeIdx), addCount);
    pickIdx = freeIdx(pickOrder);

    gapLengths(pickIdx) = gapLengths(pickIdx) + 1;
    capacity(pickIdx) = capacity(pickIdx) - 1;
    remaining = remaining - addCount;
end
end

function seed = localResolveRandomSeed(seedIn)
if ~isempty(seedIn)
    seed = double(seedIn);
    return;
end

timeNow = posixtime(datetime('now'));
seed = mod(floor(timeNow * 1e6), 2^31 - 1);
if ~isfinite(seed) || seed <= 0
    seed = 1;
end
end

function layoutInfo = localBuildTailGapLayout(blockLengths, segmentLengths)
numSegments = numel(blockLengths);
activeAzIndices = zeros(1, sum(segmentLengths));
segmentStartIdx = zeros(1, numSegments);
segmentEndIdx = zeros(1, numSegments);
gapStartIdx = zeros(1, numSegments);
gapEndIdx = zeros(1, numSegments);
cursor = 1;
writePos = 1;

for segIdx = 1:numSegments
    keepStart = cursor;
    keepEnd = cursor + segmentLengths(segIdx) - 1;
    keepCount = segmentLengths(segIdx);

    segmentStartIdx(segIdx) = keepStart;
    segmentEndIdx(segIdx) = keepEnd;
    activeAzIndices(writePos:writePos + keepCount - 1) = keepStart:keepEnd;
    writePos = writePos + keepCount;

    gapStartIdx(segIdx) = keepEnd + 1;
    gapEndIdx(segIdx) = cursor + blockLengths(segIdx) - 1;
    cursor = gapEndIdx(segIdx) + 1;
end

layoutInfo = localPackLayout(activeAzIndices, segmentStartIdx, segmentEndIdx, gapStartIdx, gapEndIdx);
end

function layoutInfo = localBuildRandomGapLayout(segmentLengths, gapLengths)
numSegments = numel(segmentLengths);
numGaps = numel(gapLengths);

activeAzIndices = zeros(1, sum(segmentLengths));
segmentStartIdx = zeros(1, numSegments);
segmentEndIdx = zeros(1, numSegments);
gapStartIdx = zeros(1, numGaps);
gapEndIdx = zeros(1, numGaps);
cursor = 1;
writePos = 1;

for segIdx = 1:numSegments
    keepStart = cursor;
    keepEnd = cursor + segmentLengths(segIdx) - 1;
    keepCount = segmentLengths(segIdx);

    segmentStartIdx(segIdx) = keepStart;
    segmentEndIdx(segIdx) = keepEnd;
    activeAzIndices(writePos:writePos + keepCount - 1) = keepStart:keepEnd;
    writePos = writePos + keepCount;
    cursor = keepEnd + 1;

    if segIdx <= numGaps
        gapStartIdx(segIdx) = cursor;
        gapEndIdx(segIdx) = cursor + gapLengths(segIdx) - 1;
        cursor = gapEndIdx(segIdx) + 1;
    end
end

layoutInfo = localPackLayout(activeAzIndices, segmentStartIdx, segmentEndIdx, gapStartIdx, gapEndIdx);
end

function layoutInfo = localPackLayout(activeAzIndices, segmentStartIdx, segmentEndIdx, gapStartIdx, gapEndIdx)
layoutInfo = struct();
layoutInfo.activeAzIndices = activeAzIndices;
layoutInfo.segmentStartIndices = segmentStartIdx;
layoutInfo.segmentEndIndices = segmentEndIdx;
layoutInfo.gapStartIndices = gapStartIdx;
layoutInfo.gapEndIndices = gapEndIdx;
end

function echoCut = localApplyGaps(echoCut, gapStartIdx, gapEndIdx)
for k = 1:numel(gapStartIdx)
    if gapStartIdx(k) <= gapEndIdx(k)
        echoCut(:, gapStartIdx(k):gapEndIdx(k)) = 0;
    end
end
end

function cutInfo = localBuildCutInfo( ...
        modeName, numAzSamples, numSegments, missingRatio, totalMissing, totalValid, ...
        meanStep, segmentLengths, layoutInfo, randomSeedUsed, constraintInfo)
gapLengths = layoutInfo.gapEndIndices - layoutInfo.gapStartIndices + 1;

cutInfo = struct();
cutInfo.mode = modeName;
cutInfo.numAzSamples = numAzSamples;
cutInfo.numSegments = numSegments;
cutInfo.missingRatio = missingRatio;
cutInfo.totalMissingSamples = totalMissing;
cutInfo.totalValidSamples = totalValid;
cutInfo.meanAzimuthStep_m = meanStep;
cutInfo.segmentLengthsSamples = segmentLengths;
cutInfo.segmentStartIndices = layoutInfo.segmentStartIndices;
cutInfo.segmentEndIndices = layoutInfo.segmentEndIndices;
cutInfo.gapLengthsSamples = gapLengths;
cutInfo.gapLengthsMeters = gapLengths * meanStep;
cutInfo.gapStartIndices = layoutInfo.gapStartIndices;
cutInfo.gapEndIndices = layoutInfo.gapEndIndices;
cutInfo.activeAzIndices = layoutInfo.activeAzIndices;
cutInfo.randomSeedUsed = randomSeedUsed;
cutInfo.constraintInfo = constraintInfo;
end
