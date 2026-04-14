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

[tiltDeg, tiltInfo] = localEstimateTilt(cut, cfg);
up = localUpsampleFFT(cut, cfg.upN);
rotDeg = 0;
refineDeltaDeg = 0;
residualTiltDeg = NaN;
residualTiltInfo = struct('method', 'not-run', 'used', 'not-run');

if cfg.enableTiltAlign && abs(tiltDeg) >= cfg.tiltApplyThresholdDeg
    rotDeg = -tiltDeg;
end

cutAligned = localRotateComplex(cut, rotDeg);
upAligned = localRotateComplex(up, rotDeg);
candidateRotationsDeg = rotDeg;
selectedCandidate = rotDeg;

if cfg.enableTiltAlign
    [residualTiltDeg, residualTiltInfo] = localEstimateTilt(cutAligned, cfg);
    residualTiltInfo.used = 'residual-diagnostic';
end

tiltInfo.residualCheckDeg = residualTiltDeg;
tiltInfo.candidateRotationsDeg = candidateRotationsDeg;
tiltInfo.candidateScores = candidateScores;
tiltInfo.candidateResidualsDeg = candidateResidualsDeg;
tiltInfo.selectedCandidate = selectedCandidate;
tiltInfo.selectedCandidateScore = NaN;
tiltInfo.selectedCandidateResidualDeg = residualTiltDeg;

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
cfg.tiltRowPeakMinDb = -20;
cfg.tiltRowFitMinRows = 6;
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
assert(isnumeric(cfg.tiltRowPeakMinDb) && isscalar(cfg.tiltRowPeakMinDb) ...
    && isfinite(cfg.tiltRowPeakMinDb) && cfg.tiltRowPeakMinDb <= 0, ...
    'tiltRowPeakMinDb must be a finite scalar <= 0.');
assert(isnumeric(cfg.tiltRowFitMinRows) && isscalar(cfg.tiltRowFitMinRows) ...
    && cfg.tiltRowFitMinRows >= 2 && mod(cfg.tiltRowFitMinRows, 1) == 0, ...
    'tiltRowFitMinRows must be an integer >= 2.');
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

function [ang, info] = localEstimateTilt(img, cfg, searchOverride) %#ok<INUSD>
if nargin < 3
    searchOverride = struct(); %#ok<NASGU>
end

info = struct();
info.method = 'raw-row-peak-fit';
info.used = 'raw-row-peak-fit';
info.estimatedFrom = 'raw-cut';
info.correctionAppliedTo = 'upsampled-slice';
info.mainPoints = 0;
info.sidePoints = 0;
info.pcaRawDeg = NaN;
info.pcaRangeDeg = NaN;
info.sideRangeDeg = NaN;
info.fallbackRangeDeg = NaN;
info.anisotropy = NaN;
info.coarseAngleDeg = NaN;
info.midAngleDeg = NaN;
info.fineAngleDeg = NaN;
info.bestScore = NaN;
info.residualCheckDeg = NaN;
info.coarsePcaDeg = NaN;
info.searchCenterDeg = NaN;
info.searchWindowDeg = NaN;
info.orientationPoints = 0;
info.candidateRotationsDeg = NaN;
info.candidateScores = NaN;
info.candidateResidualsDeg = NaN;
info.selectedCandidate = NaN;
info.rowPeakCols = [];
info.rowPeakAmp = [];
info.rowPeakDb = [];
info.validRowMask = [];
info.validRowIndices = [];
info.validRowCount = 0;
info.fitSlopePxPerRow = NaN;
info.fitInterceptPx = NaN;
info.fitRmsePx = NaN;
info.lowConfidence = false;

amp = abs(img);
if isempty(amp)
    ang = 0;
    info.used = 'empty-image';
    info.lowConfidence = true;
    return;
end

[rowPeakAmp, rowPeakCols] = max(amp, [], 2);
rowPeakAmp = rowPeakAmp(:);
rowPeakCols = rowPeakCols(:);
peakRef = max(rowPeakAmp);

