function [anaResult, anaInfo] = bp_run_point_analysis(imageBP, config, radar, track, pathInfo)
%BP_RUN_POINT_ANALYSIS 运行点目标分析脚本并整理输入参数
%
% point_analysis.m 仍是脚本式实现，这里负责准备脚本所需变量。

%% 定位分析脚本
[scriptFile, scriptSource] = localResolvePointAnalysisScript(pathInfo);

%% 组装脚本输入
imgBP = imageBP; %#ok<NASGU>

Br = localPickValue(config.analysis.physics.Br, radar.bandwidthHz, NaN); %#ok<NASGU>
Fr = localPickValue(config.analysis.physics.Fr, radar.bandwidthHz, NaN); %#ok<NASGU>

vc = config.analysis.physics.vc; %#ok<NASGU>
PRF = []; %#ok<NASGU>
[PRF, prfSource] = localResolvePRF(config.analysis, track, vc);
squintAngle = deg2rad(config.analysis.physics.squintAngleDeg); %#ok<NASGU>
lambda = localResolveLambda(config.analysis.physics.lambda, radar); %#ok<NASGU>
pointAnaCfg = config.analysis.pointAnaCfg; %#ok<NASGU>

%% 执行脚本
run(scriptFile);
assert(exist('pointAnaResult', 'var') == 1, ...
    'point_analysis 运行后未生成 pointAnaResult。');
anaResult = pointAnaResult;

%% 返回参数元信息
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

function [scriptFile, scriptSource] = localResolvePointAnalysisScript(pathInfo)
projectScript = fullfile(pathInfo.srcRoot, 'point_analysis.m');
legacyScript = fullfile(pathInfo.commonDir, 'point_analysis.m');

if exist(projectScript, 'file') == 2
    scriptFile = projectScript;
    scriptSource = 'project-src';
    return;
end

if exist(legacyScript, 'file') == 2
    scriptFile = legacyScript;
    scriptSource = 'legacy-common';
    warning('bp_run_point_analysis:UsingLegacyScript', ...
        '未找到项目内 point_analysis.m，回退到常用目录版本：%s', scriptFile);
    return;
end

error('未找到 point_analysis.m。已检查：%s 与 %s', projectScript, legacyScript);
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
% 根据轨迹点平均间距估计 PRF

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
