function [srOut, info] = bp_apply_interruption(srIn, track, interCfg)
%BP_APPLY_INTERRUPTION 根据间断模式生成缺失数据

numAzSamples = size(srIn, 2);
modeName = char(string(interCfg.mode));
numSegments = interCfg.numSegments;
missingRatio = interCfg.missingRatio;
totalMissing = round(numAzSamples * missingRatio);
totalValid = numAzSamples - totalMissing;

assert(totalValid >= numSegments, '缺失率过大，至少需要给每个分段保留 1 个样本。');

srOut = srIn;
meanStep = localEstimateMeanStep(track);
randomSeedUsed = [];

switch modeName
    case 'tail_gap'
        blockLengths = localBalancedLengths(numAzSamples, numSegments);
        gapMaxSamples = blockLengths - 1;
        gapLengths = localDistributeDeterministic(totalMissing, gapMaxSamples);
        segmentLengths = blockLengths - gapLengths;

        [activeAzIndices, segmentStartIdx, segmentEndIdx, gapStartIdx, gapEndIdx] = ...
            localBuildTailGapLayout(blockLengths, segmentLengths);

    case 'random_gap'
        numGaps = numSegments - 1;
        assert(numGaps >= 1, 'random_gap 模式至少需要 2 个分段。');

        gapMinSamples = ceil(interCfg.gapMinMeters / meanStep);
        gapMaxSamples = floor(interCfg.gapMaxMeters / meanStep);
        assert(gapMaxSamples >= gapMinSamples, ...
            'gapMaxMeters 对应的样本数必须不小于 gapMinMeters。');

        minTotalMissing = numGaps * gapMinSamples;
        maxTotalMissing = numGaps * gapMaxSamples;
        assert(totalMissing >= minTotalMissing && totalMissing <= maxTotalMissing, ...
            ['missingRatio 与随机间断范围不匹配：总缺失样本数需满足 ', ...
            '%d <= M <= %d，当前 M = %d。'], minTotalMissing, maxTotalMissing, totalMissing);

        [gapLengths, randomSeedUsed] = localGenerateRandomGaps( ...
            numGaps, totalMissing, gapMinSamples, gapMaxSamples, interCfg.randomSeed);
        segmentLengths = localBalancedLengths(totalValid, numSegments);

        [activeAzIndices, segmentStartIdx, segmentEndIdx, gapStartIdx, gapEndIdx] = ...
            localBuildRandomGapLayout(segmentLengths, gapLengths);

    otherwise
        error('不支持的间断模式：%s', modeName);
end

for k = 1:numel(gapStartIdx)
    if gapStartIdx(k) <= gapEndIdx(k)
        srOut(:, gapStartIdx(k):gapEndIdx(k)) = 0;
    end
end

info = struct();
info.mode = modeName;
info.numAzSamples = numAzSamples;
info.numSegments = numSegments;
info.missingRatio = missingRatio;
info.totalMissingSamples = totalMissing;
info.totalValidSamples = totalValid;
info.meanAzimuthStep_m = meanStep;
info.segmentLengthsSamples = segmentLengths;
info.segmentStartIndices = segmentStartIdx;
info.segmentEndIndices = segmentEndIdx;
info.gapLengthsSamples = gapEndIdx - gapStartIdx + 1;
info.gapLengthsMeters = info.gapLengthsSamples * meanStep;
info.gapStartIndices = gapStartIdx;
info.gapEndIndices = gapEndIdx;
info.activeAzIndices = activeAzIndices;
info.randomSeedUsed = randomSeedUsed;
end

function meanStep = localEstimateMeanStep(track)
x = track.X(:);
y = track.Y(:);
z = track.Z(:);

if numel(x) < 2
    error('轨迹点数量不足，无法估计方位向采样间距。');
end

stepDist = hypot(hypot(diff(x), diff(y)), diff(z));
stepDist = stepDist(isfinite(stepDist) & stepDist > 0);
assert(~isempty(stepDist), '轨迹步长无效，无法估计方位向采样间距。');

meanStep = mean(stepDist);
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
    assert(progress, 'missingRatio 过大，无法保证每个分段至少保留 1 个样本。');
end
end

function [gapLengths, seedUsed] = localGenerateRandomGaps( ...
        numGaps, totalMissing, minGapSamples, maxGapSamples, randomSeed)
gapLengths = minGapSamples * ones(1, numGaps);
remaining = totalMissing - sum(gapLengths);
capacity = (maxGapSamples - minGapSamples) * ones(1, numGaps);
seedUsed = bp_resolve_random_seed(randomSeed);

state = rng;
cleanup = onCleanup(@() rng(state)); %#ok<NASGU>
rng(seedUsed, 'twister');

while remaining > 0
    freeIdx = find(capacity > 0);
    assert(~isempty(freeIdx), '随机间断剩余容量不足。');

    addCount = min(remaining, numel(freeIdx));
    pickOrder = randperm(numel(freeIdx), addCount);
    pickIdx = freeIdx(pickOrder);

    gapLengths(pickIdx) = gapLengths(pickIdx) + 1;
    capacity(pickIdx) = capacity(pickIdx) - 1;
    remaining = remaining - addCount;
end
end

function [activeAzIndices, segmentStartIdx, segmentEndIdx, gapStartIdx, gapEndIdx] = ...
        localBuildTailGapLayout(blockLengths, segmentLengths)
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
end

function [activeAzIndices, segmentStartIdx, segmentEndIdx, gapStartIdx, gapEndIdx] = ...
        localBuildRandomGapLayout(segmentLengths, gapLengths)
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
end
