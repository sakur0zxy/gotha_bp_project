function result = run_cs_echo_recovery_demo(userConfig)
%RUN_CS_ECHO_RECOVERY_DEMO 运行压缩感知回波恢复演示流程。
% 输入：
%   userConfig  可选，用于覆盖 cs_default_config 的结构体。
% 输出：
%   result      恢复、成像、点目标分析和输出文件信息。
%
% 第一次使用恢复流程时，推荐顺序是：
% 1. 先确认 main_gotha_bp(userCfg) 已经可以稳定跑通；
% 2. 再通过 csCfg.project 复用主流程数据与间断配置；
% 3. 最后只在 csCfg.recovery / csCfg.method 中调恢复算法参数。

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

% 具体恢复、成像对比和结果保存逻辑都在 cs_recovery_pipeline 中完成。
result = cs_recovery_pipeline(cfg);
end
