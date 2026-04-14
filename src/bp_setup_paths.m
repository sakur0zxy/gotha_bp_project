function context = bp_setup_paths()
%BP_SETUP_PATHS 初始化项目路径，并返回路径上下文
% 说明：
% 1) projectRoot 指向 gotha_bp_project 目录；
% 2) workspaceRoot 指向项目上一级目录（包含数据与旧脚本）。

thisFile = mfilename('fullpath');
srcRoot = fileparts(thisFile);
projectRoot = fileparts(srcRoot);
workspaceRoot = fileparts(projectRoot);

% 兼容旧工程中常用函数目录
commonDir = fullfile(workspaceRoot, '常用');
gotchaDir = fullfile(workspaceRoot, 'gotcha_BP');
if exist(commonDir, 'dir') == 7
    addpath(commonDir);
end
if exist(gotchaDir, 'dir') == 7
    addpath(gotchaDir);
end

context = struct();
context.srcRoot = srcRoot;
context.projectRoot = projectRoot;
context.workspaceRoot = workspaceRoot;
context.commonDir = commonDir;
context.gotchaDir = gotchaDir;
end
