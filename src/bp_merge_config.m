function cfg = bp_merge_config(cfg, userCfg)
%BP_MERGE_CONFIG 递归合并默认配置和用户配置。
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
