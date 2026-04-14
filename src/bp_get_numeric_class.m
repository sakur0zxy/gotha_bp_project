function numericClass = bp_get_numeric_class(useSinglePrecision)
%BP_GET_NUMERIC_CLASS 根据开关选择数值精度类型

if useSinglePrecision
    numericClass = 'single';
else
    numericClass = 'double';
end
end