info.rowPeakCols = rowPeakCols;
info.rowPeakAmp = rowPeakAmp;

if peakRef <= 0
    ang = 0;
    info.used = 'zero-image';
    info.rowPeakDb = -Inf(size(rowPeakAmp));
    info.validRowMask = false(size(rowPeakAmp));
    info.lowConfidence = true;
    return;
end

rowPeakDb = 20 * log10(rowPeakAmp / peakRef + eps);
[validMask, validRows, selectMode] = localSelectTiltRows(rowPeakAmp, rowPeakDb, cfg);

info.rowPeakDb = rowPeakDb;
info.validRowMask = validMask;
info.validRowIndices = validRows;
info.validRowCount = numel(validRows);
info.mainPoints = numel(validRows);
info.orientationPoints = numel(validRows);

if strcmp(selectMode, 'top-rows-fallback')
    info.used = 'raw-row-peak-fit+top-rows-fallback';
    info.lowConfidence = true;
elseif strcmp(selectMode, 'insufficient-rows')
    ang = 0;
    info.used = 'raw-row-peak-fit+insufficient-rows';
    info.lowConfidence = true;
    return;
end

rowCoord = (1:size(img, 1)).';
y = rowCoord(validRows) - (size(img, 1) + 1) / 2;
x = rowPeakCols(validRows) - (size(img, 2) + 1) / 2;
weights = rowPeakAmp(validRows);
weights = weights / max(weights);

[fitSlope, fitIntercept, fitRmse] = localWeightedLineFit(y, x, weights);
if ~isfinite(fitSlope)
    ang = 0;
    info.used = 'raw-row-peak-fit+invalid-fit';
    info.lowConfidence = true;
    return;
end

ang = localToRangeAxisAngle(-atan2d(fitSlope, 1));
info.fitSlopePxPerRow = fitSlope;
info.fitInterceptPx = fitIntercept;
info.fitRmsePx = fitRmse;
info.fineAngleDeg = ang;
end

function [validMask, validRows, selectMode] = localSelectTiltRows(rowPeakAmp, rowPeakDb, cfg)
numRows = numel(rowPeakAmp);
finiteMask = isfinite(rowPeakAmp) & isfinite(rowPeakDb);
validMask = finiteMask & (rowPeakDb >= cfg.tiltRowPeakMinDb);
selectMode = 'threshold';

if nnz(validMask) < cfg.tiltRowFitMinRows
    keepCount = min(numRows, max(cfg.tiltRowFitMinRows, 2));
    validMask = false(numRows, 1);
    finiteRows = find(finiteMask);
    if numel(finiteRows) >= 2
        [~, order] = sort(rowPeakAmp(finiteRows), 'descend');
        chosen = finiteRows(order(1:min(keepCount, numel(finiteRows))));
        validMask(chosen) = true;
        selectMode = 'top-rows-fallback';
    else
        selectMode = 'insufficient-rows';
    end
end

validRows = find(validMask);
if numel(validRows) < 2
    validMask(:) = false;
    validRows = [];
    selectMode = 'insufficient-rows';
end
end

function [slope, intercept, rmse] = localWeightedLineFit(y, x, weights)
slope = NaN;
intercept = NaN;
rmse = NaN;

if numel(y) < 2 || numel(x) ~= numel(y)
    return;
end

w = weights(:);
w(~isfinite(w) | w < 0) = 0;
if ~any(w > 0)
    w = ones(size(y));
end

A = [y(:), ones(numel(y), 1)];
sqrtW = sqrt(w(:));
Aw = A .* sqrtW;
xw = x(:) .* sqrtW;
coef = Aw \ xw;

if numel(coef) ~= 2 || any(~isfinite(coef))
    return;
end

slope = coef(1);
intercept = coef(2);
fitErr = A * coef - x(:);
rmse = sqrt(sum(w .* (fitErr .^ 2)) / (sum(w) + eps));
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



