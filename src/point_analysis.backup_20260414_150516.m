%% 点目标剖面与旁瓣分析
% 脚本输入：imgBP, Br, Fr, PRF, vc, squintAngle, lambda
% 可选配置：pointAnaCfg
% 输出结果：pointAnaResult

%% 输入检查
needVars = {'imgBP', 'Br', 'Fr', 'PRF', 'vc', 'squintAngle', 'lambda'};
for i = 1:numel(needVars)
    if ~exist(needVars{i}, 'var')
        error('point_analysis:MissingInput', '缺少输入变量：%s', needVars{i});
    end
end

%% 参数配置
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
rangeUnit = c / (2 * Fr);      % 距离向采样间隔（m）
aziUnit = v / prf;             % 方位向采样间隔（m）
analysisSource = 'upSlice (rotated-corrected)';

%% 目标切片
amp = abs(img);
[~, idxMax] = max(amp(:));
[cy, cx] = ind2sub(size(amp), idxMax);

cut = localExtractPatch(img, cy, cx, cfg.cutH, cfg.cutW);

if cfg.showFigures
    figure('Name', '目标区域切片', 'Color', 'w');
    imagesc(abs(cut));
    axis image;
    colormap jet;
    xlabel('距离向（采样点）');
    ylabel('方位向（采样点）');
    title('目标区域切片');
end

%% 升采样
up = localUpsampleFFT(cut, cfg.upN);

%% 倾斜估计与旋转
[tiltDeg, tiltInfo] = localEstimateTilt(up, cfg);
rotDeg = 0;
refineDeltaDeg = 0;
residualTiltDeg = NaN;
residualTiltInfo = struct('method', 'not-run', 'used', 'not-run');

if cfg.enableTiltAlign && abs(tiltDeg) >= cfg.tiltApplyThresholdDeg
    rotDeg = -tiltDeg;
end

upAligned = localRotateComplex(up, rotDeg);

% 旋转后再估一次残余角，避免过旋或欠旋。
if cfg.enableTiltAlign && cfg.tiltResidualRefineEnable && abs(rotDeg) > 0
    cfgResidual = cfg;
    cfgResidual.tiltUseSidelobeRefine = false;
    [residualTiltDeg, residualTiltInfo] = localEstimateTilt(upAligned, cfgResidual);
    residualTiltInfo.method = [residualTiltInfo.method, '+residual-mainlobe'];

    if isfinite(residualTiltDeg) && abs(residualTiltDeg) >= cfg.tiltResidualRefineThresholdDeg
        refineDeltaDeg = -cfg.tiltResidualRefineGain * residualTiltDeg;
        refineDeltaDeg = max(min(refineDeltaDeg, cfg.tiltResidualRefineMaxStepDeg), ...
            -cfg.tiltResidualRefineMaxStepDeg);

        rotDeg = rotDeg + refineDeltaDeg;
        upAligned = localRotateComplex(up, rotDeg);

        [residualTiltDeg, residualTiltInfo] = localEstimateTilt(upAligned, cfgResidual);
        residualTiltInfo.method = [residualTiltInfo.method, '+post'];
    end
end

% 旋转后重新找峰值点，再提取剖面。
[~, idxUpMax] = max(abs(upAligned(:)));
[py, px] = ind2sub(size(upAligned), idxUpMax);

% 原始上采样图仅作为对照保留。
[~, idxUpRawMax] = max(abs(up(:)));
[pyRaw, pxRaw] = ind2sub(size(up), idxUpRawMax);

%% 图形输出
if cfg.showFigures
    figure('Name', '升采样结果', 'Color', 'w');
    imagesc(abs(upAligned));
    axis image;
    colormap jet;
    xlabel('距离向（采样点）');
    ylabel('方位向（采样点）');
    if abs(rotDeg) > 0
        title(sprintf('升采样结果（已旋转 %.2f° 校正）', rotDeg));
    else
        title('升采样结果');
    end

    figure('Name', '目标轮廓图', 'Color', 'w');
    contour(abs(upAligned));
    axis image;
    colormap jet;
    xlabel('距离向（采样点）');
    ylabel('方位向（采样点）');
    title('目标轮廓图');
end

%% 剖面提取
rangeProfile = upAligned(py, :).';
aziProfile = upAligned(:, px);
rangeProfile = localNorm(rangeProfile);
aziProfile = localNorm(aziProfile);

