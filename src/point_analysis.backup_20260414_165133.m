%% Point target profile and sidelobe analysis
% Required inputs in workspace:
%   imgBP, Br, Fr, PRF, vc, squintAngle, lambda
% Optional input:
%   pointAnaCfg
% Output:
%   pointAnaResult

needVars = {'imgBP', 'Br', 'Fr', 'PRF', 'vc', 'squintAngle', 'lambda'};
for i = 1:numel(needVars)
    if ~exist(needVars{i}, 'var')
        error('point_analysis:MissingInput', 'Missing input variable: %s', needVars{i});
    end
end

cfg = localDefaultCfg();
if exist('pointAnaCfg', 'var') && isstruct(pointAnaCfg)
    cfg = localMergeStruct(cfg, pointAnaCfg);
end
localCheckCfg(cfg);

img = imgBP;
c = 3e8;
v = vc;
prf = PRF;
fd = 2 * v * sin(squintAngle) / lambda;
rangeUnit = c / (2 * Fr);
aziUnit = v / prf;
analysisSource = 'upSlice (rotated-corrected)';

amp = abs(img);
[~, idxMax] = max(amp(:));
[cy, cx] = ind2sub(size(amp), idxMax);
cut = localExtractPatch(img, cy, cx, cfg.cutH, cfg.cutW);

if cfg.showFigures
    figure('Name', 'Target Cut', 'Color', 'w');
    imagesc(abs(cut));
    axis image;
    colormap jet;
    xlabel('Range samples');
    ylabel('Azimuth samples');
    title('Target Cut');
end

up = localUpsampleFFT(cut, cfg.upN);
[tiltDeg, tiltInfo] = localEstimateTilt(up, cfg);
rotDeg = 0;
refineDeltaDeg = 0;
residualTiltDeg = NaN;
residualTiltInfo = struct('method', 'not-run', 'used', 'not-run');
candidateRotationsDeg = [];
candidateScores = [];
candidateResidualsDeg = [];
selectedCandidate = NaN;

if cfg.enableTiltAlign && abs(tiltDeg) >= cfg.tiltApplyThresholdDeg
    rotDeg = -tiltDeg;
end

upAligned = localRotateComplex(up, rotDeg);
candidateRotationsDeg = rotDeg;
candidateScores = localRotationAlignmentScores(up, candidateRotationsDeg, cfg);
candidateResidualsDeg = NaN(size(candidateRotationsDeg));
selectedCandidate = rotDeg;

if cfg.enableTiltAlign && cfg.tiltResidualRefineEnable && abs(rotDeg) > 0
    residualSearch = struct();
    residualSearch.centerDeg = 0;
    residualSearch.halfRangeDeg = cfg.tiltResidualRefineMaxStepDeg;
    residualSearch.coarseStepDeg = min(cfg.tiltSearchCoarseStepDeg, 0.2);
    residualSearch.midStepDeg = min(cfg.tiltSearchMidStepDeg, 0.05);
    residualSearch.fineStepDeg = min(cfg.tiltSearchFineStepDeg, 0.01);
    [residualTiltDeg, residualTiltInfo] = localEstimateTilt(upAligned, cfg, residualSearch);
    residualTiltInfo.used = 'residual-check';

    if isfinite(residualTiltDeg) && abs(residualTiltDeg) >= cfg.tiltResidualRefineThresholdDeg
        deltaFull = localClampAbs(-residualTiltDeg, cfg.tiltResidualRefineMaxStepDeg);
        deltaHalf = localClampAbs(-0.5 * residualTiltDeg, cfg.tiltResidualRefineMaxStepDeg);
        candidateRotationsDeg = unique([rotDeg, rotDeg + deltaFull, rotDeg + deltaHalf], 'stable');
        candidateScores = localRotationAlignmentScores(up, candidateRotationsDeg, cfg);
        candidateResidualsDeg = zeros(size(candidateRotationsDeg));
        for candidateIndex = 1:numel(candidateRotationsDeg)
            candidateImg = localRotateComplex(up, candidateRotationsDeg(candidateIndex));
            candidateResidualsDeg(candidateIndex) = abs(localEstimateTilt(candidateImg, cfg, residualSearch));
        end

        bestCandidateScore = max(candidateScores);
        eligibleIndex = find(candidateScores >= (bestCandidateScore - cfg.tiltResidualMinScoreGain));
        [~, bestResidualPick] = min(candidateResidualsDeg(eligibleIndex));
        bestCandidateIndex = eligibleIndex(bestResidualPick);
        currentResidual = candidateResidualsDeg(1);
        if bestCandidateIndex ~= 1 && candidateResidualsDeg(bestCandidateIndex) < currentResidual
            selectedCandidate = candidateRotationsDeg(bestCandidateIndex);
            refineDeltaDeg = selectedCandidate - rotDeg;
            rotDeg = selectedCandidate;
            upAligned = localRotateComplex(up, rotDeg);
            [residualTiltDeg, residualTiltInfo] = localEstimateTilt(upAligned, cfg, residualSearch);
            residualTiltInfo.used = 'residual-check+candidate';
        else
            selectedCandidate = candidateRotationsDeg(1);
            residualTiltDeg = sign(residualTiltDeg) * currentResidual;
        end
    end
