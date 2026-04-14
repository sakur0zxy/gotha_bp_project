%% 点目标剖面与旁瓣分析
% 必需输入：
%   imgBP, Br, Fr, PRF, vc, squintAngle, lambda
% 可选输入：
%   pointAnaCfg
% 输出：
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
analysisSource = 'rotated-corrected upsampled slice';

% 在成像结果中截取峰值邻域。
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

% 主估角、主剖面和主指标统一基于旋转后的升采样图。
up = localUpsampleFFT(cut, cfg.upN);
[tiltDeg, tiltInfo] = localEstimateTilt(up, cfg);
rotDeg = 0;
refineDeltaDeg = 0;
residualTiltDeg = NaN;
residualTiltInfo = struct('method', 'not-run', 'used', 'not-run');

if cfg.enableTiltAlign && abs(tiltDeg) >= cfg.tiltApplyThresholdDeg
    rotDeg = -tiltDeg;
end

upAligned = localRotateComplex(up, rotDeg);
candidateRotationsDeg = rotDeg;
candidateScores = NaN;
candidateResidualsDeg = NaN;
selectedCandidate = rotDeg;

if cfg.enableTiltAlign
    [residualTiltDeg, residualTiltInfo] = localEstimateTilt(upAligned, cfg);
    residualTiltInfo.used = 'residual-diagnostic';
    residualTiltInfo.estimatedFrom = 'rotated-upsampled-slice';
    residualTiltInfo.correctionAppliedTo = 'diagnostic-only';
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

% raw 仅保留未矫正参考，不参与主结果判断。
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
cfg.tiltEdgeFraction = 0.2;
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
assert(cfg.tiltApplyThresholdDeg >= 0, 'tiltApplyThresholdDeg must be nonnegative.');
assert(isnumeric(cfg.tiltEdgeFraction) && isscalar(cfg.tiltEdgeFraction) ...
    && isfinite(cfg.tiltEdgeFraction) && cfg.tiltEdgeFraction > 0 ...
    && cfg.tiltEdgeFraction < 0.5, ...
    'tiltEdgeFraction must be a finite scalar in (0, 0.5).');
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
info.method = 'upsampled-column-peak-edge-fit';
info.used = 'upsampled-column-peak-edge-fit';
info.estimatedFrom = 'upsampled-slice';
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
info.colPeakRows = [];
info.colPeakAmp = [];
info.usedColumnMask = [];
info.usedColumnIndices = [];
info.usedColumnCount = 0;
info.edgeFraction = cfg.tiltEdgeFraction;
info.fitSlopePxPerCol = NaN;
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

[colPeakAmp, colPeakRows] = max(amp, [], 1);
colPeakAmp = colPeakAmp(:);
colPeakRows = colPeakRows(:);
info.colPeakRows = colPeakRows;
info.colPeakAmp = colPeakAmp;

if max(colPeakAmp) <= 0
    ang = 0;
    info.used = 'zero-image';
    info.lowConfidence = true;
    return;
end

[usedMask, usedCols, selectMode] = localSelectTiltColumns(size(img, 2), cfg.tiltEdgeFraction);
info.usedColumnMask = usedMask;
info.usedColumnIndices = usedCols;
info.usedColumnCount = numel(usedCols);
info.mainPoints = numel(usedCols);
info.orientationPoints = numel(usedCols);

if strcmp(selectMode, 'insufficient-columns')
    ang = 0;
    info.used = 'upsampled-column-peak-edge-fit+insufficient-columns';
    info.lowConfidence = true;
    return;
end

y = colPeakRows(usedCols) - (size(img, 1) + 1) / 2;
x = usedCols(:) - (size(img, 2) + 1) / 2;

[fitSlope, fitIntercept, fitRmse] = localLineFit(x, y);
if ~isfinite(fitSlope)
    ang = 0;
    info.used = 'upsampled-column-peak-edge-fit+invalid-fit';
    info.lowConfidence = true;
    return;
end

ang = localToRangeAxisAngle(atan2d(fitSlope, 1));
info.fitSlopePxPerCol = fitSlope;
info.fitInterceptPx = fitIntercept;
info.fitRmsePx = fitRmse;
info.fineAngleDeg = ang;
end

function [usedMask, usedCols, selectMode] = localSelectTiltColumns(numCols, edgeFraction)
usedMask = false(numCols, 1);
usedCols = [];
selectMode = 'edge-columns';

if numCols < 2
    selectMode = 'insufficient-columns';
    return;
end

edgeCount = ceil(numCols * edgeFraction);
edgeCount = max(edgeCount, 1);
edgeCount = min(edgeCount, floor(numCols / 2));
if edgeCount < 1
    selectMode = 'insufficient-columns';
    return;
end

% 只用左右边缘列拟合倾角，中间列不参与。
usedMask(1:edgeCount) = true;
usedMask(end-edgeCount+1:end) = true;
usedCols = find(usedMask);
if numel(usedCols) < 2
    usedMask(:) = false;
    usedCols = [];
    selectMode = 'insufficient-columns';
end
end

function [slope, intercept, rmse] = localLineFit(x, y)
slope = NaN;
intercept = NaN;
rmse = NaN;

if numel(x) < 2 || numel(y) ~= numel(x)
    return;
end

A = [x(:), ones(numel(x), 1)];
coef = A \ y(:);

if numel(coef) ~= 2 || any(~isfinite(coef))
    return;
end

slope = coef(1);
intercept = coef(2);
fitErr = A * coef - y(:);
rmse = sqrt(mean(fitErr .^ 2));
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