rangeProfileRaw = up(pyRaw, :).';
aziProfileRaw = up(:, pxRaw);
rangeProfileRaw = localNorm(rangeProfileRaw);
aziProfileRaw = localNorm(aziProfileRaw);

if cfg.showFigures
    localPlotProfile(rangeProfile, '距离向剖面图', '距离向（采样点）');
    localPlotProfile(aziProfile, '方位向剖面图', '方位向（采样点）');
end

%% 指标计算
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

%% 结果打包
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

%% 文本输出
disp('------------------------------------------------------------');
fprintf('剖面/旁瓣分析数据源：%s\n', pointAnaResult.analysisSource);
fprintf('距离向 PSLR：%.4f dB\n', mR.PSLR_dB);
fprintf('方位向 PSLR：%.4f dB\n', mA.PSLR_dB);
fprintf('距离向 ISLR：%.4f dB\n', mR.ISLR_dB);
fprintf('方位向 ISLR：%.4f dB\n', mA.ISLR_dB);
fprintf('距离向 IRW ：%.6f m   理论值：%.6f m\n', mR.IRW_m, irwRTheory);
fprintf('方位向 IRW ：%.6f m   理论值：%.6f m\n', mA.IRW_m, irwATheory);
fprintf('原图对照 PSLR（距/方）：%.4f / %.4f dB\n', mRRaw.PSLR_dB, mARaw.PSLR_dB);
fprintf('原图对照 ISLR（距/方）：%.4f / %.4f dB\n', mRRaw.ISLR_dB, mARaw.ISLR_dB);
fprintf('原图对照 IRW （距/方）：%.6f / %.6f m\n', mRRaw.IRW_m, mARaw.IRW_m);
fprintf('估计旁瓣倾斜角：%.3f deg\n', tiltDeg);
if isfinite(residualTiltDeg)
    fprintf('旋转后残余倾斜角：%.3f deg\n', residualTiltDeg);
end
fprintf('实际旋转角度：%.3f deg（闭环微调：%.3f deg）\n', rotDeg, refineDeltaDeg);
fprintf('估角方法：%s\n', tiltInfo.method);

%% 局部函数
function cfg = localDefaultCfg()
cfg = struct();
cfg.cutH = 32;                     % 切片高度（方位向）
cfg.cutW = 32;                     % 切片宽度（距离向）
cfg.upN = 16;                      % 上采样倍数
cfg.showFigures = true;            % 是否出图

cfg.enableTiltAlign = true;        % 是否执行倾斜校正
cfg.tiltApplyThresholdDeg = 0.0;   % 倾斜角超过该阈值才旋转（默认全量按估角修正）
cfg.tiltWindowRadius = 24;         % 倾斜估计窗口半径（上采样点）

cfg.tiltMainlobeDb = -6;           % 主瓣掩膜门限（dB）
cfg.tiltSidelobeDbLow = -35;       % 旁瓣门限下限（dB）
cfg.tiltSidelobeDbHigh = -8;       % 旁瓣门限上限（dB）
cfg.tiltCenterExcludeRadius = 4;   % 排除主瓣中心半径（上采样点）
cfg.tiltMinMainPoints = 20;        % PCA 主瓣最小点数
cfg.tiltMinSidePoints = 20;        % 旁瓣二次校正最小点数
cfg.tiltUseSidelobeRefine = true;  % 是否启用旁瓣二次校正
cfg.tiltSideSearchDeg = 20;        % 二次校正相对粗角搜索范围（±deg）
cfg.tiltSideStepDeg = 0.2;         % 二次校正角步长（deg）

cfg.tiltFuseDisagreeDeg = 4;       % PCA 与旁瓣角度差超过该值，判为分歧（deg）
cfg.tiltPcaWeightStrong = 0.8;     % 主瓣各向异性强时，PCA 权重
cfg.tiltPcaWeightWeak = 0.6;       % 主瓣各向异性弱但无分歧时，PCA 权重
cfg.tiltPcaWeightDisagree = 0.9;   % 分歧场景下，PCA 主导权重

