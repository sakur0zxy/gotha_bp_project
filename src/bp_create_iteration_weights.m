function iterWeights = bp_create_iteration_weights(J, numericClass)
%BP_CREATE_ITERATION_WEIGHTS 生成三阶历史图像迭代权重
% 说明：该权重公式沿用原始脚本，不改变算法行为。

lam = 1 - 2.8 / J;
mi = pi / (2 * J / 3);
ga = 1 - 3 / J;

iterWeights = zeros(1, 3);
iterWeights(1) = -(-lam * exp(-1i * mi) - lam * exp(1i * mi) - ga);
iterWeights(2) = -(lam^2 + lam * ga * exp(-1i * mi) + lam * ga * exp(1i * mi));
iterWeights(3) = (lam^2) * ga;

iterWeights = cast(iterWeights, numericClass);
end
