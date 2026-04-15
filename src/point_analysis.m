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

[geom, theory] = localBuildPhysicalContext(Br, Fr, PRF, vc, squintAngle, lambda);
sliceData = localPrepareSliceData(imgBP, cfg);
rotationData = localAnalyzeTiltAlignment(sliceData.up, cfg);
profileData = localBuildProfiles(rotationData.upAligned, sliceData.up, cfg.upN);
metricData = localBuildMetrics(profileData, cfg.upN, geom, theory);

pointAnaResult = localBuildResult(sliceData, rotationData, profileData, metricData, cfg);

localShowFigures(cfg, sliceData.cut, rotationData.upAligned, ...
    pointAnaResult.range.profile, pointAnaResult.azimuth.profile, ...
    rotationData.appliedRotationDeg);
localPrintSummary(pointAnaResult, metricData);
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

function [geom, theory] = localBuildPhysicalContext(Br, Fr, PRF, vc, squintAngle, lambda)
c = 3e8;
fd = 2 * vc * sin(squintAngle) / lambda;

geom = struct();
geom.rangeUnit = c / (2 * Fr);
geom.azimuthUnit = vc / PRF;

theory = struct();
theory.rangeIRW = 0.886 * c / (2 * Br);
if abs(fd) < eps
    theory.azimuthIRW = NaN;
else
    theory.azimuthIRW = 0.886 * (vc / fd);
end
end

function sliceData = localPrepareSliceData(imgBP, cfg)
amp = abs(imgBP);
[~, idxMax] = max(amp(:));
[cy, cx] = ind2sub(size(amp), idxMax);
cut = localExtractPatch(imgBP, cy, cx, cfg.cutH, cfg.cutW);
up = localUpsampleFFT(cut, cfg.upN);

sliceData = struct();
sliceData.peakInImage = [cy, cx];
sliceData.cut = cut;
sliceData.up = up;
sliceData.peakInUpSliceRaw = localFindPeak(up);
end

function rotationData = localAnalyzeTiltAlignment(up, cfg)
[tiltDeg, tiltInfo] = localEstimateTilt(up, cfg);
rotDeg = 0;
if cfg.enableTiltAlign && abs(tiltDeg) >= cfg.tiltApplyThresholdDeg
    rotDeg = -tiltDeg;
end

upAligned = localRotateComplex(up, rotDeg);
residualTiltDeg = NaN;
residualTiltInfo = struct('method', 'not-run', 'used', 'not-run');
if cfg.enableTiltAlign
    [residualTiltDeg, residualTiltInfo] = localEstimateTilt(upAligned, cfg);
    residualTiltInfo.used = 'residual-diagnostic';
    residualTiltInfo.estimatedFrom = 'rotated-upsampled-slice';
    residualTiltInfo.correctionAppliedTo = 'diagnostic-only';
end
tiltInfo.residualCheckDeg = residualTiltDeg;

rotationData = struct();
rotationData.upAligned = upAligned;
rotationData.peakInUpSlice = localFindPeak(upAligned);
rotationData.estimatedTiltDeg = tiltDeg;
rotationData.appliedRotationDeg = rotDeg;
rotationData.refineDeltaDeg = 0;
rotationData.residualTiltDeg = residualTiltDeg;
rotationData.tiltInfo = tiltInfo;
rotationData.residualTiltInfo = residualTiltInfo;
rotationData.analysisSource = 'rotated-corrected upsampled slice';
end

function profileData = localBuildProfiles(upAligned, upRaw, upN)
peakAligned = localFindPeak(upAligned);
peakRaw = localFindPeak(upRaw);