cfg.tiltResidualRefineEnable = true;        % 是否启用残余角闭环微调
cfg.tiltResidualRefineThresholdDeg = 0.25;  % 残余角超过该值才微调（deg）
cfg.tiltResidualRefineGain = 0.7;           % 微调增益（0~1）
cfg.tiltResidualRefineMaxStepDeg = 2.0;     % 单次微调最大角度（deg）
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
assert(cfg.cutH >= 8 && mod(cfg.cutH, 2) == 0, 'cutH 需为 >=8 的偶数。');
assert(cfg.cutW >= 8 && mod(cfg.cutW, 2) == 0, 'cutW 需为 >=8 的偶数。');
assert(cfg.upN >= 2 && mod(cfg.upN, 1) == 0, 'upN 需为 >=2 的整数。');
assert(cfg.tiltWindowRadius >= 4, 'tiltWindowRadius 过小。');
assert(cfg.tiltApplyThresholdDeg >= 0, 'tiltApplyThresholdDeg 需非负。');
assert(cfg.tiltMainlobeDb < 0, 'tiltMainlobeDb 需小于 0 dB。');
assert(cfg.tiltSidelobeDbLow < cfg.tiltSidelobeDbHigh, ...
    'tiltSidelobeDbLow 必须小于 tiltSidelobeDbHigh。');
assert(cfg.tiltCenterExcludeRadius >= 0, 'tiltCenterExcludeRadius 需非负。');
assert(cfg.tiltMinMainPoints >= 5, 'tiltMinMainPoints 过小。');
assert(cfg.tiltMinSidePoints >= 5, 'tiltMinSidePoints 过小。');
assert(cfg.tiltSideSearchDeg > 0, 'tiltSideSearchDeg 需大于 0。');
assert(cfg.tiltSideStepDeg > 0, 'tiltSideStepDeg 需大于 0。');
assert(cfg.tiltFuseDisagreeDeg >= 0, 'tiltFuseDisagreeDeg 需非负。');
assert(cfg.tiltPcaWeightStrong >= 0 && cfg.tiltPcaWeightStrong <= 1, ...
    'tiltPcaWeightStrong 需在 [0,1]。');
assert(cfg.tiltPcaWeightWeak >= 0 && cfg.tiltPcaWeightWeak <= 1, ...
    'tiltPcaWeightWeak 需在 [0,1]。');
assert(cfg.tiltPcaWeightDisagree >= 0 && cfg.tiltPcaWeightDisagree <= 1, ...
    'tiltPcaWeightDisagree 需在 [0,1]。');
assert(cfg.tiltResidualRefineThresholdDeg >= 0, ...
    'tiltResidualRefineThresholdDeg 需非负。');
assert(cfg.tiltResidualRefineGain > 0 && cfg.tiltResidualRefineGain <= 1, ...
    'tiltResidualRefineGain 需在 (0,1]。');
assert(cfg.tiltResidualRefineMaxStepDeg > 0, ...
    'tiltResidualRefineMaxStepDeg 需大于 0。');
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

function [ang, info] = localEstimateTilt(img, cfg)
% 用主瓣 PCA 和旁瓣扫描估计距离向倾斜角（[-45, 45] 度）。

info = struct();
info.method = 'mainlobe-pca+sidelobe-refine';
info.mainPoints = 0;
info.sidePoints = 0;
info.pcaRawDeg = NaN;
info.pcaRangeDeg = NaN;
info.sideRangeDeg = NaN;
info.fallbackRangeDeg = NaN;
info.anisotropy = NaN;
info.used = '';

amp = abs(img);
mx = max(amp(:));
if mx <= 0
    ang = 0;
    info.used = 'zero-image';
    return;
end

amp = amp / mx;
[yy, xx] = ndgrid(1:size(img, 1), 1:size(img, 2));
[~, idx] = max(amp(:));
[cy, cx] = ind2sub(size(amp), idx);

x = xx - cx;
y = yy - cy;
r2 = x.^2 + y.^2;
winMask = abs(x) <= cfg.tiltWindowRadius & abs(y) <= cfg.tiltWindowRadius;
db = 20 * log10(amp + eps);

mainMask = winMask & db >= cfg.tiltMainlobeDb;
info.mainPoints = nnz(mainMask);

if info.mainPoints >= cfg.tiltMinMainPoints
    w = amp.^2;
    w(~mainMask) = 0;
    wSum = sum(w(:));
    if wSum > 0
        xMean = sum(w(:) .* x(:)) / wSum;
        yMean = sum(w(:) .* y(:)) / wSum;
        dx = x - xMean;
        dy = y - yMean;
        Cxx = sum(w(:) .* dx(:) .* dx(:)) / wSum;
        Cyy = sum(w(:) .* dy(:) .* dy(:)) / wSum;
        Cxy = sum(w(:) .* dx(:) .* dy(:)) / wSum;

        pcaRaw = localNormAngle(0.5 * atan2d(2 * Cxy, Cxx - Cyy));
        pcaRange = localToRangeAxisAngle(pcaRaw);
        anis = abs(Cxx - Cyy) / (Cxx + Cyy + eps);
    else
        pcaRaw = NaN;
        pcaRange = NaN;
        anis = NaN;
    end
