function cfg = cs_default_config()
%CS_DEFAULT_CONFIG 压缩感知回波恢复模块的默认配置。
% cfg.project 管主流程。
% cfg.method / recovery / compare / data / output 管恢复流程。

cfg = struct();

% 复用主流程 schema，保证 csCfg.project 和主流程同样严格。
cfg.project = default_config();

cfg.method = struct( ...
    'run1D', true, ... % true: 运行逐距离单元的 1D 方位向恢复。
    'run2D', true); % true: 运行整幅回波的 2D 恢复。

% compare 控制恢复后是否继续做成像和点目标分析。
cfg.compare = struct( ...
    'runImaging', true, ... % true: 对 original / interrupted / recovered_* 全部重新成像。
    'runPointAnalysis', true, ... % true: 成像后继续做主瓣宽度、旁瓣等点目标分析。
    'failOnPointAnalysisError', false); % true: 任一点目标分析失败就停止；false: 记录错误后继续。

% recovery 是恢复算法自己的迭代和正则化参数。
cfg.recovery = struct( ...
    'maxIter', 200, ... % 最大迭代次数；越大越可能收敛，但运行更慢。
    'tol', 1e-4, ... % 相邻两次解的相对变化阈值，低于它就认为收敛。
    'lambda1D', 0.01, ... % 1D 方位向 FFT 稀疏正则强度；越大越偏向平滑/稀疏。
    'lambda2D', 0.005, ... % 2D FFT 稀疏正则强度；作用与 lambda1D 类似，但针对整幅回波。
    'useFista', true, ... % true: 使用 FISTA 加速；false: 退化为普通 ISTA。
    'normalizeInput', true, ... % true: 先按最大幅值归一化，通常能让不同数据规模下更稳。
    'verbose', true); % 是否打印迭代进度。

% 留空时使用完整数据；调试时可裁剪索引范围。
cfg.data = struct( ...
    'rangeIndexRange', [], ... % 距离向索引范围；[] 表示全部，支持 [start end] 或显式索引列表。
    'azimuthIndexRange', []); % 方位向索引范围；[] 表示全部，支持 [start end] 或显式索引列表。

% 这里只控制恢复流程产物是否写入 cs_echo_recovery/results/。
cfg.output = struct( ...
    'enableOutput', true, ... % 恢复流程输出总开关；false 时只返回 result，不写文件。
    'resultsDirName', 'results', ... % 恢复流程结果根目录名，相对 cs_echo_recovery/。
    'runFolderPrefix', 'run', ... % 每次运行目录前缀。
    'timestampFormat', 'yyyyMMdd_HHmmss'); % 运行目录时间戳格式。
end