end

tiltInfo.residualCheckDeg = residualTiltDeg;
tiltInfo.candidateRotationsDeg = candidateRotationsDeg;
tiltInfo.candidateScores = candidateScores;
tiltInfo.candidateResidualsDeg = candidateResidualsDeg;
tiltInfo.selectedCandidate = selectedCandidate;
if ~isempty(candidateScores)
    selectedIndex = find(abs(candidateRotationsDeg - selectedCandidate) < 1e-9, 1, 'first');
    if isempty(selectedIndex)
        selectedIndex = 1;
    end
    tiltInfo.selectedCandidateScore = candidateScores(selectedIndex);
    tiltInfo.selectedCandidateResidualDeg = candidateResidualsDeg(selectedIndex);
    tiltInfo.bestScore = max(tiltInfo.bestScore, max(candidateScores));
end

[~, idxUpMax] = max(abs(upAligned(:)));
[py, px] = ind2sub(size(upAligned), idxUpMax);
[~, idxUpRawMax] = max(abs(up(:)));
[pyRaw, pxRaw] = ind2sub(size(up), idxUpRawMax);

if cfg.showFigures
    figure('Name', 'Upsampled Slice', 'Color', 'w');
    imagesc(abs(upAligned));
    axis image;
    colormap jet;
    xlabel('Range samples');
    ylabel('Azimuth samples');
    if abs(rotDeg) > 0
        title(sprintf('Upsampled Slice (rotation %.2f deg)', rotDeg));
    else
        title('Upsampled Slice');
    end

    figure('Name', 'Target Contour', 'Color', 'w');
    contour(abs(upAligned));
    axis image;
    colormap jet;
    xlabel('Range samples');
    ylabel('Azimuth samples');
    title('Target Contour');
end

