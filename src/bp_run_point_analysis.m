function [anaResult, anaInfo] = bp_run_point_analysis(imageBP, config, radar, track, pathInfo)
%BP_RUN_POINT_ANALYSIS 组织点目标分析输入并调用分析函数。

[scriptFile, scriptSource] = localResolvePointAnalysisFile(pathInfo);

Br = localPickValue(config.analysis.physics.Br, radar.bandwidthHz, NaN);
Fr = localPickValue(config.analysis.physics.Fr, radar.bandwidthHz, NaN);
vc = config.analysis.physics.vc;
[PRF, prfSource] = localResolvePRF(config.analysis, track, vc);
squintAngle = deg2rad(config.analysis.physics.squintAngleDeg);
lambda = localResolveLambda(config.analysis.physics.lambda, radar);
pointAnaCfg = config.analysis.pointAnaCfg;

anaResult = localCallPointAnalysis( ...
    scriptFile, imageBP, Br, Fr, PRF, vc, squintAngle, lambda, pointAnaCfg);

anaInfo = struct();
anaInfo.scriptPath = scriptFile;
anaInfo.Br_Hz = Br;
anaInfo.Fr_Hz = Fr;
anaInfo.PRF_Hz = PRF;
anaInfo.vc_mps = vc;
anaInfo.squintAngle_deg = config.analysis.physics.squintAngleDeg;
anaInfo.lambda_m = lambda;
anaInfo.prfSource = prfSource;
anaInfo.bandwidthFromData_Hz = radar.bandwidthHz;
anaInfo.scriptSource = scriptSource;
end

function anaResult = localCallPointAnalysis(scriptFile, imageBP, Br, Fr, PRF, vc, squintAngle, lambda, pointAnaCfg)
scriptDir = fileparts(scriptFile);
originalPath = path;
cleanup = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(scriptDir, '-begin');

pointAnaFunc = str2func('point_analysis');
anaResult = pointAnaFunc(imageBP, Br, Fr, PRF, vc, squintAngle, lambda, pointAnaCfg);
end

function [scriptFile, scriptSource] = localResolvePointAnalysisFile(pathInfo)
projectScript = fullfile(pathInfo.srcRoot, 'point_analysis.m');

if exist(projectScript, 'file') == 2
    scriptFile = projectScript;
    scriptSource = 'project-src';
    return;
end

error('未找到项目内 point_analysis.m：%s', projectScript);
end

function value = localPickValue(manualValue, autoValue, defaultValue)
if ~isempty(manualValue)
    value = manualValue;
elseif ~isempty(autoValue) && isfinite(autoValue) && autoValue > 0
    value = autoValue;
else
    value = defaultValue;
end
end

function [prf, source] = localResolvePRF(analysisCfg, track, platformSpeed)
prf = analysisCfg.physics.PRF;
source = 'manual';

if isempty(prf) && analysisCfg.autoDerivePRFFromTrack
    prf = localEstimatePRF(track, platformSpeed);
    source = 'track-derived';
end

if isempty(prf) || ~isfinite(prf) || prf <= 0
    prf = analysisCfg.defaultPRF;
    source = 'default';
end
end

function lambda = localResolveLambda(lambdaManual, radar)
lambda = lambdaManual;
if isempty(lambda)
    lambda = radar.c * 2 * pi / radar.w0;
end
end

function prf = localEstimatePRF(track, platformSpeed)
x = track.X(:);
y = track.Y(:);
z = track.Z(:);

if numel(x) < 2
    prf = [];
    return;
end

stepDist = hypot(hypot(diff(x), diff(y)), diff(z));
stepDist = stepDist(isfinite(stepDist) & stepDist > 0);

if isempty(stepDist)
    prf = [];
    return;
end

meanStep = mean(stepDist);
if meanStep <= 0
    prf = [];
else
    prf = platformSpeed / meanStep;
end
end
