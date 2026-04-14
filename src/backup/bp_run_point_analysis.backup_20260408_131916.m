function [anaResult, anaInfo] = bp_run_point_analysis(imageBP, config, radar, track, pathInfo)
%BP_RUN_POINT_ANALYSIS 调用常用/point_analysis.m 进行点目标分析
%
% 说明：
% 1) point_analysis.m 是“脚本式”实现，需要在当前工作区提供一组变量；
% 2) 本函数负责把项目配置转换成这些变量，统一管理参数来源；
% 3) 执行结束后，返回脚本生成的 pointAnaResult。
%
% 输入：
%   imageBP   成像复图
%   config    项目配置
%   radar     雷达参数
%   track     轨迹结构体（X/Y/Z）
%   pathInfo  路径信息（需包含 commonDir）
%
% 输出：
%   anaResult 点目标分析结果结构体
%   anaInfo   点目标分析参数与来源信息

%% 1) 定位点目标分析脚本
scriptFile = fullfile(pathInfo.commonDir, 'point_analysis.m');
assert(exist(scriptFile, 'file') == 2, '未找到 point_analysis.m：%s', scriptFile);

% 保留一份配置副本，避免脚本内部变量名与本函数冲突
cfgMain = config;

%% 2) 组装脚本输入变量（point_analysis.m 依赖这些变量名）
% 注意：这里变量名必须与 point_analysis.m 中脚本变量一致。
imgBP = imageBP; %#ok<NASGU>

Br = localPickValue(cfgMain.analysis.physics.Br, radar.bandwidthHz, NaN); %#ok<NASGU>
Fr = localPickValue(cfgMain.analysis.physics.Fr, radar.bandwidthHz, NaN); %#ok<NASGU>

PRF = cfgMain.analysis.physics.PRF; %#ok<NASGU>
prfSource = 'manual';
if isempty(PRF)
    if cfgMain.analysis.autoDerivePRFFromTrack
        PRF = localEstimatePRF(track, cfgMain.analysis.physics.vc);
        prfSource = 'track-derived';
    end
    if isempty(PRF) || ~isfinite(PRF) || PRF <= 0
        PRF = cfgMain.analysis.defaultPRF;
        prfSource = 'default';
    end
end

vc = cfgMain.analysis.physics.vc; %#ok<NASGU>
squintAngle = deg2rad(cfgMain.analysis.physics.squintAngleDeg); %#ok<NASGU>

lambda = cfgMain.analysis.physics.lambda; %#ok<NASGU>
if isempty(lambda)
    % 若用户未给定波长，使用 w0 推导：lambda = c / f0 = c*2*pi / w0
    lambda = radar.c * 2 * pi / radar.w0;
end

% point_analysis.m 的可选配置
pointAnaCfg = cfgMain.analysis.pointAnaCfg; %#ok<NASGU>

%% 3) 执行脚本并读取结果
run(scriptFile);
assert(exist('pointAnaResult', 'var') == 1, ...
    'point_analysis 运行后未生成 pointAnaResult。');
anaResult = pointAnaResult;

%% 4) 返回参数元信息（用于追踪本次分析参数）
anaInfo = struct();
anaInfo.scriptPath = scriptFile;
anaInfo.Br_Hz = Br;
anaInfo.Fr_Hz = Fr;
anaInfo.PRF_Hz = PRF;
anaInfo.vc_mps = vc;
anaInfo.squintAngle_deg = cfgMain.analysis.physics.squintAngleDeg;
anaInfo.lambda_m = lambda;
anaInfo.prfSource = prfSource;
anaInfo.bandwidthFromData_Hz = radar.bandwidthHz;
end

function value = localPickValue(manualValue, autoValue, defaultValue)
%LOCALPICKVALUE 按“手动 > 自动 > 默认”优先级选择参数
if ~isempty(manualValue)
    value = manualValue;
elseif ~isempty(autoValue) && isfinite(autoValue) && autoValue > 0
    value = autoValue;
else
    value = defaultValue;
end
end

function prf = localEstimatePRF(track, platformSpeed)
%LOCALESTIMATEPRF 根据轨迹间距和平台速度估计 PRF
%
% 估计方法：
%   PRF ≈ 平台速度 / 相邻轨迹点平均间距

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