rangeProfile = localNorm(upAligned(py, :).');
aziProfile = localNorm(upAligned(:, px));
rangeProfileRaw = localNorm(up(pyRaw, :).');
aziProfileRaw = localNorm(up(:, pxRaw));

if cfg.showFigures
    localPlotProfile(rangeProfile, 'Range Profile', 'Range samples');
    localPlotProfile(aziProfile, 'Azimuth Profile', 'Azimuth samples');
end

mR = localMetrics(rangeProfile, cfg.upN, rangeUnit);
mA = localMetrics(aziProfile, cfg.upN, aziUnit);
mRRaw = localMetrics(rangeProfileRaw, cfg.upN, rangeUnit);
mARaw = localMetrics(aziProfileRaw, cfg.upN, aziUnit);

irwRTheory = 0.886 * c / (2 * Br);
if abs(fd) < eps
    irwATheory = NaN;
else
    irwATheory = 0.886 * (v / fd);
end

pointAnaResult = struct();
pointAnaResult.peakInImage = [cy, cx];
pointAnaResult.peakInUpSlice = [py, px];
pointAnaResult.peakInUpSliceRaw = [pyRaw, pxRaw];
pointAnaResult.cut = cut;
pointAnaResult.upSlice = upAligned;
pointAnaResult.upSliceRaw = up;
pointAnaResult.config = cfg;
pointAnaResult.analysisSource = analysisSource;

pointAnaResult.range = localPackAxisResult(rangeProfile, mR, irwRTheory);
pointAnaResult.azimuth = localPackAxisResult(aziProfile, mA, irwATheory);

pointAnaResult.raw = struct();
pointAnaResult.raw.range = localPackAxisResult(rangeProfileRaw, mRRaw, irwRTheory);
pointAnaResult.raw.azimuth = localPackAxisResult(aziProfileRaw, mARaw, irwATheory);

pointAnaResult.rotated = struct();
pointAnaResult.rotated.enabled = cfg.enableTiltAlign;
pointAnaResult.rotated.estimatedTiltDeg = tiltDeg;
pointAnaResult.rotated.appliedRotationDeg = rotDeg;
pointAnaResult.rotated.tiltInfo = tiltInfo;
pointAnaResult.rotated.refineDeltaDeg = refineDeltaDeg;
pointAnaResult.rotated.residualTiltDeg = residualTiltDeg;
pointAnaResult.rotated.residualTiltInfo = residualTiltInfo;
pointAnaResult.rotated.finalEquivalentTiltDeg = -rotDeg;
pointAnaResult.rotated.rangeLikeAngleDeg = 0;
pointAnaResult.rotated.azimuthLikeAngleDeg = 90;
pointAnaResult.rotated.rangeLikeMetrics = mR;
pointAnaResult.rotated.azimuthLikeMetrics = mA;
pointAnaResult.rotated.resultIsPrimary = true;
pointAnaResult.rotated.resultImageSource = analysisSource;

disp('------------------------------------------------------------');
fprintf('Analysis source: %s\n', pointAnaResult.analysisSource);
fprintf('Range PSLR:   %.4f dB\n', mR.PSLR_dB);
fprintf('Azimuth PSLR: %.4f dB\n', mA.PSLR_dB);
fprintf('Range ISLR:   %.4f dB\n', mR.ISLR_dB);
fprintf('Azimuth ISLR: %.4f dB\n', mA.ISLR_dB);
fprintf('Range IRW:    %.6f m   Theory: %.6f m\n', mR.IRW_m, irwRTheory);
fprintf('Azimuth IRW:  %.6f m   Theory: %.6f m\n', mA.IRW_m, irwATheory);
fprintf('Raw PSLR (R/A): %.4f / %.4f dB\n', mRRaw.PSLR_dB, mARaw.PSLR_dB);
fprintf('Raw ISLR (R/A): %.4f / %.4f dB\n', mRRaw.ISLR_dB, mARaw.ISLR_dB);
fprintf('Raw IRW  (R/A): %.6f / %.6f m\n', mRRaw.IRW_m, mARaw.IRW_m);
fprintf('Estimated tilt angle: %.3f deg\n', tiltDeg);
if isfinite(residualTiltDeg)
    fprintf('Residual tilt after rotation: %.3f deg\n', residualTiltDeg);
end
fprintf('Applied rotation: %.3f deg (refine delta: %.3f deg)\n', rotDeg, refineDeltaDeg);
fprintf('Tilt method: %s\n', tiltInfo.method);

function cfg = localDefaultCfg()
cfg = struct();
cfg.cutH = 32;
cfg.cutW = 32;
cfg.upN = 16;
cfg.showFigures = true;

cfg.enableTiltAlign = true;
cfg.tiltApplyThresholdDeg = 0.0;
cfg.tiltWindowRadius = 24;

cfg.tiltMainlobeDb = -6;
cfg.tiltSidelobeDbLow = -35;
cfg.tiltSidelobeDbHigh = -8;
cfg.tiltCenterExcludeRadius = 4;
cfg.tiltMinMainPoints = 20;
cfg.tiltMinSidePoints = 20;
cfg.tiltUseSidelobeRefine = true;
cfg.tiltSideSearchDeg = 20;
cfg.tiltSideStepDeg = 0.2;
cfg.tiltFuseDisagreeDeg = 4;
cfg.tiltPcaWeightStrong = 0.8;
cfg.tiltPcaWeightWeak = 0.6;
cfg.tiltPcaWeightDisagree = 0.9;

cfg.tiltSearchCoarseStepDeg = 1.0;
cfg.tiltSearchMidStepDeg = 0.1;
cfg.tiltSearchFineStepDeg = 0.02;
cfg.tiltSearchMidHalfRangeDeg = 1.0;
cfg.tiltSearchFineHalfRangeDeg = 0.1;
cfg.tiltEvalPatchSize = 41;
cfg.tiltEvalDbFloor = -35;
cfg.tiltOrientDbLow = -24;
cfg.tiltOrientDbHigh = -6;
cfg.tiltOrientGamma = 1.5;
cfg.tiltPcaHalfRangeDeg = 8;

cfg.tiltResidualRefineEnable = true;
cfg.tiltResidualRefineThresholdDeg = 0.25;
cfg.tiltResidualRefineGain = 0.7;
cfg.tiltResidualRefineMaxStepDeg = 2.0;
cfg.tiltResidualMinScoreGain = 1e-4;
end

function cfg = localMergeStruct(cfg, userCfg)
f = fieldnames(userCfg);
for k = 1:numel(f)
    name = f{k};
    val = userCfg.(name);
    if isfield(cfg, name) && isstruct(cfg.(name)) && isstruct(val)
        cfg.(name) = localMergeStruct(cfg.(name), val);
    else
        cfg.(name) = val;
    end
end
end

function localCheckCfg(cfg)
assert(cfg.cutH >= 8 && mod(cfg.cutH, 2) == 0, 'cutH must be an even integer >= 8.');
assert(cfg.cutW >= 8 && mod(cfg.cutW, 2) == 0, 'cutW must be an even integer >= 8.');
assert(cfg.upN >= 1 && mod(cfg.upN, 1) == 0, 'upN must be an integer >= 1.');
assert(cfg.tiltWindowRadius >= 4, 'tiltWindowRadius is too small.');
assert(cfg.tiltApplyThresholdDeg >= 0, 'tiltApplyThresholdDeg must be nonnegative.');
assert(cfg.tiltMainlobeDb < 0, 'tiltMainlobeDb must be less than 0 dB.');
assert(cfg.tiltSidelobeDbLow < cfg.tiltSidelobeDbHigh, ...
    'tiltSidelobeDbLow must be less than tiltSidelobeDbHigh.');
assert(cfg.tiltCenterExcludeRadius >= 0, 'tiltCenterExcludeRadius must be nonnegative.');
assert(cfg.tiltMinMainPoints >= 5, 'tiltMinMainPoints is too small.');
assert(cfg.tiltMinSidePoints >= 5, 'tiltMinSidePoints is too small.');
assert(cfg.tiltSideSearchDeg > 0, 'tiltSideSearchDeg must be greater than 0.');
assert(cfg.tiltSideStepDeg > 0, 'tiltSideStepDeg must be greater than 0.');
assert(cfg.tiltFuseDisagreeDeg >= 0, 'tiltFuseDisagreeDeg must be nonnegative.');
assert(cfg.tiltPcaWeightStrong >= 0 && cfg.tiltPcaWeightStrong <= 1, ...
    'tiltPcaWeightStrong must be in [0, 1].');
assert(cfg.tiltPcaWeightWeak >= 0 && cfg.tiltPcaWeightWeak <= 1, ...
    'tiltPcaWeightWeak must be in [0, 1].');
assert(cfg.tiltPcaWeightDisagree >= 0 && cfg.tiltPcaWeightDisagree <= 1, ...
    'tiltPcaWeightDisagree must be in [0, 1].');
assert(cfg.tiltSearchCoarseStepDeg > 0, 'tiltSearchCoarseStepDeg must be greater than 0.');
assert(cfg.tiltSearchMidStepDeg > 0, 'tiltSearchMidStepDeg must be greater than 0.');
assert(cfg.tiltSearchFineStepDeg > 0, 'tiltSearchFineStepDeg must be greater than 0.');
assert(cfg.tiltSearchMidHalfRangeDeg > 0, 'tiltSearchMidHalfRangeDeg must be greater than 0.');
assert(cfg.tiltSearchFineHalfRangeDeg > 0, 'tiltSearchFineHalfRangeDeg must be greater than 0.');
assert(cfg.tiltEvalPatchSize >= 9 && mod(cfg.tiltEvalPatchSize, 2) == 1, ...
    'tiltEvalPatchSize must be an odd integer >= 9.');
assert(cfg.tiltEvalDbFloor < 0, 'tiltEvalDbFloor must be less than 0 dB.');
assert(cfg.tiltOrientDbLow < cfg.tiltOrientDbHigh, ...
    'tiltOrientDbLow must be less than tiltOrientDbHigh.');
assert(cfg.tiltOrientGamma > 0, 'tiltOrientGamma must be greater than 0.');
assert(cfg.tiltPcaHalfRangeDeg > 0 && cfg.tiltPcaHalfRangeDeg <= 45, ...
    'tiltPcaHalfRangeDeg must be in (0, 45].');
assert(cfg.tiltResidualRefineThresholdDeg >= 0, ...
    'tiltResidualRefineThresholdDeg must be nonnegative.');
assert(cfg.tiltResidualRefineGain > 0 && cfg.tiltResidualRefineGain <= 1, ...
    'tiltResidualRefineGain must be in (0, 1].');
assert(cfg.tiltResidualRefineMaxStepDeg > 0, ...
    'tiltResidualRefineMaxStepDeg must be greater than 0.');
assert(cfg.tiltResidualMinScoreGain >= 0, ...
    'tiltResidualMinScoreGain must be nonnegative.');
end

function patch = localExtractPatch(img, cy, cx, h, w)
patch = complex(zeros(h, w, class(img)));
y0 = cy - h / 2;
x0 = cx - w / 2;
y1 = y0 + h - 1;
x1 = x0 + w - 1;

iy0 = max(1, y0);
ix0 = max(1, x0);
iy1 = min(size(img, 1), y1);
ix1 = min(size(img, 2), x1);

py0 = iy0 - y0 + 1;
px0 = ix0 - x0 + 1;
py1 = py0 + (iy1 - iy0);
px1 = px0 + (ix1 - ix0);

patch(py0:py1, px0:px1) = img(iy0:iy1, ix0:ix1);
end

function patch = localExtractCenteredSquare(img, cy, cx, sideLen)
halfLen = floor(sideLen / 2);
patch = zeros(sideLen, sideLen, class(img));
y0 = cy - halfLen;
y1 = cy + halfLen;
x0 = cx - halfLen;
x1 = cx + halfLen;

iy0 = max(1, y0);
iy1 = min(size(img, 1), y1);
ix0 = max(1, x0);
ix1 = min(size(img, 2), x1);

py0 = iy0 - y0 + 1;
py1 = py0 + (iy1 - iy0);
px0 = ix0 - x0 + 1;
px1 = px0 + (ix1 - ix0);

patch(py0:py1, px0:px1) = img(iy0:iy1, ix0:ix1);
end

function up = localUpsampleFFT(img, upN)
[h, w] = size(img);
H = h * upN;
W = w * upN;

F = fftshift(fft2(fftshift(img)));
Fup = complex(zeros(H, W, class(F)));

r0 = floor(H / 2) - floor(h / 2) + 1;
c0 = floor(W / 2) - floor(w / 2) + 1;
r1 = r0 + h - 1;
c1 = c0 + w - 1;

Fup(r0:r1, c0:c1) = F;
up = fftshift(ifft2(fftshift(Fup)));
end

function [ang, info] = localEstimateTilt(img, cfg, searchOverride)
if nargin < 3
    searchOverride = struct();
end

info = struct();
info.method = 'orientation-pca+separability-search';
info.mainPoints = 0;
info.sidePoints = 0;
info.pcaRawDeg = NaN;
info.pcaRangeDeg = NaN;
info.sideRangeDeg = NaN;
info.fallbackRangeDeg = NaN;
info.anisotropy = NaN;
info.used = 'orientation-pca';
info.coarseAngleDeg = NaN;
info.midAngleDeg = NaN;
info.fineAngleDeg = NaN;
info.bestScore = NaN;
info.residualCheckDeg = NaN;
info.coarsePcaDeg = NaN;
info.searchCenterDeg = NaN;
info.searchWindowDeg = NaN;
info.orientationPoints = 0;
info.candidateRotationsDeg = [];
info.candidateScores = [];
info.selectedCandidate = NaN;

amp = abs(img);
mx = max(amp(:));
if mx <= 0
    ang = 0;
    info.used = 'zero-image';
    return;
end

ctx = localBuildTiltContext(img, cfg);
if ~any(ctx.scoreImg(:) > 0)
    ang = 0;
    info.used = 'flat-eval-image';
    return;
end

limits = [-45, 45];
searchCfg = localResolveTiltSearchCfg(ctx, cfg, searchOverride, limits);

[coarseAngle, ~] = localSearchBestAngle(ctx.scoreImg, ...
    localAngleGrid(searchCfg.centerDeg, searchCfg.coarseHalfRangeDeg, ...
    searchCfg.coarseStepDeg, limits));
[midAngle, ~] = localSearchBestAngle(ctx.scoreImg, ...
    localAngleGrid(coarseAngle, searchCfg.midHalfRangeDeg, ...
    searchCfg.midStepDeg, limits));
[fineAngle, fineScore, fineAngles, fineScores, fineIndex] = localSearchBestAngle(ctx.scoreImg, ...
    localAngleGrid(midAngle, searchCfg.fineHalfRangeDeg, ...
    searchCfg.fineStepDeg, limits));
[refinedAngle, refinedScore] = localParabolicAngleRefine(fineAngles, fineScores, fineIndex);

if ~isfinite(refinedAngle)
    refinedAngle = fineAngle;
    refinedScore = fineScore;
else
    refinedScore = localTiltScore(ctx.scoreImg, refinedAngle);
end

ang = localToRangeAxisAngle(refinedAngle);
info.mainPoints = ctx.orientationPoints;
info.pcaRawDeg = ctx.pcaRawDeg;
info.pcaRangeDeg = ctx.coarsePcaDeg;
info.coarsePcaDeg = ctx.coarsePcaDeg;
info.searchCenterDeg = searchCfg.centerDeg;
info.searchWindowDeg = searchCfg.coarseHalfRangeDeg;
info.orientationPoints = ctx.orientationPoints;
info.coarseAngleDeg = coarseAngle;
info.midAngleDeg = midAngle;
info.fineAngleDeg = ang;
info.bestScore = refinedScore;
if ctx.hasCoarsePca
    info.used = 'orientation-pca+local-search';
else
    info.used = 'global-search-fallback';
end
end

function ctx = localBuildTiltContext(img, cfg)
amp = abs(img);
[~, idx] = max(amp(:));
[cy, cx] = ind2sub(size(amp), idx);
evalPatch = localExtractCenteredSquare(amp, cy, cx, cfg.tiltEvalPatchSize);
[baseEvalImg, dbImg] = localBuildTiltEvalImage(evalPatch, cfg.tiltEvalDbFloor);
[orientationWeights, orientInfo] = localBuildOrientationWeights(dbImg, cfg);

ctx = struct();
ctx.baseEvalImg = baseEvalImg;
ctx.orientationWeights = orientationWeights;
ctx.orientationPoints = orientInfo.orientationPoints;
ctx.pcaRawDeg = orientInfo.pcaRawDeg;
ctx.coarsePcaDeg = orientInfo.coarsePcaDeg;
ctx.hasCoarsePca = isfinite(orientInfo.coarsePcaDeg) ...
    && abs(orientInfo.coarsePcaDeg) <= cfg.tiltPcaHalfRangeDeg;
ctx.scoreImg = baseEvalImg;
if ctx.hasCoarsePca
    ctx.defaultSearchCenterDeg = orientInfo.coarsePcaDeg;
    ctx.defaultSearchWindowDeg = cfg.tiltPcaHalfRangeDeg;
    ctx.defaultCoarseStepDeg = 0.5;
else
    ctx.defaultSearchCenterDeg = 0;
    ctx.defaultSearchWindowDeg = min(abs(diff([-45, 45])) / 2, 45);
    ctx.defaultCoarseStepDeg = cfg.tiltSearchCoarseStepDeg;
end
end

function searchCfg = localResolveTiltSearchCfg(ctx, cfg, override, limits)
searchCfg = struct();
searchCfg.centerDeg = ctx.defaultSearchCenterDeg;
searchCfg.coarseHalfRangeDeg = ctx.defaultSearchWindowDeg;
searchCfg.coarseStepDeg = ctx.defaultCoarseStepDeg;
searchCfg.midHalfRangeDeg = cfg.tiltSearchMidHalfRangeDeg;
searchCfg.midStepDeg = cfg.tiltSearchMidStepDeg;
searchCfg.fineHalfRangeDeg = cfg.tiltSearchFineHalfRangeDeg;
searchCfg.fineStepDeg = cfg.tiltSearchFineStepDeg;

if isfield(override, 'centerDeg') && ~isempty(override.centerDeg)
    searchCfg.centerDeg = localToRangeAxisAngle(override.centerDeg);
end
if isfield(override, 'halfRangeDeg') && ~isempty(override.halfRangeDeg)
    searchCfg.coarseHalfRangeDeg = min(abs(override.halfRangeDeg), 45);
    searchCfg.midHalfRangeDeg = min(searchCfg.midHalfRangeDeg, searchCfg.coarseHalfRangeDeg);
    searchCfg.fineHalfRangeDeg = min(searchCfg.fineHalfRangeDeg, searchCfg.coarseHalfRangeDeg);
end
if isfield(override, 'coarseStepDeg') && ~isempty(override.coarseStepDeg)
    searchCfg.coarseStepDeg = override.coarseStepDeg;
end
if isfield(override, 'midStepDeg') && ~isempty(override.midStepDeg)
    searchCfg.midStepDeg = override.midStepDeg;
end
if isfield(override, 'fineStepDeg') && ~isempty(override.fineStepDeg)
    searchCfg.fineStepDeg = override.fineStepDeg;
end
end

function [evalImg, dbImg] = localBuildTiltEvalImage(ampPatch, dbFloor)
ampPatch = abs(ampPatch);
mx = max(ampPatch(:));
if mx <= 0
    evalImg = zeros(size(ampPatch));
    dbImg = -Inf(size(ampPatch));
    return;
end

ampPatch = ampPatch / mx;
dbImg = 20 * log10(ampPatch + eps);
dbImg = max(dbImg, dbFloor);
evalImg = (dbImg - dbFloor) / (0 - dbFloor);
evalImg = max(min(evalImg, 1), 0);
end

function [weights, info] = localBuildOrientationWeights(dbImg, cfg)
[h, w] = size(dbImg);
[yy, xx] = ndgrid(1:h, 1:w);
cx = (w + 1) / 2;
cy = (h + 1) / 2;
r = hypot(xx - cx, yy - cy);

mask = dbImg >= cfg.tiltOrientDbLow ...
    & dbImg <= cfg.tiltOrientDbHigh ...
    & r >= cfg.tiltCenterExcludeRadius;
scaled = (dbImg - cfg.tiltOrientDbLow) / ...
    (cfg.tiltOrientDbHigh - cfg.tiltOrientDbLow + eps);
scaled = max(min(scaled, 1), 0);

weights = zeros(size(dbImg));
weights(mask) = scaled(mask) .^ cfg.tiltOrientGamma;

info = struct();
info.orientationPoints = nnz(mask);
info.pcaRawDeg = NaN;
info.coarsePcaDeg = NaN;
if info.orientationPoints >= cfg.tiltMinMainPoints && any(weights(:) > 0)
    [info.pcaRawDeg, info.coarsePcaDeg] = localWeightedPcaAngle(weights);
end
end

function [pcaRawDeg, coarsePcaDeg] = localWeightedPcaAngle(weights)
[h, w] = size(weights);
[yy, xx] = ndgrid(1:h, 1:w);
cx = (w + 1) / 2;
cy = (h + 1) / 2;
x = xx - cx;
y = yy - cy;
wSum = sum(weights(:));

if wSum <= 0
    pcaRawDeg = NaN;
    coarsePcaDeg = NaN;
    return;
end

xMean = sum(weights(:) .* x(:)) / wSum;
yMean = sum(weights(:) .* y(:)) / wSum;
dx = x - xMean;
dy = y - yMean;
Cxx = sum(weights(:) .* dx(:) .* dx(:)) / wSum;
Cyy = sum(weights(:) .* dy(:) .* dy(:)) / wSum;
Cxy = sum(weights(:) .* dx(:) .* dy(:)) / wSum;

pcaRawDeg = localNormAngle(0.5 * atan2d(2 * Cxy, Cxx - Cyy));
coarsePcaDeg = localToRangeAxisAngle(pcaRawDeg);
end

function angleList = localAngleGrid(centerDeg, halfRangeDeg, stepDeg, limits)
lo = max(limits(1), centerDeg - halfRangeDeg);
hi = min(limits(2), centerDeg + halfRangeDeg);
if hi < lo
    angleList = centerDeg;
    return;
end

angleList = lo:stepDeg:hi;
angleList = unique([angleList, lo, centerDeg, hi]);
angleList = angleList(angleList >= limits(1) & angleList <= limits(2));
angleList = sort(angleList);
end

function [bestAngle, bestScore, angleList, scoreList, bestIndex] = localSearchBestAngle(evalImg, angleList)
scoreList = zeros(size(angleList));
for k = 1:numel(angleList)
    scoreList(k) = localTiltScore(evalImg, angleList(k));
end
[bestScore, bestIndex] = max(scoreList);
bestAngle = angleList(bestIndex);
end

function score = localTiltScore(evalImg, angleDeg)
rotImg = real(localRotateComplex(evalImg, -angleDeg));
rotImg(rotImg < 0) = 0;
if ~any(rotImg(:) > 0)
    score = -Inf;
    return;
end

innerSize = localInnerCropSize(min(size(rotImg, 1), size(rotImg, 2)));
rotImg = localExtractCenteredSquare(rotImg, ceil(size(rotImg, 1) / 2), ceil(size(rotImg, 2) / 2), innerSize);
singVals = svd(rotImg, 'econ');
energy = sum(singVals .^ 2);
if isempty(singVals) || energy <= 0
    score = -Inf;
    return;
end
score = (singVals(1) ^ 2) / (energy + eps);
end

function scores = localRotationAlignmentScores(img, rotationList, cfg)
scores = zeros(size(rotationList));
for k = 1:numel(rotationList)
    rotatedImg = localRotateComplex(img, rotationList(k));
    ctx = localBuildTiltContext(rotatedImg, cfg);
    scores(k) = localTiltScore(ctx.scoreImg, 0);
end
end

function val = localClampAbs(val, maxAbs)
val = max(min(val, maxAbs), -maxAbs);
end

function innerSize = localInnerCropSize(sideLen)
innerSize = floor(sideLen / sqrt(2));
if mod(innerSize, 2) == 0
    innerSize = innerSize - 1;
end
innerSize = max(innerSize, 9);
end

function [refinedAngle, refinedScore] = localParabolicAngleRefine(angleList, scoreList, bestIndex)
refinedAngle = NaN;
refinedScore = NaN;
if numel(angleList) < 3 || bestIndex <= 1 || bestIndex >= numel(angleList)
    return;
end

x = angleList(bestIndex-1:bestIndex+1);
y = scoreList(bestIndex-1:bestIndex+1);
p = polyfit(x, y, 2);
if numel(p) ~= 3 || abs(p(1)) < eps
    return;
end

candidate = -p(2) / (2 * p(1));
if candidate < min(x) || candidate > max(x)
    return;
end

refinedAngle = candidate;
refinedScore = polyval(p, candidate);
end

function out = localRotateComplex(img, angDeg)
if abs(angDeg) < eps
    out = img;
    return;
end

[h, w] = size(img);
[yy, xx] = ndgrid(1:h, 1:w);
cx = (w + 1) / 2;
cy = (h + 1) / 2;

x = xx - cx;
y = yy - cy;

t = deg2rad(angDeg);
xIn = x * cos(t) + y * sin(t) + cx;
yIn = -x * sin(t) + y * cos(t) + cy;

re = interp2(real(img), xIn, yIn, 'linear', 0);
im = interp2(imag(img), xIn, yIn, 'linear', 0);
out = re + 1i * im;
end

function y = localNorm(x)
x = x(:);
m = max(abs(x));
if m > 0
    y = x / m;
else
    y = x;
end
end

function d = localToDb(x)
d = 20 * log10(abs(x) + eps);
end

function axisResult = localPackAxisResult(profile, metrics, theoryIRW)
axisResult = struct();
axisResult.profile = profile;
axisResult.metrics = metrics;
axisResult.theoryIRW = theoryIRW;
end

function localPlotProfile(profile, figName, xLabelText)
profileDb = localToDb(profile);
[pks, locs] = localPeakMark(profileDb);

figure('Name', figName, 'Color', 'w');
plot(profileDb, 'b'); hold on;
plot(locs, pks, 'r*');
hold off;
grid on;
axis tight;
xlabel(xLabelText);
ylabel('Amplitude (dB)');
title(figName);
end

function [pks, locs] = localPeakMark(dbLine)
n = numel(dbLine);
if n < 3
    locs = (1:n).';
    pks = dbLine(locs);
    return;
end
locs = find(dbLine(2:n-1) >= dbLine(1:n-2) & dbLine(2:n-1) > dbLine(3:n)) + 1;
if isempty(locs)
    [~, locs] = max(dbLine);
end
pks = dbLine(locs);
end

function m = localMetrics(profile, upN, unit)
m = struct();
m.PSLR_dB = localPSLR(profile);
m.ISLR_dB = localISLR(profile);
m.IRW_m = localIRW(profile, upN, unit);
end

function val = localPSLR(profile)
s = abs(profile(:));
if isempty(s) || max(s) <= 0
    val = NaN;
    return;
end

idx = localFindPeaks(s);
if isempty(idx)
    val = NaN;
    return;
end
pk = sort(s(idx), 'descend');
if numel(pk) < 2
    val = -Inf;
else
    val = 20 * log10(pk(2) / pk(1));
end
end

function val = localISLR(profile)
s = abs(profile(:));
if isempty(s) || max(s) <= 0
    val = NaN;
    return;
end

[~, i0] = max(s);
[l, r] = localMainlobeBound(s, i0);
if l >= r
    val = NaN;
    return;
end
pMain = sum(s(l:r).^2);
pAll = sum(s.^2);
if pMain <= 0 || pAll <= pMain
    val = -Inf;
else
    val = 10 * log10((pAll - pMain) / pMain);
end
end

function val = localIRW(profile, upN, unit)
s = abs(profile(:));
if isempty(s)
    val = NaN;
    return;
end
[pk, i0] = max(s);
if pk <= 0
    val = NaN;
    return;
end

thr = pk * 10^(-3/20);

iL = i0;
while iL > 1 && s(iL) > thr
    iL = iL - 1;
end
if iL == 1 && s(iL) > thr
    val = NaN;
    return;
end
xL = localCross(iL, s(iL), iL + 1, s(iL + 1), thr);

iR = i0;
while iR < numel(s) && s(iR) > thr
    iR = iR + 1;
end
if iR == numel(s) && s(iR) > thr
    val = NaN;
    return;
end
xR = localCross(iR - 1, s(iR - 1), iR, s(iR), thr);

val = (xR - xL) / upN * unit;
end

function idx = localFindPeaks(s)
n = numel(s);
if n < 3
    idx = (1:n).';
    return;
end
idx = find(s(2:n-1) >= s(1:n-2) & s(2:n-1) > s(3:n)) + 1;
if s(1) > s(2)
    idx = [1; idx(:)];
end
if s(end) > s(end-1)
    idx = [idx(:); n];
end
idx = unique(idx(:));
end

function [l, r] = localMainlobeBound(s, i0)
mins = find(s(2:end-1) <= s(1:end-2) & s(2:end-1) < s(3:end)) + 1;
lCand = mins(mins < i0);
rCand = mins(mins > i0);

if isempty(lCand)
    l = max(1, i0 - 1);
else
    l = lCand(end);
end
if isempty(rCand)
    r = min(numel(s), i0 + 1);
else
    r = rCand(1);
end

if l >= r
    thr = s(i0) * 10^(-3/20);
    l = i0;
    while l > 1 && s(l) > thr
        l = l - 1;
    end
    r = i0;
    while r < numel(s) && s(r) > thr
        r = r + 1;
    end
end
end

function x = localCross(x1, y1, x2, y2, y)
if abs(y2 - y1) < eps
    x = (x1 + x2) / 2;
else
    x = x1 + (y - y1) * (x2 - x1) / (y2 - y1);
end
end

function a = localNormAngle(a)
a = mod(a + 90, 180) - 90;
end

function a = localToRangeAxisAngle(a)
a = localNormAngle(a);
if a > 45
    a = a - 90;
elseif a <= -45
    a = a + 90;
end
end



