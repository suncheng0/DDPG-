% 奖励函数验证脚本
% 系统测试不同工况下的奖励输出，验证函数设计是否符合预期

%% 测试场景定义
test_cases = {
    % 场景描述, Vout, I1_inst, I2_inst, I1_dc, I2_dc, phase_diff
    {'理想状态', 12.00, 0, 0, 83.3, 83.3, -180}
    {'轻微电压偏高', 12.10, 0, 0, 83.3, 83.3, -180}
    {'轻微电压偏低', 11.95, 0, 0, 83.3, 83.3, -180}
    {'显著电压偏差', 7.50, 0, 0, 83.3, 83.3, -180}
    {'电流轻微不平衡', 12.00, 0, 0, 85.0, 81.5, -180}
    {'电流显著不平衡', 12.00, 0, 0, 90.0, 66.0, -180}
    {'相位轻微偏差', 12.00, 0, 0, 83.3, 83.3, -175}
    {'相位显著偏差', 12.00, 0, 0, 83.3, 83.3, -140}
    {'单相电流偏高', 12.00, 0, 0, 95.0, 83.3, -180}
    {'单相电流偏低', 12.00, 0, 0, 70.0, 83.3, -180}
    {'过压临界(13.2V)', 13.20, 0, 0, 83.3, 83.3, -180}
    {'过压危险(14.0V)', 14.00, 0, 0, 83.3, 83.3, -180}
    {'欠压临界(5.1V)', 5.10, 0, 0, 83.3, 83.3, -180}
    {'过流临界(99.9A)', 12.00, 0, 0, 99.9, 99.9, -180}
    {'综合问题(电压+电流)', 11.80, 0, 0, 90.0, 75.0, -170}
    {'极端恶劣情况', 10.50, 0, 0, 95.0, 70.0, -150}
};

%% 执行测试并收集结果
results = cell(length(test_cases), 4); % 存储测试结果

fprintf('=== 奖励函数验证测试 ===\n');
fprintf('%-30s | %8s | %8s\n', '测试场景', '奖励值', '状态');
fprintf('------------------------------------------------\n');

for i = 1:length(test_cases)
    % 提取测试参数
    case_desc = test_cases{i}{1};
    params = test_cases{i}(2:end);
    
    % 计算奖励
    reward = improvedRewardFunction(params{:});
    
    % 判断状态
    if reward > 50
        status = '优秀';
    elseif reward > 0
        status = '良好';
    elseif reward > -50
        status = '警告';
    else
        status = '危险';
    end
    
    % 存储结果
    results{i, 1} = case_desc;
    results{i, 2} = params;
    results{i, 3} = reward;
    results{i, 4} = status;
    
    % 实时输出
    fprintf('%-30s | %8.1f | %8s\n', case_desc, reward, status);
end

%% 结果可视化分析
% 创建奖励值柱状图
figure('Position', [100, 100, 900, 400]);  % 调整窗口大小，适配单个柱状图
bar([results{:,3}], 'FaceColor', [0.6 0.8 1]);  % 绘制奖励值柱状图，设置柱面颜色
title('各场景奖励值分布');  % 图表标题
xlabel('测试场景');         % x轴标签（测试场景）
ylabel('奖励值');           % y轴标签（奖励值）
grid on;  % 显示网格线，方便读数

% 添加场景标签（避免标签重叠，设置旋转角度）
xticks(1:length(test_cases));            % 为每个场景设置刻度
xticklabels({results{:,1}});             % 刻度标签为场景描述
xtickangle(45);                          % 标签旋转45度

%% 详细报告输出
fprintf('\n=== 详细测试报告 ===\n');
for i = 1:length(results)
    fprintf('\n场景 %d: %s\n', i, results{i,1});
    fprintf('参数: Vout=%.2fV, I1_dc=%.1fA, I2_dc=%.1fA, Phase=%.0f°\n', ...
            results{i,2}{1}, results{i,2}{4}, results{i,2}{5}, results{i,2}{6});
    fprintf('奖励值: %.1f (%s)\n', results{i,3}, results{i,4});
    
    % 提供设计建议
    if results{i,3} < -100
        fprintf('建议: 检查安全阈值设置，可能需要调整惩罚权重\n');
    elseif results{i,3} < 0 && i < 5 % 前几个基本场景
        fprintf('建议: 基础电压控制奖励可能需要增强\n');
    end
end

%% 边界条件测试（额外验证）
fprintf('\n=== 边界条件测试 ===\n');
edge_cases = {
    {'电压精确控制(12.00V)', 12.00, 0, 0, 83.3, 83.3, -180}
    {'电压临界高(12.05V)', 12.05, 0, 0, 83.3, 83.3, -180}
    {'电压临界低(11.95V)', 11.95, 0, 0, 83.3, 83.3, -180}
    {'电流临界高(83.4A)', 12.00, 0, 0, 83.4, 83.3, -180}
    {'电流临界低(83.2A)', 12.00, 0, 0, 83.2, 83.3, -180}
};

for i = 1:length(edge_cases)
    case_desc = edge_cases{i}{1};
    params = edge_cases{i}(2:end);
    reward = improvedRewardFunction(params{:});
    fprintf('%-25s: 奖励=%.1f\n', case_desc, reward);
end

%% 奖励函数定义（确保使用最新版本）
function reward = improvedRewardFunction(Vout, I1_inst, I2_inst, I1_dc, I2_dc, phase_diff)
    % 目标参数
    V_ref = 12;               % 目标电压
    I_dc_target = 83.3;       % 目标电流
    phase_target = -180;      % 目标相位
    
    % 安全约束（优先判断）
    if Vout > 15 || Vout < 5  
        reward = -1500; return; % 直接返回大惩罚
    end
    if I1_dc > 100 || I2_dc > 100  % 1.2 * 83.3≈100
        reward = -1000; return;
    end
    
    % ---- 核心修改：简化奖励结构，移除归一化 ----
    % 电压奖励（连续奖励）
    volt_error = abs(Vout - V_ref);
    R_volt = -10 * volt_error;  % 线性惩罚
    
    % 电流跟踪奖励
    curr_error = (abs(I1_dc - I_dc_target) + abs(I2_dc - I_dc_target))/2;
    R_curr = -5 * curr_error;
    
    % 均流奖励（两相电流差异）
    balance_error = abs(I1_dc - I2_dc);
    R_balance = -3 * balance_error;
    
    % 相位奖励
    phase_error = abs(phase_diff - phase_target);
    R_phase = -2 * phase_error;
    
    % ---- 目标区域奖励（阶梯式）----
    if volt_error < 0.05
        R_target_volt = 100;
    elseif volt_error < 0.1
        R_target_volt = 50;
    elseif volt_error < 0.5
        R_target_volt = 20;
    else
        R_target_volt = 0;
    end
    
    % 总奖励（不再归一化！）
    reward = R_volt + R_curr + R_balance + R_phase + R_target_volt;
    
    % 限制合理范围即可
    reward = max(min(reward, 200), -200);
end