else
    pcaRaw = NaN;
    pcaRange = NaN;
    anis = NaN;
end

info.pcaRawDeg = pcaRaw;
info.pcaRangeDeg = pcaRange;
info.anisotropy = anis;

sideRange = NaN;
sideMask = winMask ...
    & db >= cfg.tiltSidelobeDbLow ...
    & db <= cfg.tiltSidelobeDbHigh ...
    & (r2 >= cfg.tiltCenterExcludeRadius^2);
info.sidePoints = nnz(sideMask);

if cfg.tiltUseSidelobeRefine && info.sidePoints >= cfg.tiltMinSidePoints
    sideImg = amp;
    sideImg(~sideMask) = 0;

    if isfinite(pcaRange)
        base = pcaRange;
    else
        base = 0;
    end

    scanAngles = (base - cfg.tiltSideSearchDeg):cfg.tiltSideStepDeg:(base + cfg.tiltSideSearchDeg);
    [bestAngle, ~] = localScanBestAngle(sideImg, cy, cx, cfg.tiltWindowRadius, scanAngles);
    sideRange = localToRangeAxisAngle(bestAngle);
end
info.sideRangeDeg = sideRange;

if ~isfinite(pcaRange) && ~isfinite(sideRange)
    fallbackAngles = -89:1:89;
    [fallback, ~] = localScanBestAngle(amp .* winMask, cy, cx, cfg.tiltWindowRadius, fallbackAngles);
    fallback = localToRangeAxisAngle(fallback);
else
    fallback = NaN;
end
info.fallbackRangeDeg = fallback;

if isfinite(sideRange) && isfinite(pcaRange)
    diffPS = localNormAngle(sideRange - pcaRange);
    if abs(diffPS) > cfg.tiltFuseDisagreeDeg
        wPca = cfg.tiltPcaWeightDisagree;
        info.used = 'pca-dominant(disagree)';
    else
        if isfinite(anis) && anis >= 0.08
            wPca = cfg.tiltPcaWeightStrong;
        else
            wPca = cfg.tiltPcaWeightWeak;
        end
        info.used = 'pca+side(weighted)';
    end
    wPca = min(max(wPca, 0), 1);
    ang = wPca * pcaRange + (1 - wPca) * sideRange;
elseif isfinite(sideRange)
    ang = sideRange;
    info.used = 'side';
elseif isfinite(pcaRange)
    ang = pcaRange;
    info.used = 'pca';
elseif isfinite(fallback)
    ang = fallback;
    info.used = 'fallback-scan';
else
    ang = 0;
    info.used = 'default-zero';
end

ang = localToRangeAxisAngle(ang);
end

function [bestAngle, bestScore] = localScanBestAngle(img, cy, cx, halfLen, angleList)
score = zeros(size(angleList));
for k = 1:numel(angleList)
    p = localLineSample(img, cy, cx, angleList(k), halfLen);
    score(k) = sum(abs(p).^2);
end
[bestScore, idx] = max(score);
bestAngle = angleList(idx);
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

function p = localLineSample(img, cy, cx, angDeg, halfLen)
t = (-halfLen:halfLen).';
x = cx + t * cosd(angDeg);
y = cy + t * sind(angDeg);
p = interp2(img, x, y, 'linear', 0);
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
ylabel('幅度（dB）');
title([figName, '（旋转修正后）']);
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
if s(1) > s(2), idx = [1; idx(:)]; end
if s(end) > s(end-1), idx = [idx(:); n]; end
idx = unique(idx(:));
end

function [l, r] = localMainlobeBound(s, i0)
mins = find(s(2:end-1) <= s(1:end-2) & s(2:end-1) < s(3:end)) + 1;
lCand = mins(mins < i0);
rCand = mins(mins > i0);

if isempty(lCand), l = max(1, i0 - 1); else, l = lCand(end); end
if isempty(rCand), r = min(numel(s), i0 + 1); else, r = rCand(1); end

if l >= r
    thr = s(i0) * 10^(-3/20);
    l = i0;
    while l > 1 && s(l) > thr, l = l - 1; end
    r = i0;
    while r < numel(s) && s(r) > thr, r = r + 1; end
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
