function outputFile = bp_save_image_output(imgBp, cfg, outputDir)
%BP_SAVE_IMAGE_OUTPUT 保存成像结果到 jpg 文件
% 说明：
% 1) 输出目录由主流程传入（可为每次运行的独立目录）；
% 2) 输出文件名包含间断模式、分段数与缺失率，便于对比实验结果。

if exist(outputDir, 'dir') ~= 7
    mkdir(outputDir);
end

baseName = sprintf('%s_%s_%d_%g', ...
    cfg.output.filePrefix, ...
    cfg.interruption.mode, ...
    cfg.interruption.numSegments, ...
    cfg.interruption.missingRatio);

if cfg.output.appendTimestamp
    timeStamp = datetime('now', 'Format', cfg.output.timestampFormat);
    fileName = sprintf('%s_%s.jpg', baseName, char(timeStamp));
else
    fileName = sprintf('%s.jpg', baseName);
end

outputFile = fullfile(outputDir, fileName);

outputImage = abs(imgBp);
outputScale = mean(outputImage(:));
if outputScale > 0
    outputImage = outputImage / (outputScale * cfg.display.outputScale);
end

imwrite(outputImage, outputFile, 'jpg');
end
