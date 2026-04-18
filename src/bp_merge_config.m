function cfg = bp_merge_config(cfg, userCfg)
%BP_MERGE_CONFIG 按默认配置 schema 严格递归合并用户配置。
cfg = localMergeStruct(cfg, userCfg, 'cfg');
end

function cfg = localMergeStruct(cfg, userCfg, currentPath)
if ~isstruct(userCfg)
    error('bp_merge_config:InvalidUserConfig', ...
        '%s 的用户覆盖必须是结构体，当前类型为 %s。', ...
        currentPath, class(userCfg));
end

userFields = fieldnames(userCfg);
for idx = 1:numel(userFields)
    key = userFields{idx};
    fieldPath = sprintf('%s.%s', currentPath, key);

    if ~isfield(cfg, key)
        error('bp_merge_config:UnknownField', ...
            '未知配置字段：%s。请检查字段名或层级是否正确。', fieldPath);
    end

    userValue = userCfg.(key);
    defaultValue = cfg.(key);

    if isstruct(defaultValue) && isstruct(userValue)
        cfg.(key) = localMergeStruct(defaultValue, userValue, fieldPath);
    elseif isstruct(defaultValue) ~= isstruct(userValue)
        error('bp_merge_config:TypeMismatch', ...
            '配置字段 %s 的层级类型不匹配：默认值为 %s，用户覆盖为 %s。', ...
            fieldPath, localDescribeValueType(defaultValue), localDescribeValueType(userValue));
    else
        cfg.(key) = userValue;
    end
end
end

function typeText = localDescribeValueType(value)
if isstruct(value)
    typeText = 'struct';
elseif isstring(value)
    typeText = 'string';
elseif ischar(value)
    typeText = 'char';
elseif isempty(value)
    typeText = 'empty';
elseif islogical(value)
    typeText = 'logical';
elseif isnumeric(value)
    typeText = class(value);
else
    typeText = class(value);
end
end
