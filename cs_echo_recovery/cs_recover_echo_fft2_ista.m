function [echoRec, info] = cs_recover_echo_fft2_ista(echoCut, maskObs, cfg)
%CS_RECOVER_ECHO_FFT2_ISTA 使用二维 FFT 稀疏先验恢复缺失回波。
% 输入：
%   echoCut  间断采样后的回波矩阵。
%   maskObs  与 echoCut 同尺寸的观测掩膜，true 表示已观测。
%   cfg      恢复参数，需包含 maxIter、tol、lambda2D 等字段。
% 输出：
%   echoRec  恢复后的完整回波矩阵。
%   info     迭代信息和收敛指标。

lambda = cfg.lambda2D;
[echoRec, info] = localRunFista(echoCut, maskObs, lambda, @localProx2D, ...
    @localTransform2D, cfg, ...
    '2d-fft');
end

function dataOut = localProx2D(dataIn, thresh)
spec = localTransform2D(dataIn);
spec = localComplexSoft(spec, thresh);
dataOut = localInverseTransform2D(spec);
end

function spec = localTransform2D(dataIn)
scaleValue = sqrt(numel(dataIn));
spec = fft2(dataIn) / scaleValue;
end

function dataOut = localInverseTransform2D(spec)
scaleValue = sqrt(numel(spec));
dataOut = ifft2(spec) * scaleValue;
end

function [echoRec, info] = localRunFista(echoCut, maskObs, lambda, proxFcn, transformFcn, cfg, methodName)
dataClass = class(echoCut);
maskObs = logical(maskObs);

[dataNorm, scaleValue] = localNormalizeEcho(echoCut, cfg.normalizeInput);
obsData = dataNorm;

xPrev = obsData;
yPrev = xPrev;
tPrev = 1;
relHistory = zeros(cfg.maxIter, 1);
objHistory = zeros(cfg.maxIter, 1);

timeStart = tic;
for iter = 1:cfg.maxIter
    gradValue = maskObs .* (yPrev - obsData);
    xNow = yPrev - gradValue;
    xNow = proxFcn(xNow, lambda);
    xNow(maskObs) = obsData(maskObs);

    relChange = norm(double(xNow(:) - xPrev(:))) / (norm(double(xPrev(:))) + eps);
    relHistory(iter) = relChange;
    objHistory(iter) = localObjective(xNow, obsData, maskObs, lambda, transformFcn);

    if cfg.useFista
        tNow = (1 + sqrt(1 + 4 * tPrev^2)) / 2;
        yNow = xNow + ((tPrev - 1) / tNow) * (xNow - xPrev);
        yNow(maskObs) = obsData(maskObs);
        tPrev = tNow;
        yPrev = yNow;
    else
        yPrev = xNow;
    end

    xPrev = xNow;

    if cfg.verbose && (iter == 1 || mod(iter, 20) == 0 || iter == cfg.maxIter)
        fprintf('  [%s] iter %d/%d, relChange = %.3e\n', ...
            methodName, iter, cfg.maxIter, relChange);
    end

    if relChange <= cfg.tol
        relHistory = relHistory(1:iter);
        objHistory = objHistory(1:iter);
        break;
    end
end
timeUsed = toc(timeStart);

echoRec = xPrev * scaleValue;
echoRec(maskObs) = echoCut(maskObs);
echoRec = cast(echoRec, dataClass);

obsDiff = echoRec(maskObs) - echoCut(maskObs);
info = struct();
info.method = methodName;
info.iterations = numel(relHistory);
info.converged = relHistory(end) <= cfg.tol;
info.lambda = lambda;
info.relChangeHistory = relHistory;
info.objectiveHistory = objHistory;
info.scaleValue = scaleValue;
info.runtimeSec = timeUsed;
info.observedConsistencyErr = localRelativeError(echoRec(maskObs), echoCut(maskObs));
info.maxObservedAbsErr = localMaxAbsError(obsDiff);
end

function [dataNorm, scaleValue] = localNormalizeEcho(dataIn, doNormalize)
if doNormalize
    scaleValue = max(abs(dataIn(:)));
else
    scaleValue = 1;
end

if isempty(scaleValue) || ~isfinite(scaleValue) || scaleValue <= 0
    scaleValue = 1;
end
dataNorm = dataIn / scaleValue;
end

function objValue = localObjective(xNow, obsData, maskObs, lambda, transformFcn)
fitValue = maskObs .* (xNow - obsData);
specValue = transformFcn(xNow);
objValue = 0.5 * sum(abs(fitValue(:)).^2) + lambda * sum(abs(specValue(:)));
end

function valueOut = localComplexSoft(valueIn, thresh)
amp = abs(valueIn);
scale = max(amp - thresh, 0) ./ (amp + eps);
valueOut = scale .* valueIn;
end

function relErr = localRelativeError(valueNow, valueRef)
den = norm(double(valueRef(:)));
if den <= eps
    relErr = norm(double(valueNow(:) - valueRef(:)));
else
    relErr = norm(double(valueNow(:) - valueRef(:))) / den;
end
end

function maxErr = localMaxAbsError(diffValue)
if isempty(diffValue)
    maxErr = 0;
else
    maxErr = max(abs(diffValue(:)));
end
end
