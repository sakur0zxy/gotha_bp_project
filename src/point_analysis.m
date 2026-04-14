function pointAnaResult = point_analysis(imgBP, Br, Fr, PRF, vc, squintAngle, lambda, pointAnaCfg)
%POINT_ANALYSIS 执行点目标剖面、旁瓣和旋转矫正分析。
% 输入：
%   imgBP, Br, Fr, PRF, vc, squintAngle, lambda  点目标分析所需物理量。
%   pointAnaCfg                                  可选分析配置。
% 输出：
%   pointAnaResult                               点目标分析结果。
if nargin < 8 || isempty(pointAnaCfg)
    pointAnaCfg = struct();
end

cfg = localDefaultCfg();
if isstruct(pointAnaCfg)
    cfg = localMergeStruct(cfg, pointAnaCfg);
end
localCheckCfg(cfg);

c = 3e8;
v = vc;
fd = 2 * v * sin(squintAngle) / lambda;
rangeUnit = c / (2 * Fr);
aziUnit = v / PRF;
analysisSource = 'rotated-corrected upsampled slice';

amp = abs(imgBP);
[~, idxMax] = max(amp(:));
[cy, cx] = ind2sub(size(amp), idxMax);
cut = localExtractPatch(imgBP, cy, cx, cfg.cutH, cfg.cutW);

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
if cfg.enableTiltAlign && abs(tiltDeg) >= cfg.tiltApplyThresholdDeg
    rotDeg = -tiltDeg;
end

upAligned = localRotateComplex(up, rotDeg);
refineDeltaDeg = 0;
residualTiltDeg = NaN;
residualTiltInfo = struct('method', 'not-run', 'used', 'not-run');
if cfg.enableTiltAlign
    [residualTiltDeg, residualTiltInfo] = localEstimateTilt(upAligned, cfg);
    residualTiltInfo.used = 'residual-diagnostic';
    residualTiltInfo.estimatedFrom = 'rotated-upsampled-slice';
    residualTiltInfo.correctionAppliedTo = 'diagnostic-only';
end

tiltInfo.residualCheckDeg = residualTiltDeg;

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
end

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
fields = fieldnames(userCfg);
for k = 1:numel(fields)
    name = fields{k};
    value = userCfg.(name);
    if isfield(cfg, name) && isstruct(cfg.(name)) && isstruct(value)
        cfg.(name) = localMergeStruct(cfg.(name), value);
    else
        cfg.(name) = value;
    end
end
end

function localCheckCfg(cfg)
assert(cfg.cutH >= 8 && mod(cfg.cutH, 2) == 0, 'cutH 必须是不小于 8 的偶数。');
assert(cfg.cutW >= 8 && mod(cfg.cutW, 2) == 0, 'cutW 必须是不小于 8 的偶数。');
assert(cfg.upN >= 1 && mod(cfg.upN, 1) == 0, 'upN 必须是不小于 1 的整数。');
assert(cfg.tiltApplyThresholdDeg >= 0, 'tiltApplyThresholdDeg 必须不小于 0。');
assert(isnumeric(cfg.tiltEdgeFraction) && isscalar(cfg.tiltEdgeFraction) ...
    && isfinite(cfg.tiltEdgeFraction) && cfg.tiltEdgeFraction > 0 ...
    && cfg.tiltEdgeFraction < 0.5, ...
    'tiltEdgeFraction 必须位于 (0, 0.5) 之间。');
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

spec = fftshift(fft2(fftshift(img)));
specUp = complex(zeros(H, W, class(spec)));

r0 = floor(H / 2) - floor(h / 2) + 1;
c0 = floor(W / 2) - floor(w / 2) + 1;
r1 = r0 + h - 1;
c1 = c0 + w - 1;

specUp(r0:r1, c0:c1) = spec;
up = fftshift(ifft2(fftshift(specUp)));
end

