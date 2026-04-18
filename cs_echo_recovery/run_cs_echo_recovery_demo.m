function result = run_cs_echo_recovery_demo(userConfig)
%RUN_CS_ECHO_RECOVERY_DEMO 运行压缩感知回波恢复演示流程。
% 输入：
%   userConfig  可选，用于覆盖 cs_default_config 的结构体。
% 输出：
%   result      恢复、成像、点目标分析和输出文件信息。

csRoot = fileparts(mfilename('fullpath'));
projectRoot = fileparts(csRoot);
addpath(projectRoot);
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
addpath(csRoot);

cfg = cs_default_config();
if nargin >= 1 && ~isempty(userConfig)
    cfg = bp_merge_config(cfg, userConfig);
end

result = cs_recovery_pipeline(cfg);
end
