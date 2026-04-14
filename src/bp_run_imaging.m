function [imageBP, info] = bp_run_imaging(track, echoData, radar, iterWeight, config, cutInfo)
%BP_RUN_IMAGING BP 成像核心

%% 构建成像网格
numType = bp_get_numeric_class(config.general.useSinglePrecision);
imgSize = config.image.numPixels;

xAxis = linspace(config.image.xLimits(1), config.image.xLimits(2), imgSize);
yAxis = linspace(config.image.yLimits(1), config.image.yLimits(2), imgSize);
[gridX, gridY] = ndgrid(xAxis, yAxis);

%% 构建窗函数
activeAzIdx = cutInfo.activeAzIndices(:).';
aziWindow = hamming(numel(activeAzIdx)).';
rngWindow = hamming(radar.numRangeSamples);

%% 统一数据精度
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

%% 初始化图像与历史项
imageBP = complex(zeros(imgSize, imgSize, numType));
imgHist1 = imageBP;
imgHist2 = imageBP;
imgHist3 = imageBP;

%% 初始化过程显示
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

%% 缓存循环常量
numAz = cutInfo.numAzSamples;
numRngUp = radar.numRangeSamplesUp;
expectedUsedCount = numel(activeAzIdx);
halfBin = numRngUp / 2;
deltaRDouble = double(deltaR);

%% BP 主循环
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

    onePulse = echoData(:, azIdx) * aziWindow(winIdx);
    onePulse = fftshift(fft(onePulse .* rngWindow, numRngUp));

    refRange = sqrt(xc.^2 + yc.^2 + zc.^2);
    rangeMat = sqrt((xc - gridX).^2 + (yc - gridY).^2 + zc.^2) - refRange;

    sampleIdx = round(-double(rangeMat) / deltaRDouble) + halfBin;
    sampleIdx(sampleIdx < 1) = 1;
    sampleIdx(sampleIdx > numRngUp) = numRngUp;
    validMask = sampleIdx > 1 & sampleIdx < numRngUp;

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

%% 返回统计信息
info = struct();
info.numericClass = numType;
info.numPixels = imgSize;
info.numAzSamples = numAz;
info.usedSamples = usedCount;
info.numRangeSamples = radar.numRangeSamples;
info.numRangeSamplesUp = radar.numRangeSamplesUp;
end