function [tiltDeg, tiltInfo] = localEstimateTilt(img, cfg)
tiltInfo = struct();
tiltInfo.method = 'upsampled-column-peak-edge-fit';
tiltInfo.used = 'upsampled-column-peak-edge-fit';
tiltInfo.estimatedFrom = 'upsampled-slice';
tiltInfo.correctionAppliedTo = 'upsampled-slice';
tiltInfo.colPeakRows = [];
tiltInfo.colPeakAmp = [];
tiltInfo.usedColumnMask = [];
tiltInfo.usedColumnIndices = [];
tiltInfo.usedColumnCount = 0;
tiltInfo.edgeFraction = cfg.tiltEdgeFraction;
tiltInfo.fitSlopePxPerCol = NaN;
tiltInfo.fitInterceptPx = NaN;
tiltInfo.fitRmsePx = NaN;
tiltInfo.residualCheckDeg = NaN;
tiltInfo.lowConfidence = false;

amp = abs(img);
if isempty(amp)
    tiltDeg = 0;
    tiltInfo.used = 'empty-image';
    tiltInfo.lowConfidence = true;
    return;
end

[colPeakAmp, colPeakRows] = max(amp, [], 1);
colPeakAmp = colPeakAmp(:);
colPeakRows = colPeakRows(:);
tiltInfo.colPeakRows = colPeakRows;
tiltInfo.colPeakAmp = colPeakAmp;

if max(colPeakAmp) <= 0
    tiltDeg = 0;
    tiltInfo.used = 'zero-image';
    tiltInfo.lowConfidence = true;
    return;
end

[usedMask, usedCols, selectMode] = localSelectTiltColumns(size(img, 2), cfg.tiltEdgeFraction);
tiltInfo.usedColumnMask = usedMask;
tiltInfo.usedColumnIndices = usedCols;
tiltInfo.usedColumnCount = numel(usedCols);

if strcmp(selectMode, 'insufficient-columns')
    tiltDeg = 0;
    tiltInfo.used = 'upsampled-column-peak-edge-fit+insufficient-columns';
    tiltInfo.lowConfidence = true;
    return;
end

y = colPeakRows(usedCols) - (size(img, 1) + 1) / 2;
x = usedCols(:) - (size(img, 2) + 1) / 2;

[fitSlope, fitIntercept, fitRmse] = localLineFit(x, y);
if ~isfinite(fitSlope)
    tiltDeg = 0;
    tiltInfo.used = 'upsampled-column-peak-edge-fit+invalid-fit';
    tiltInfo.lowConfidence = true;
    return;
end

tiltDeg = localToRangeAxisAngle(atan2d(fitSlope, 1));
tiltInfo.fitSlopePxPerCol = fitSlope;
tiltInfo.fitInterceptPx = fitIntercept;
tiltInfo.fitRmsePx = fitRmse;
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

realPart = interp2(real(img), xIn, yIn, 'linear', 0);
imagPart = interp2(imag(img), xIn, yIn, 'linear', 0);
out = realPart + 1i * imagPart;
end

function y = localNorm(x)
x = x(:);
scale = max(abs(x));
if scale > 0
    y = x / scale;
else
    y = x;
end
end

function axisResult = localPackAxisResult(profile, metrics, theoryIRW)
axisResult = struct();
axisResult.profile = profile;
axisResult.metrics = metrics;
axisResult.theoryIRW = theoryIRW;
end

function localPlotProfile(profile, figName, xLabelText)
profileDb = localToDb(profile);
[peakValues, peakIndices] = localPeakMark(profileDb);

figure('Name', figName, 'Color', 'w');
plot(profileDb, 'b');
hold on;
plot(peakIndices, peakValues, 'r*');
hold off;
grid on;
axis tight;
xlabel(xLabelText);
ylabel('Amplitude (dB)');
title(figName);
end

function [peakValues, peakIndices] = localPeakMark(dbLine)
numPoints = numel(dbLine);
if numPoints < 3
    peakIndices = (1:numPoints).';
    peakValues = dbLine(peakIndices);
    return;
end

peakIndices = find(dbLine(2:numPoints-1) >= dbLine(1:numPoints-2) ...
    & dbLine(2:numPoints-1) > dbLine(3:numPoints)) + 1;
if isempty(peakIndices)
    [~, peakIndices] = max(dbLine);
end
peakValues = dbLine(peakIndices);
end

function metrics = localMetrics(profile, upN, unit)
metrics = struct();
metrics.PSLR_dB = localPSLR(profile);
metrics.ISLR_dB = localISLR(profile);
metrics.IRW_m = localIRW(profile, upN, unit);
end

