function cutInfo = cs_build_full_cutinfo(track, numAzSamples)
%CS_BUILD_FULL_CUTINFO 构造全采样状态下的 cutInfo。
% 输入：
%   track         轨迹结构体，包含 X/Y/Z。
%   numAzSamples  方位向采样点数。
% 输出：
%   cutInfo       供 bp_imaging_pipeline 使用的全采样信息。

meanStep = localEstimateMeanStep(track);

constraintInfo = struct();
constraintInfo.numAzSamples = numAzSamples;
constraintInfo.numSegments = 1;
constraintInfo.numGaps = 0;
constraintInfo.meanStep_m = meanStep;
constraintInfo.totalMissingSamples = 0;
constraintInfo.totalMissingMeters = 0;
constraintInfo.gapMinMetersRequested = NaN;
constraintInfo.gapMaxMetersRequested = NaN;
constraintInfo.gapMinSamples = 0;
constraintInfo.gapMaxSamples = 0;
constraintInfo.gapMinMetersEffective = 0;
constraintInfo.gapMaxMetersEffective = 0;
constraintInfo.maxAllowedGapMinSamples = 0;
constraintInfo.maxAllowedGapMinMeters = 0;
constraintInfo.minRequiredGapMaxSamples = 0;
constraintInfo.minRequiredGapMaxMeters = 0;

cutInfo = struct();
cutInfo.mode = 'full_sampling';
cutInfo.numAzSamples = numAzSamples;
cutInfo.numSegments = 1;
cutInfo.missingRatio = 0;
cutInfo.totalMissingSamples = 0;
cutInfo.totalValidSamples = numAzSamples;
cutInfo.meanAzimuthStep_m = meanStep;
cutInfo.segmentLengthsSamples = numAzSamples;
cutInfo.segmentStartIndices = 1;
cutInfo.segmentEndIndices = numAzSamples;
cutInfo.gapLengthsSamples = 0;
cutInfo.gapLengthsMeters = 0;
cutInfo.gapStartIndices = 0;
cutInfo.gapEndIndices = 0;
cutInfo.activeAzIndices = 1:numAzSamples;
cutInfo.randomSeedUsed = [];
cutInfo.constraintInfo = constraintInfo;
end

function meanStep = localEstimateMeanStep(track)
x = track.X(:);
y = track.Y(:);
z = track.Z(:);

if numel(x) < 2
    meanStep = NaN;
    return;
end

stepDist = hypot(hypot(diff(x), diff(y)), diff(z));
stepDist = stepDist(isfinite(stepDist) & stepDist > 0);
if isempty(stepDist)
    meanStep = NaN;
else
    meanStep = mean(stepDist);
end
end
