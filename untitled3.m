%% 交错Buck电路参数计算与Simulink模型参数同步
% 功能：根据额定功率计算元件参数，并通过Model Workspace同步到Simulink模型

%% 1. 固定电路与设计参数
Vin = 48;          % 输入电压 (V)
Vout = 12;         % 输出电压 (V)
fsw = 500e3;       % 开关频率 (Hz)
D = Vout / Vin;    % 占空比
R_phase = 3e-3;    % 每相电感串联电阻（与示例一致，3mΩ）

% 纹波与设计约束
K_ripple = 0.2;    % 每相电流纹波率
DeltaVout = 50e-3; % 目标输出电压纹波 (V)
ESR_initial = 10e-3; % 电容初始ESR (Ω)

%% 2. 用户输入额定功率
P = input('请输入额定功率（单位：W）：');

%% 3. 基础参数计算
Iout = P / Vout;               % 总额定输出电流 (A)
Iout_phase = Iout / 2;         % 每相平均电流 (A)
R1 = Vout^2 / P;               % 负载电阻R1 (Ω)

%% 4. 每相电感参数计算（H2、H3）
DeltaIL = K_ripple * Iout_phase;  % 每相电流纹波 (A)
L_phase = 2 * (Vin - Vout) * D / (fsw * K_ripple * Iout);  % 每相电感 (H)
H2 = L_phase;  % 一号支路电感
H3 = L_phase;  % 二号支路电感
R2 = R_phase;  % 一号支路电阻
R3 = R_phase;  % 二号支路电阻

%% 5. 总输出电容参数计算（C1）
DeltaIc = DeltaIL / 2;            % 电容纹波电流 (A)
DeltaV_ESR = DeltaIc * ESR_initial; % ESR引起的纹波 (V)

% 处理ESR纹波超限，自动调整ESR
if DeltaV_ESR >= DeltaVout
    max_ESR_ripple = 0.6 * DeltaVout;  % ESR纹波上限
    ESR = max_ESR_ripple / DeltaIc;    
    DeltaV_ESR = max_ESR_ripple;       
    warning('为避免ESR纹波超限，已自动调整ESR至合理值');
else
    ESR = ESR_initial;
end

DeltaV_C = DeltaVout - DeltaV_ESR; % 电容充放电纹波 (V)
C1 = DeltaIc / (8 * fsw * DeltaV_C);  % 总输出电容 (F)

%% 6. 同步参数到Simulink模型（Model Workspace）
model_name = 'answer';  % Simulink模型名称（无.slx后缀）
model_path = 'D:\tai_da\922\chengpin23\answer.slx';  % 模型完整路径

% 加载模型（若未加载）
if ~bdIsLoaded(model_name)
    load_system(model_path);
end


% 获取Model Workspace并赋值参数
mdlwks = get_param(model_name, 'ModelWorkspace');
mdlwks.assignin('R1', R1);
mdlwks.assignin('C1', C1);
mdlwks.assignin('H2', H2);
mdlwks.assignin('R2', R2);
mdlwks.assignin('H3', H3);
mdlwks.assignin('R3', R3);
mdlwks.assignin('I', Iout/2);


%% 7. 输出结果
disp('\n===== 计算与同步结果 =====');
disp(['额定功率：', num2str(P), ' W']);
disp(['负载电阻 R1：', num2str(R1, '%.6f'), ' Ω']);
disp(['总输出电容 C1：', num2str(C1*1e6, '%.2f'), ' μF']);
disp(['每相电感 H2/H3：', num2str(L_phase*1e6, '%.2f'), ' μH']);
disp(['每相电阻 R2/R3：', num2str(R_phase*1e3, '%.2f'), ' mΩ']);
disp(['额定输出电流：', num2str(Iout, '%.2f'), ' A']);
disp(['输出电压纹波（总）：', num2str(DeltaVout*1e3, '%.2f'), ' mV']);
disp(['  - 电容充放电纹波：', num2str(DeltaV_C*1e3, '%.2f'), ' mV']);
disp(['  - ESR引起的纹波：', num2str(DeltaV_ESR*1e3, '%.2f'), ' mV']);
disp('提示：Simulink模型中元件需通过“Model Workspace”变量（R1、C1、H2、R2、H3、R3）引用参数，已自动同步。');

%% 8. 可选：打开模型查看效果
% open_system(model_path);