profileData = struct();
profileData.peakInUpSlice = peakAligned;
profileData.peakInUpSliceRaw = peakRaw;
profileData.rangeProfile = localNorm(upAligned(peakAligned(1), :).');
profileData.aziProfile = localNorm(upAligned(:, peakAligned(2)));
profileData.rangeProfileRaw = localNorm(upRaw(peakRaw(1), :).');
profileData.aziProfileRaw = localNorm(upRaw(:, peakRaw(2)));
profileData.upN = upN;
end

function metricData = localBuildMetrics(profileData, upN, geom, theory)
metricData = struct();
metricData.range = localMetrics(profileData.rangeProfile, upN, geom.rangeUnit);
metricData.azimuth = localMetrics(profileData.aziProfile, upN, geom.azimuthUnit);
metricData.rangeRaw = localMetrics(profileData.rangeProfileRaw, upN, geom.rangeUnit);
metricData.azimuthRaw = localMetrics(profileData.aziProfileRaw, upN, geom.azimuthUnit);
metricData.theory = theory;
end

function pointAnaResult = localBuildResult(sliceData, rotationData, profileData, metricData, cfg)
pointAnaResult = struct();
pointAnaResult.peakInImage = sliceData.peakInImage;
pointAnaResult.peakInUpSlice = profileData.peakInUpSlice;
pointAnaResult.peakInUpSliceRaw = profileData.peakInUpSliceRaw;
pointAnaResult.cut = sliceData.cut;
pointAnaResult.upSlice = rotationData.upAligned;
pointAnaResult.upSliceRaw = sliceData.up;
pointAnaResult.config = cfg;
pointAnaResult.analysisSource = rotationData.analysisSource;
pointAnaResult.range = localPackAxisResult( ...
    profileData.rangeProfile, metricData.range, metricData.theory.rangeIRW);
pointAnaResult.azimuth = localPackAxisResult( ...
    profileData.aziProfile, metricData.azimuth, metricData.theory.azimuthIRW);

pointAnaResult.raw = struct();
pointAnaResult.raw.range = localPackAxisResult( ...
    profileData.rangeProfileRaw, metricData.rangeRaw, metricData.theory.rangeIRW);
pointAnaResult.raw.azimuth = localPackAxisResult( ...
    profileData.aziProfileRaw, metricData.azimuthRaw, metricData.theory.azimuthIRW);

pointAnaResult.rotated = struct();
pointAnaResult.rotated.enabled = cfg.enableTiltAlign;
pointAnaResult.rotated.estimatedTiltDeg = rotationData.estimatedTiltDeg;
pointAnaResult.rotated.appliedRotationDeg = rotationData.appliedRotationDeg;
pointAnaResult.rotated.tiltInfo = rotationData.tiltInfo;
pointAnaResult.rotated.refineDeltaDeg = rotationData.refineDeltaDeg;
pointAnaResult.rotated.residualTiltDeg = rotationData.residualTiltDeg;
pointAnaResult.rotated.residualTiltInfo = rotationData.residualTiltInfo;
pointAnaResult.rotated.resultIsPrimary = true;
pointAnaResult.rotated.resultImageSource = rotationData.analysisSource;
end

function localShowFigures(cfg, cut, upAligned, rangeProfile, aziProfile, rotDeg)
if ~cfg.showFigures
    return;
end

localShowCutFigure(cut);
localShowUpsliceFigure(upAligned, rotDeg);
localShowContourFigure(upAligned);
localPlotProfile(rangeProfile, 'Range Profile', 'Range samples');
localPlotProfile(aziProfile, 'Azimuth Profile', 'Azimuth samples');
end

function localShowCutFigure(cut)
figure('Name', 'Target Cut', 'Color', 'w');
imagesc(abs(cut));
axis image;
colormap jet;
xlabel('Range samples');
ylabel('Azimuth samples');
title('Target Cut');
end

function localShowUpsliceFigure(upAligned, rotDeg)
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
end

function localShowContourFigure(upAligned)
figure('Name', 'Target Contour', 'Color', 'w');
contour(abs(upAligned));
axis image;
colormap jet;
xlabel('Range samples');
ylabel('Azimuth samples');
title('Target Contour');
end

function localPrintSummary(pointAnaResult, metricData)
disp('------------------------------------------------------------');
fprintf('Analysis source: %s\n', pointAnaResult.analysisSource);
fprintf('Range PSLR:   %.4f dB\n', metricData.range.PSLR_dB);
fprintf('Azimuth PSLR: %.4f dB\n', metricData.azimuth.PSLR_dB);
fprintf('Range ISLR:   %.4f dB\n', metricData.range.ISLR_dB);
fprintf('Azimuth ISLR: %.4f dB\n', metricData.azimuth.ISLR_dB);
fprintf('Range IRW:    %.6f m   Theory: %.6f m\n', ...
    metricData.range.IRW_m, metricData.theory.rangeIRW);
fprintf('Azimuth IRW:  %.6f m   Theory: %.6f m\n', ...
    metricData.azimuth.IRW_m, metricData.theory.azimuthIRW);
fprintf('Raw PSLR (R/A): %.4f / %.4f dB\n', ...
    metricData.rangeRaw.PSLR_dB, metricData.azimuthRaw.PSLR_dB);
fprintf('Raw ISLR (R/A): %.4f / %.4f dB\n', ...
    metricData.rangeRaw.ISLR_dB, metricData.azimuthRaw.ISLR_dB);
fprintf('Raw IRW  (R/A): %.6f / %.6f m\n', ...
    metricData.rangeRaw.IRW_m, metricData.azimuthRaw.IRW_m);
fprintf('Estimated tilt angle: %.3f deg\n', pointAnaResult.rotated.estimatedTiltDeg);
if isfinite(pointAnaResult.rotated.residualTiltDeg)
    fprintf('Residual tilt after rotation: %.3f deg\n', ...
        pointAnaResult.rotated.residualTiltDeg);
end
fprintf('Applied rotation: %.3f deg (refine delta: %.3f deg)\n', ...
    pointAnaResult.rotated.appliedRotationDeg, ...
    pointAnaResult.rotated.refineDeltaDeg);
fprintf('Tilt method: %s\n', pointAnaResult.rotated.tiltInfo.method);
end

function peakPos = localFindPeak(img)
[~, idxMax] = max(abs(img(:)));
[py, px] = ind2sub(size(img), idxMax);
peakPos = [py, px];
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
