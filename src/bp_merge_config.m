function cfg = bp_merge_config(cfg, userCfg)
%BP_MERGE_CONFIG 递归合并配置结构体
% 规则：
% 1) userCfg 中存在的字段覆盖默认 cfg；
% 2) 若字段是结构体，则递归合并；
% 3) 若字段不存在于默认 cfg，也允许新增。

if ~isstruct(userCfg)
    error('userCfg 必须是结构体。');
end

userFields = fieldnames(userCfg);
for idx = 1:numel(userFields)
    key = userFields{idx};
    userValue = userCfg.(key);

    if isfield(cfg, key) && isstruct(cfg.(key)) && isstruct(userValue)
        cfg.(key) = bp_merge_config(cfg.(key), userValue);
    else
        cfg.(key) = userValue;
    end
end
end