function val = localPSLR(profile)
signal = abs(profile(:));
if isempty(signal) || max(signal) <= 0
    val = NaN;
    return;
end

peakIdx = localFindPeaks(signal);
if isempty(peakIdx)
    val = NaN;
    return;
end

peakValues = sort(signal(peakIdx), 'descend');
if numel(peakValues) < 2
    val = -Inf;
else
    val = 20 * log10(peakValues(2) / peakValues(1));
end
end

function val = localISLR(profile)
signal = abs(profile(:));
if isempty(signal) || max(signal) <= 0
    val = NaN;
    return;
end

[~, peakIdx] = max(signal);
[leftIdx, rightIdx] = localMainlobeBound(signal, peakIdx);
if leftIdx >= rightIdx
    val = NaN;
    return;
end

mainPower = sum(signal(leftIdx:rightIdx).^2);
allPower = sum(signal.^2);
if mainPower <= 0 || allPower <= mainPower
    val = -Inf;
else
    val = 10 * log10((allPower - mainPower) / mainPower);
end
end

function val = localIRW(profile, upN, unit)
signal = abs(profile(:));
if isempty(signal)
    val = NaN;
    return;
end

[peakVal, peakIdx] = max(signal);
if peakVal <= 0
    val = NaN;
    return;
end

threshold = peakVal * 10^(-3 / 20);

leftIdx = peakIdx;
while leftIdx > 1 && signal(leftIdx) > threshold
    leftIdx = leftIdx - 1;
end
if leftIdx == 1 && signal(leftIdx) > threshold
    val = NaN;
    return;
end
xLeft = localCross(leftIdx, signal(leftIdx), leftIdx + 1, signal(leftIdx + 1), threshold);

rightIdx = peakIdx;
while rightIdx < numel(signal) && signal(rightIdx) > threshold
    rightIdx = rightIdx + 1;
end
if rightIdx == numel(signal) && signal(rightIdx) > threshold
    val = NaN;
    return;
end
xRight = localCross(rightIdx - 1, signal(rightIdx - 1), rightIdx, signal(rightIdx), threshold);

val = (xRight - xLeft) / upN * unit;
end

function idx = localFindPeaks(signal)
numPoints = numel(signal);
if numPoints < 3
    idx = (1:numPoints).';
    return;
end

idx = find(signal(2:numPoints-1) >= signal(1:numPoints-2) ...
    & signal(2:numPoints-1) > signal(3:numPoints)) + 1;
if signal(1) > signal(2)
    idx = [1; idx(:)];
end
if signal(end) > signal(end - 1)
    idx = [idx(:); numPoints];
end
idx = unique(idx(:));
end

function [leftIdx, rightIdx] = localMainlobeBound(signal, peakIdx)
mins = find(signal(2:end-1) <= signal(1:end-2) & signal(2:end-1) < signal(3:end)) + 1;
leftCand = mins(mins < peakIdx);
rightCand = mins(mins > peakIdx);

if isempty(leftCand)
    leftIdx = max(1, peakIdx - 1);
else
    leftIdx = leftCand(end);
end
if isempty(rightCand)
    rightIdx = min(numel(signal), peakIdx + 1);
else
    rightIdx = rightCand(1);
end

if leftIdx >= rightIdx
    threshold = signal(peakIdx) * 10^(-3 / 20);
    leftIdx = peakIdx;
    while leftIdx > 1 && signal(leftIdx) > threshold
        leftIdx = leftIdx - 1;
    end
    rightIdx = peakIdx;
    while rightIdx < numel(signal) && signal(rightIdx) > threshold
        rightIdx = rightIdx + 1;
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

function dbVal = localToDb(x)
dbVal = 20 * log10(abs(x) + eps);
end

function angleOut = localNormAngle(angleIn)
angleOut = mod(angleIn + 90, 180) - 90;
end

function angleOut = localToRangeAxisAngle(angleIn)
angleOut = localNormAngle(angleIn);
if angleOut > 45
    angleOut = angleOut - 90;
elseif angleOut <= -45
    angleOut = angleOut + 90;
end
end

