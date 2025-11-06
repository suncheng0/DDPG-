% 奖励函数对中间动作激励的正确验证脚本（修复cell类型动作索引问题）
clear; clc;

%% 1. 加载智能体
load('trained_agent_sac.mat', 'agent');  % 加载训练好的智能体

%% 2. 定义测试状态
test_states = {
    % 场景描述, Vout, I1_dc, I2_dc, phase_diff
    {'理想状态', 12.0, 83.3, 83.3, -180}
    {'电压小偏差(+0.2V)', 12.2, 83.3, 83.3, -180}
    {'电压大偏差(+2V)', 14.0, 83.3, 83.3, -180}
    {'电流小失衡(+3A)', 12.0, 86.3, 80.3, -180}
    {'电流大失衡(+10A)', 12.0, 93.3, 73.3, -180}
    {'危险工况(过压+过流)', 14.6, 101.0, 83.3, -180}
};

%% 3. 状态→动作→奖励验证
fprintf('=== 状态→动作→奖励 验证 ===\n');
fprintf('场景\t\t\tKp\tKi\tKd\t奖励\t动作区间\n');
fprintf('--------------------------------------------------------------------------------\n');

for i = 1:length(test_states)
    state_desc = test_states{i}{1};
    Vout = test_states{i}{2};
    I1_dc = test_states{i}{3};
    I2_dc = test_states{i}{4};
    phase_diff = test_states{i}{5};
    
    % 构造观测向量（列向量，与obsInfo维度一致）
    observation = [Vout; 0; 0; I1_dc; I2_dc; phase_diff];  
    
    % 获取动作（返回1×1 cell，内部为3×1 double）
    [action_cell, ~] = getAction(agent, observation);  
    action = cell2mat(action_cell);  % cell转数值向量（3×1 double）
    
    % 提取Kp、Ki、Kd
    Kp = action(1);
    Ki = action(2);  % 现在可正常索引第2个元素
    Kd = action(3);
    
    % 计算奖励
    reward = optimizedSACRewardImproved(Vout, 0, 0, I1_dc, I2_dc, phase_diff);
    
    % 判断动作区间
    Kp_mid = (150 < Kp && Kp < 5000-100);
    Ki_mid = (100 < Ki && Ki < 1000-100);
    Kd_mid = (0.04 < Kd && Kd < 0.08-0.005);
    if Kp_mid && Ki_mid && Kd_mid
        action_range ='中间';
    else
        action_range ='边界';
    end
    
    % 打印结果
    fprintf('%20s\t%.0f\t%.0f\t%.2f\t%.3f\t%s\n', ...
        state_desc, Kp, Ki, Kd, reward, action_range);
end

%% 奖励函数（与原函数一致，确保无三目运算符）
function reward = optimizedSACRewardImproved(Vout, I1_inst, I2_inst, I1_dc, I2_dc, phase_diff)
    V_ref = 12;         
    I_dc_target = 83.3; 
    phase_target = -180;

    %% 1. 安全约束惩罚
    safety_penalty = 0;
    if Vout > 14.5 || Vout < 9.5  
        safety_penalty = -2.0;  
    elseif Vout > 13.5 || Vout < 10.5  
        safety_penalty = -1.0;  
    end
    if I1_dc > 100 || I2_dc > 100  
        safety_penalty = safety_penalty - 1.5; 
    elseif I1_dc > 90 || I2_dc > 90  
        safety_penalty = safety_penalty - 0.8; 
    end

    %% 2. 状态误差惩罚
    volt_error = abs(Vout - V_ref);
    if volt_error < 0.5
        R_volt = -0.2 * (1 - exp(-2 * volt_error));
    else
        R_volt = -0.2 * volt_error;
    end

    curr_error = (abs(I1_dc - I_dc_target) + abs(I2_dc - I_dc_target))/2;
    if curr_error < 5
        R_curr = -0.1 * (1 - exp(-curr_error/2));
    else
        R_curr = -0.1 * curr_error/5;
    end

    balance_error = abs(I1_dc - I2_dc);
    if balance_error < 3
        R_balance = -0.05 * (1 - exp(-balance_error));
    else
        R_balance = -0.05 * balance_error/3;
    end

    phase_error = abs(phase_diff - phase_target);
    if phase_error < 10
        R_phase = -0.03 * (1 - exp(-phase_error/5));
    else
        R_phase = -0.03 * phase_error/10;
    end

    %% 3. 性能奖励
    perf_volt = exp(-2 * volt_error) * 2.5;     
    perf_curr = exp(-curr_error/2) * 1.8;      
    perf_balance = exp(-balance_error) * 1.2;  
    perf_phase = exp(-phase_error/5) * 0.6;    
    performance = perf_volt + perf_curr + perf_balance + perf_phase;

    %% 4. 总奖励
    reward = safety_penalty + R_volt + R_curr + R_balance + R_phase + performance;
    reward = max(min(reward, 10), -10);
end