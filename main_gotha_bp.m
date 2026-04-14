function result = main_gotha_bp(userConfig)
%MAIN_GOTHA_BP GOTCHA 间断采样 BP 成像主入口
%
% 用法：
%   result = main_gotha_bp();
%   result = main_gotha_bp(userConfig);
%
% 输入：
%   userConfig   可选，结构体。只需填写你要覆盖的配置字段。
%
% 输出：
%   result.image                 最终 BP 复图像
%   result.outputFile            成像图输出文件
%   result.config                实际生效配置
%   result.interruptionInfo      间断采样统计信息
%   result.meta                  运行元信息（含数据目录、输出目录等）
%   result.pointAnalysis         点目标分析结果（若启用）
%   result.pointAnalysisMeta     点目标分析元信息（参数来源等）
%   result.pointAnalysisFiles    点目标分析输出文件路径

%% 加载项目路径
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));

%% 读取配置
config = default_config();
if nargin >= 1 && ~isempty(userConfig)
    config = bp_merge_config(config, userConfig);
end
config = bp_validate_config(config);
if ~isfield(config.output, 'saveInterruptionText')
    config.output.saveInterruptionText = true;
end
if ~isfield(config.output, 'saveInterruptionImage')
    config.output.saveInterruptionImage = true;
end
if strcmp(char(string(config.interruption.mode)), 'random_gap')
    config.interruption.randomSeed = bp_resolve_random_seed(config.interruption.randomSeed);
end

%% 初始化路径与输出目录
pathInfo = bp_setup_paths();
runOutput = bp_prepare_run_output_dir(config, pathInfo);

%% 读取数据
[track, echoData, radar, dataRoot] = bp_load_data(config, pathInfo);

%% 生成间断采样回波
[echoCut, cutInfo] = bp_apply_interruption(echoData, track, config.interruption);
interruptionFiles = bp_save_interruption_output(cutInfo, config, runOutput.runDir);

if config.display.showInterruptedEcho
    figure('Name', 'Interrupted Echo', 'Color', 'w');
    imagesc(abs(echoCut));
    title('间断采样后的回波矩阵');
    xlabel('方位向采样点');
    ylabel('距离向采样点');
    colormap jet;
end

%% 计算迭代权重
numType = bp_get_numeric_class(config.general.useSinglePrecision);
iterWeight = bp_create_iteration_weights(config.iteration.J, numType);

%% 执行 BP 成像
[imageBP, imageMeta] = bp_run_imaging(track, echoCut, radar, iterWeight, config, cutInfo);

%% 点目标分析
pointResult = [];
pointMeta = struct('enabled', false);
pointFiles = struct( ...
    'matFile', '', ...
    'textFile', '', ...
    'imageFile', '', ...
    'imageFiles', struct( ...
        'upslice', '', ...
        'contour', '', ...
        'rangeProfile', '', ...
        'azimuthProfile', ''));

if config.analysis.enablePointAnalysis
    try
        [pointResult, pointMeta] = bp_run_point_analysis(imageBP, config, radar, track, pathInfo);
        pointFiles = bp_save_point_analysis_output(pointResult, pointMeta, config, runOutput.runDir);
        pointMeta.enabled = true;
    catch err
        pointMeta.enabled = false;
        pointMeta.errorMessage = err.message;
        warning('main_gotha_bp:PointAnalysisFailed', '点目标分析失败：%s', err.message);
        if config.analysis.failOnPointAnalysisError
            rethrow(err);
        end
    end
end

%% 保存成像图
imageFile = bp_save_image_output(imageBP, config, runOutput.runDir);

%% 打包结果
result = struct();
result.image = imageBP;
result.outputFile = imageFile;
result.config = config;
result.interruptionInfo = cutInfo;
result.interruptionFiles = interruptionFiles;
result.meta = imageMeta;
result.meta.dataRoot = dataRoot;
result.meta.runOutput = runOutput;
result.pointAnalysis = pointResult;
result.pointAnalysisMeta = pointMeta;
result.pointAnalysisFiles = pointFiles;
if strcmp(cutInfo.mode, 'random_gap')
    fprintf('random seed used: %.0f\n', cutInfo.randomSeedUsed);
end

fprintf('成像完成，运行输出目录：%s\n', runOutput.runDir);
fprintf('成像图文件：%s\n', imageFile);
end
