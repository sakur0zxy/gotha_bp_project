function seed = bp_resolve_random_seed(seedIn)
%BP_RESOLVE_RANDOM_SEED 返回可复现的整数随机种子

if ~isempty(seedIn)
    seed = double(seedIn);
    return;
end

timeNow = posixtime(datetime('now'));
seed = mod(floor(timeNow * 1e6), 2^31 - 1);

if ~isfinite(seed) || seed <= 0
    seed = 1;
end
end
