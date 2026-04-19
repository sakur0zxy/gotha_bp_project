function tests = test_data_pipeline_contract()
%TEST_DATA_PIPELINE_CONTRACT 验证通用数据契约加载逻辑。
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
testCase.TestData.projectRoot = projectRoot;
end

function testCustomDatasetContractLoads(testCase)
tempDir = localCreateTempDir();
cleanupObj = onCleanup(@() localRemoveTempDir(tempDir)); %#ok<NASGU>

freqHz = [9.6e9, 9.61e9, 9.62e9, 9.63e9];
for fileIdx = 1:2
    sampleBlock = struct();
    sampleBlock.platform_x = (fileIdx - 1) * 3 + [1, 2, 3];
    sampleBlock.platform_y = (fileIdx - 1) * 3 + [11, 12, 13];
    sampleBlock.platform_z = (fileIdx - 1) * 3 + [21, 22, 23];
    sampleBlock.echo_matrix = reshape(fileIdx + (1:12), 4, 3);
    sampleBlock.freq_hz = freqHz;
    save(fullfile(tempDir, sprintf('sample_%02d.mat', fileIdx)), 'sampleBlock');
end

cfg = default_config();
cfg.general.numDataFiles = 2;
cfg.general.dataFilePattern = 'sample_%02d.mat';
cfg.general.dataVariableName = 'sampleBlock';
cfg.general.dataFieldMap = struct( ...
    'x', 'platform_x', ...
    'y', 'platform_y', ...
    'z', 'platform_z', ...
    'echo', 'echo_matrix', ...
    'freq', 'freq_hz');
cfg.path.dataRoot = tempDir;

cfg = bp_validate_config(cfg);
[~, track, echoData, radar, dataRoot] = bp_data_pipeline(cfg);

verifyEqual(testCase, dataRoot, tempDir);
verifyEqual(testCase, numel(track.X), 6);
verifyEqual(testCase, numel(track.Y), 6);
verifyEqual(testCase, numel(track.Z), 6);
verifySize(testCase, echoData, [4, 6]);
verifyEqual(testCase, radar.freqVectorHz, freqHz, 'AbsTol', 1e-12);
end

function testMissingMappedFieldFailsClearly(testCase)
tempDir = localCreateTempDir();
cleanupObj = onCleanup(@() localRemoveTempDir(tempDir)); %#ok<NASGU>

sampleBlock = struct();
sampleBlock.platform_x = [1, 2, 3];
sampleBlock.platform_y = [4, 5, 6];
sampleBlock.platform_z = [7, 8, 9];
sampleBlock.freq_hz = [9.6e9, 9.61e9, 9.62e9, 9.63e9];
save(fullfile(tempDir, 'sample_01.mat'), 'sampleBlock');

cfg = default_config();
cfg.general.numDataFiles = 1;
cfg.general.dataFilePattern = 'sample_%02d.mat';
cfg.general.dataVariableName = 'sampleBlock';
cfg.general.dataFieldMap = struct( ...
    'x', 'platform_x', ...
    'y', 'platform_y', ...
    'z', 'platform_z', ...
    'echo', 'echo_matrix', ...
    'freq', 'freq_hz');
cfg.path.dataRoot = tempDir;

cfg = bp_validate_config(cfg);

try
    bp_data_pipeline(cfg);
    verifyFail(testCase, 'bp_data_pipeline 应该因为缺少映射字段而失败。');
catch ME
    verifyEqual(testCase, ME.identifier, 'bp_data_pipeline:MissingDatasetFields');
    verifyTrue(testCase, contains(ME.message, 'echo->echo_matrix'));
    verifyTrue(testCase, contains(ME.message, 'cfg.general.dataFieldMap'));
end
end

function tempDir = localCreateTempDir()
tempDir = tempname();
mkdir(tempDir);
end

function localRemoveTempDir(tempDir)
if exist(tempDir, 'dir') == 7
    rmdir(tempDir, 's');
end
end
