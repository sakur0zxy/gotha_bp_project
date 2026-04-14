
% 需要 MupsampleS.m, PSLR.m, IRW.m, ISLR.m

%%
S_rac = imgBP;
Br = Br;
Fr = Fr;
Fa = PRF;
Vr = vc;
f_dop = 2*Vr*sin(squintAngle)/lambda;

%% ----------------------------------------------- 对目标升采样分析 ---------------------------------------------------
% 提取以峰值点为中心 [Row, Col] 维度的切片
Row = 32;
Col = 32;
Nus = 16;                                                           % 升采样系数

% 峰值点中心
[CentY, CentX] = find(abs(S_rac)==max(max(abs(S_rac))));                                        % 目标坐标

Slice = S_rac(CentY-Col/2: CentY+Col/2-1, CentX-Row/2: CentX+Row/2-1);            % 切片

figure
imagesc(abs(Slice));
colormap jet
xlabel('距离向（采样点）');   ylabel('方位向（采样点）');
title('目标区域切片');

% Nus 倍升采样分析
% 对截取自目标周围的小切片进行频谱补零扩充，P38、P47

upSlice = MupsampleS(Slice, Nus);                   % 图像升采样函数

figure
imagesc(abs(upSlice));
colormap jet
xlabel('距离向（采样点）');  ylabel('方位向（采样点）');
title('升采样结果');

figure
contour(abs(upSlice));
colormap jet
xlabel('距离向（采样点）');  ylabel('方位向（采样点）');
title('目标轮廓图');

% 对点目标中心做距离向切片和方位向切片
[Rmaxloc, Amaxloc] = find(abs(upSlice)==max(max(abs(upSlice))));                        % 峰值坐标
Rslice = upSlice(Rmaxloc, :);                              % 距离向切片
Rslice = Rslice/max(Rslice);                               % 归一化            

figure
plot(20*log10(abs(Rslice)), 'b');  hold on;
[Rpks, Rlocs] = findpeaks(20*log10(abs(Rslice)));                                                      % 使用 findpeaks 函数提取峰值
plot(Rlocs, Rpks, 'r*');
axis tight
xlabel('距离向（采样点）');  ylabel('幅度（dB）');
title('距离剖面图');

Aslice = upSlice(:, Amaxloc);                             % 方位向切片
Aslice = Aslice/max(Aslice);

figure
plot(20*log10(abs(Aslice)), 'b');  hold on;
[Apks, Alocs] = findpeaks(20*log10(abs(Aslice)));
plot(Alocs, Apks, 'r*');
axis tight
xlabel('方位向（采样点）');  ylabel('幅度（dB）');
title('方位剖面图');


%% -------------------------------------------------- 指标计算 ----------------------------------------------------------
% 峰值旁瓣比（PSLR）
% 调用自定义函数 PSRL

RPSLR = PSRL(Rslice);                                       % 距离向一维峰值旁瓣比 
APSLR = PSRL(Aslice);                                       % 方位向一维峰值旁瓣比 

disp('------------------------------------------------------------')
fprintf('距离向 PSLR：%f dB \n', RPSLR);
fprintf('方位向 PSLR：%f dB \n', APSLR);

% 一维积分旁瓣比（ISLR）
% 调用自定义函数 ISRL
RISLR = ISRL(Rslice);                                          % 距离向一维积分旁瓣比             
AISLR = ISRL(Aslice);                                          % 方位向一维积分旁瓣比  

disp('------------------------------------------------------------')
fprintf('距离向 ISLR：%f dB \n', RISLR);
fprintf('方位向 ISLR：%f dB \n', AISLR);

% 冲击响应宽度（IRW）
% 调用自定义函数 IRW
Runit = c/(2*Fr);                                                 % 斜距输出的采样间隔，m

RIRW = IRW(Rslice, Nus, Runit);                        % 距离向冲击响应宽度，单位 m
AIRW= IRW(Aslice, Nus, Vr/Fa);                        % 方位向冲击响应宽度，单位 m

RIRW_i = 0.886*c/(2*Br);                                   % 距离分辨率理论值，单位 m
AIRW_i = 0.886*(Vr/f_dop);                               % 方位分辨率理论值，单位 m

disp('------------------------------------------------------------')
fprintf('距离向 IRW：%f m        理论值：%f m \n', RIRW, RIRW_i);
fprintf('方位向 IRW：%f m        理论值：%f m \n', AIRW, AIRW_i);


%%%%%% END %%%%%%
