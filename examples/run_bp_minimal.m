%% 最小主流程示例
% 通过配置覆盖运行 GOTCHA BP 主流程，不要直接修改生产源码。

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);

userCfg = struct();

% 推荐：显式指定数据根目录。
userCfg.path = struct( ...
    'dataRoot', 'E:/path/to/gotcha_BP');

% 如需覆盖实验参数，可按字段逐层补充。
% userCfg.interruption = struct( ...
%     'mode', 'random_gap', ...
%     'numSegments', 5, ...
%     'missingRatio', 0.07, ...
%     'randomSeed', 42);
%
% userCfg.display = struct( ...
%     'showInterruptedEcho', true, ...
%     'showProgress', true);
%
% userCfg.analysis = struct( ...
%     'pointAnaCfg', struct('showFigures', true));

result = main_gotha_bp(userCfg);
disp(result.meta.runOutput.runDir);
