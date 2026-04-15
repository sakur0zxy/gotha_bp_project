function result = main_gotha_bp(userConfig)
%MAIN_GOTHA_BP 运行 GOTCHA BP 成像主流程。
% 输入：
%   userConfig  可选，用于覆盖默认配置的结构体。
% 输出：
%   result      包含成像结果、间断信息、点目标分析结果和输出路径。

%% 加载项目路径
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));

%% 读取并校验配置
config = default_config();
if nargin >= 1 && ~isempty(userConfig)
    config = bp_merge_config(config, userConfig);
end
config = bp_validate_config(config);

%% 读取路径和数据
[pathInfo, track, echoData, radar, dataRoot] = bp_data_pipeline(config);

%% 生成间断采样回波
[echoCut, cutInfo] = bp_interruption_pipeline(echoData, track, config.interruption);
runOutput = bp_output_pipeline('prepare_run_dir', config, pathInfo, cutInfo);
interruptionFiles = bp_output_pipeline('save_interruption', cutInfo, config, runOutput.runDir);

if config.display.showInterruptedEcho
    figure('Name', 'Interrupted Echo', 'Color', 'w');
    imagesc(abs(echoCut));
    title('间断采样后的回波矩阵');
    xlabel('方位向采样点');
    ylabel('距离向采样点');
    colormap jet;
end

%% 执行 BP 成像
[imageBP, imageMeta] = bp_imaging_pipeline(track, echoCut, radar, config, cutInfo);

%% 点目标分析
pointResult = [];
pointMeta = struct('enabled', false);
pointFiles = localEmptyPointFiles();

if config.analysis.enablePointAnalysis
    try
        [pointResult, pointMeta] = bp_run_point_analysis(imageBP, config, radar, track, pathInfo);
        pointFiles = bp_output_pipeline('save_point_analysis', pointResult, pointMeta, config, runOutput.runDir);
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
imageFile = bp_output_pipeline('save_image', imageBP, config, runOutput.runDir);

%% 汇总结果
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
    fprintf('Random seed used: %.0f\n', cutInfo.randomSeedUsed);
end
fprintf('运行输出目录：%s\n', runOutput.runDir);
fprintf('成像图文件：%s\n', imageFile);
end

function pointFiles = localEmptyPointFiles()
pointFiles = struct( ...
    'matFile', '', ...
    'textFile', '', ...
    'imageFile', '', ...
    'imageFiles', struct( ...
        'upslice', '', ...
        'contour', '', ...
        'rangeProfile', '', ...
        'azimuthProfile', ''));
end
