function radar = bp_build_radar_params(cfg, numRangeSamples, freqVec)
%BP_BUILD_RADAR_PARAMS 根据配置和数据构建雷达参数

c = cfg.radar.c;
w0 = cfg.radar.w0;
tau = cfg.radar.tau;
rangeUpsampleFactor = cfg.radar.rangeUpsampleFactor;

if isempty(freqVec)
    error('freqVec 不能为空。');
end
freqVec = freqVec(:).';
firstFreq = freqVec(1);

if numel(freqVec) >= 2
    freqStepHz = mean(diff(freqVec));
    bandwidthHz = abs(freqVec(end) - freqVec(1));
else
    freqStepHz = NaN;
    bandwidthHz = NaN;
end

Ts = tau / numRangeSamples;
numRangeSamplesUp = rangeUpsampleFactor * numRangeSamples;
y0 = (w0 - firstFreq * 2 * pi) / tau * 2;
deltaR = c * pi / (y0 * Ts * numRangeSamplesUp);

radar = struct();
radar.c = c;
radar.w0 = w0;
radar.tau = tau;
radar.Ts = Ts;
radar.y0 = y0;
radar.firstFreq = firstFreq;
radar.freqVectorHz = freqVec;
radar.freqStepHz = freqStepHz;
radar.bandwidthHz = bandwidthHz;
radar.numRangeSamples = numRangeSamples;
radar.numRangeSamplesUp = numRangeSamplesUp;
radar.deltaR = deltaR;
end
