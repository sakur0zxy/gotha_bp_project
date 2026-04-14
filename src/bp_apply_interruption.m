function [srOut, info] = bp_apply_interruption(srIn, track, interCfg)
%BP_APPLY_INTERRUPTION Apply azimuth interruption layout.

numAzSamples = size(srIn, 2);
modeName = char(string(interCfg.mode));
numSegments = interCfg.numSegments;
missingRatio = interCfg.missingRatio;
totalMissing = round(numAzSamples * missingRatio);
totalValid = numAzSamples - totalMissing;

assert(totalValid >= numSegments, ...
    'missingRatio is too large: each segment must keep at least one sample.');

srOut = srIn;
meanStep = localEstimateMeanStep(track);
randomSeedUsed = [];
constraintInfo = localBuildConstraintInfo(numAzSamples, numSegments, totalMissing, meanStep);

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
        assert(numGaps >= 1, 'random_gap requires at least two kept segments.');

        constraintInfo = localAnalyzeRandomGapConstraints( ...
            numAzSamples, numSegments, totalMissing, meanStep, ...
            interCfg.gapMinMeters, interCfg.gapMaxMeters);

        if constraintInfo.gapMaxSamples < constraintInfo.gapMinSamples
            error('bp_apply_interruption:GapDiscretizationEmpty', '%s', ...
                localBuildDiscretizationError(constraintInfo));
        end

        minTotalMissing = numGaps * constraintInfo.gapMinSamples;
        maxTotalMissing = numGaps * constraintInfo.gapMaxSamples;
        if totalMissing < minTotalMissing || totalMissing > maxTotalMissing
            error('bp_apply_interruption:GapRangeMismatch', '%s', ...
                localBuildMissingRatioError(constraintInfo));
        end

        [gapLengths, randomSeedUsed] = localGenerateRandomGaps( ...
            numGaps, totalMissing, constraintInfo.gapMinSamples, ...
            constraintInfo.gapMaxSamples, interCfg.randomSeed);
        segmentLengths = localBalancedLengths(totalValid, numSegments);

        [activeAzIndices, segmentStartIdx, segmentEndIdx, gapStartIdx, gapEndIdx] = ...
            localBuildRandomGapLayout(segmentLengths, gapLengths);

    otherwise
        error('Unsupported interruption mode: %s', modeName);
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
info.constraintInfo = constraintInfo;
end

function meanStep = localEstimateMeanStep(track)
x = track.X(:);
y = track.Y(:);
z = track.Z(:);

if numel(x) < 2
    error('Not enough track samples to estimate mean azimuth spacing.');
end

stepDist = hypot(hypot(diff(x), diff(y)), diff(z));
stepDist = stepDist(isfinite(stepDist) & stepDist > 0);
assert(~isempty(stepDist), 'Track step length is invalid.');
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
    'gapMinMeters/gapMaxMeters become an empty discrete interval after conversion.\n' ...
    'meanStep_m = %.6f\n' ...
    'gapMinMeters = %.6f -> gapMinSamples = %d -> effectiveMinMeters = %.6f\n' ...
    'gapMaxMeters = %.6f -> gapMaxSamples = %d -> effectiveMaxMeters = %.6f\n' ...
    'To make the interval valid, ensure either gapMinMeters <= %.6f or gapMaxMeters >= %.6f.'], ...
    info.meanStep_m, ...
    info.gapMinMetersRequested, info.gapMinSamples, info.gapMinMetersEffective, ...
    info.gapMaxMetersRequested, info.gapMaxSamples, info.gapMaxMetersEffective, ...
    info.gapMaxSamples * info.meanStep_m, ...
    info.gapMinSamples * info.meanStep_m);
end

function msg = localBuildMissingRatioError(info)
msg = sprintf([ ...
    'missingRatio does not match the requested random gap limits.\n' ...
    'M = %d samples, G = %d gaps, meanStep_m = %.6f\n' ...
    'gapMinMeters = %.6f -> gapMinSamples = %d -> effectiveMinMeters = %.6f\n' ...
    'gapMaxMeters = %.6f -> gapMaxSamples = %d -> effectiveMaxMeters = %.6f\n' ...
    'maxAllowedGapMinSamples = %d -> maxAllowedGapMinMeters = %.6f\n' ...
    'minRequiredGapMaxSamples = %d -> minRequiredGapMaxMeters = %.6f\n' ...
    'Feasible gapMinMeters range: [0, %.6f]\n' ...
    'Feasible gapMaxMeters range: [%.6f, %.6f]'], ...
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
    assert(progress, ...
        'missingRatio is too large to keep at least one sample in each segment.');
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
    assert(~isempty(freeIdx), 'Random gap capacity is insufficient.');

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
