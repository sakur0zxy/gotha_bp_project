function [imageBP, info] = bp_imaging_pipeline(track, echoData, radar, config, cutInfo)
%BP_IMAGING_PIPELINE 执行 BP 成像并返回成像元信息。
% 输入：
%   track     轨迹数据。
%   echoData  用于成像的回波矩阵。
%   radar     雷达参数。
%   config    运行配置。
%   cutInfo   当前可用的方位采样信息。
% 输出：
%   imageBP   成像结果。
%   info      成像元信息。
%
% 关键配置：
% - image.numPixels / xLimits / yLimits：成像网格。
% - iteration.J：递推加权参数。
% - display.*：只影响显示。

numType = localGetNumericClass(config.general.useSinglePrecision);
iterWeight = localCreateIterationWeights(config.iteration.J, numType);
imgSize = config.image.numPixels;

% 构造成像网格。
xAxis = linspace(config.image.xLimits(1), config.image.xLimits(2), imgSize);
yAxis = linspace(config.image.yLimits(1), config.image.yLimits(2), imgSize);
[gridX, gridY] = ndgrid(xAxis, yAxis);

% 只对有效方位位置成像，并对方位/距离向加窗。
activeAzIdx = cutInfo.activeAzIndices(:).';
aziWindow = hamming(numel(activeAzIdx)).';
rngWindow = hamming(radar.numRangeSamples);

trackX = cast(track.X, numType);
trackY = cast(track.Y, numType);
trackZ = cast(track.Z, numType);
echoData = cast(echoData, numType);
gridX = cast(gridX, numType);
gridY = cast(gridY, numType);
aziWindow = cast(aziWindow, numType);
rngWindow = cast(rngWindow, numType);

c = cast(radar.c, numType);
w0 = cast(radar.w0, numType);
deltaR = cast(radar.deltaR, numType);
phaseScale = cast(1i * 2, numType) * w0 / c;

imageBP = complex(zeros(imgSize, imgSize, numType));
imgHist1 = imageBP;
imgHist2 = imageBP;
imgHist3 = imageBP;

showProgress = config.display.showProgress;
progressStep = config.display.progressUpdateInterval;
progressScale = config.display.progressScale;
hImage = [];

if showProgress
    figure('Name', 'BP Imaging Progress', 'Color', 'w');
    hImage = imagesc(abs(imageBP));
    title('BP 成像过程');
    xlabel('横向像素');
    ylabel('纵向像素');
    axis image;
    colormap jet;
end

numAz = cutInfo.numAzSamples;
numRngUp = radar.numRangeSamplesUp;
expectedUsedCount = numel(activeAzIdx);
halfBin = numRngUp / 2;
deltaRDouble = double(deltaR);
usedCount = 0;

for winIdx = 1:expectedUsedCount
    azIdx = activeAzIdx(winIdx);
    if azIdx < 1 || azIdx > numAz
        continue;
    end

    usedCount = usedCount + 1;

    xc = trackX(azIdx);
    yc = trackY(azIdx);
    zc = trackZ(azIdx);

    % 单脉冲先做距离向 FFT，再映射到图像网格。
    onePulse = echoData(:, azIdx) * aziWindow(winIdx);
    onePulse = fftshift(fft(onePulse .* rngWindow, numRngUp));

    refRange = sqrt(xc.^2 + yc.^2 + zc.^2);
    rangeMat = sqrt((xc - gridX).^2 + (yc - gridY).^2 + zc.^2) - refRange;

    % 按距离差找到频域采样位置，越界点直接夹到边界。
    sampleIdx = round(-double(rangeMat) / deltaRDouble) + halfBin;
    sampleIdx(sampleIdx < 1) = 1;
    sampleIdx(sampleIdx > numRngUp) = numRngUp;
    validMask = sampleIdx > 1 & sampleIdx < numRngUp;

    % 三阶递推权重是原始实现的一部分，不是额外后处理。
    currImg = onePulse(sampleIdx) .* cast(validMask, numType) .* exp(phaseScale * rangeMat);
    imageBP = currImg ...
        + iterWeight(1) * imgHist1 ...
        + iterWeight(2) * imgHist2 ...
        + iterWeight(3) * imgHist3;

    imgHist3 = imgHist2;
    imgHist2 = imgHist1;
    imgHist1 = imageBP;

    if showProgress && ( ...
            usedCount == 1 || ...
            mod(usedCount, progressStep) == 0 || ...
            usedCount == expectedUsedCount)
        showScale = mean(abs(imageBP(:)));
        if showScale > 0
            set(hImage, 'CData', abs(imageBP) / (showScale * progressScale));
        else
            set(hImage, 'CData', abs(imageBP));
        end
        drawnow limitrate;
    end
end

info = struct();
info.numericClass = numType;
info.numPixels = imgSize;
info.numAzSamples = numAz;
info.usedSamples = usedCount;
info.numRangeSamples = radar.numRangeSamples;
info.numRangeSamplesUp = radar.numRangeSamplesUp;
end

function numericClass = localGetNumericClass(useSinglePrecision)
if useSinglePrecision
    numericClass = 'single';
else
    numericClass = 'double';
end
end

function iterWeights = localCreateIterationWeights(J, numericClass)
% J 控制递推历史项权重；保持默认值通常最稳。
lam = 1 - 2.8 / J;
mi = pi / (2 * J / 3);
ga = 1 - 3 / J;

iterWeights = zeros(1, 3);
iterWeights(1) = -(-lam * exp(-1i * mi) - lam * exp(1i * mi) - ga);
iterWeights(2) = -(lam^2 + lam * ga * exp(-1i * mi) + lam * ga * exp(1i * mi));
iterWeights(3) = (lam^2) * ga;
iterWeights = cast(iterWeights, numericClass);
end
