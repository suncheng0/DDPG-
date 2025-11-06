% 多相BUCK电路强化学习PID参数自整定训练代码
% 修复电压稳定在0V的问题

% 环境参数设置
Ts = 0.0005;   % 采样时间 (50us)
Tf = 0.01;      % 总仿真时间 - 延长以观察完整动态过程

% 全局变量定义
global agent best_agent best_reward bestEpisodeNumber;
best_reward = -inf;
best_agent = [];
bestEpisodeNumber = 0;
saveCounter = 0;

% 检查GPU可用性并设置
if gpuDeviceCount > 0
    disp('GPU detected. Enabling GPU acceleration...');
    useGPU = false;
    % 设置并行计算环境
    if isempty(gcp('nocreate'))
        parpool('local');
    end
else
    disp('No GPU detected. Using CPU only.');
    useGPU = false;
end

% Simulink模型环境设置
mdl = 'answer';
open_system(mdl);

% 创建状态规范（观测空间：电压，电流1，电流2）
obsInfo = rlNumericSpec([6 1]); % 对应 [Vout; I_phase1; I_phase2]

% 创建动作规范（电压环PID的P、I，电流环P）
actionInfo = rlNumericSpec([3 1], 'LowerLimit', [1;1; 0.001], 'UpperLimit', [5000; 1000; 0.08]);

% agent在Simulink的位置
agent_blk = [mdl '/RL Agent'];

% 创建Env
env = rlSimulinkEnv(mdl, agent_blk, obsInfo, actionInfo);

% 环境初始化函数 - 添加随机化
env.ResetFcn = @(in)localResetFcn(in, mdl);    

% 固定随机种子以确保结果可重现
rng(0);

% 创建智能体

% Critic网络创建（输入为3维观测+3维动作）- 加深版本.
statePath = [
    featureInputLayer(6, 'Normalization', 'none', 'Name', 'State')
    fullyConnectedLayer(256, 'Name', 'CriticStateFC1') 
    reluLayer('Name', 'CriticRelu1')
    fullyConnectedLayer(128, 'Name', 'CriticStateFC2') 
    reluLayer('Name', 'CriticRelu2')
    fullyConnectedLayer(64, 'Name', 'CriticStateFC3') 
    reluLayer('Name', 'CriticRelu3')
    fullyConnectedLayer(32, 'Name', 'CriticStateFC4')
];

actionPath = [
    featureInputLayer(3, 'Normalization', 'none', 'Name', 'Action')
    fullyConnectedLayer(128, 'Name', 'CriticActionFC1')
    reluLayer('Name', 'CriticActionRelu1')
    fullyConnectedLayer(64, 'Name', 'CriticActionFC2')
    reluLayer('Name', 'CriticActionRelu2')
    fullyConnectedLayer(32, 'Name', 'CriticActionFC3')
];

commonPath = [
    concatenationLayer(1, 2, 'Name', 'concat')
    reluLayer('Name', 'CriticCommonRelu1')
    fullyConnectedLayer(64, 'Name', 'CriticCommonFC1')
    reluLayer('Name', 'CriticCommonRelu2')
    fullyConnectedLayer(32, 'Name', 'CriticCommonFC2')
    reluLayer('Name', 'CriticCommonRelu3')
    fullyConnectedLayer(16, 'Name', 'CriticCommonFC3')
    reluLayer('Name', 'CriticCommonRelu4')
    fullyConnectedLayer(1, 'Name', 'CriticOutput')
];

criticNetwork = layerGraph();
criticNetwork = addLayers(criticNetwork, statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'CriticStateFC4', 'concat/in1');
criticNetwork = connectLayers(criticNetwork, 'CriticActionFC3', 'concat/in2');

% Critic的优化选项 - 启用GPU加速
criticOpts = rlRepresentationOptions('LearnRate', 1e-4, 'GradientThreshold', 1);
if useGPU
    criticOpts.UseDevice = 'gpu';
    disp('Critic network will use GPU acceleration.');
end

% 拟合Critic
critic = rlQValueRepresentation(criticNetwork, obsInfo, actionInfo,...
    'Observation', {'State'}, 'Action', {'Action'}, criticOpts);

% 创建Actor网络（输入为3维观测，输出为3维动作）
actorNetwork = [
    featureInputLayer(6, 'Normalization', 'none', 'Name', 'State')
    fullyConnectedLayer(256, 'Name', 'actorFC1')
    reluLayer('Name', 'actorRelu1')
    fullyConnectedLayer(128, 'Name', 'actorFC2')
    reluLayer('Name', 'actorRelu2')
    fullyConnectedLayer(64, 'Name', 'actorFC3')
    reluLayer('Name', 'actorRelu3')
    fullyConnectedLayer(32, 'Name', 'actorFC4')
    reluLayer('Name', 'actorRelu4')
    fullyConnectedLayer(3, 'Name', 'Action')
];

% Actor的优化选项 - 启用GPU加速
actorOptions = rlRepresentationOptions('LearnRate', 2e-5, 'GradientThreshold', 1);
if useGPU
    actorOptions.UseDevice = 'gpu';
    disp('Actor network will use GPU acceleration.');
end

% 拟合Actor
actor = rlDeterministicActorRepresentation(actorNetwork, obsInfo, actionInfo,...
    'Observation', {'State'}, 'Action', {'Action'}, actorOptions);

% 正式创建智能体
agentOpts = rlDDPGAgentOptions(...
    'SampleTime', Ts, ...
    'TargetSmoothFactor', 0.01, ...
    'DiscountFactor', 0.99, ...
    'MiniBatchSize', 256, ...          % 增大批处理大小以更好地利用GPU
    'ExperienceBufferLength', 1e6);
agentOpts.NoiseOptions.Variance = 500;        % 增加探索噪声
agentOpts.NoiseOptions.VarianceDecayRate = 0.99;% 每轮衰减2‰（1000轮后衰减到 ~1.0*(0.998)^1000≈0.135）
agentOpts.NoiseOptions.VarianceMin = 50;

agent = rlDDPGAgent(actor, critic, agentOpts); 

% 设置训练选项
maxepisodes = 100; % 增加训练回合数
maxsteps = ceil(Tf/Ts);

% 设置训练选项 - 使用支持的参数
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', maxepisodes, ...
    'MaxStepsPerEpisode', maxsteps, ...
    'ScoreAveragingWindowLength', 20, ...
    'Verbose', false, ...
    'Plots', 'training-progress', ...
    'StopTrainingCriteria', 'AverageReward', ...
    'StopTrainingValue', 50000, ...
    'SaveAgentCriteria', "EpisodeReward", ...  % 基于奖励保存
    'SaveAgentValue', 0, ...               % 当奖励>1000时保存
    'SaveAgentDirectory', 'saved_agents', ... % 指定保存目录
    'UseParallel', useGPU);

% 创建保存目录
if ~exist('saved_agents', 'dir')
    mkdir('saved_agents');
end

% 保存当前工作区变量
save('training_setup.mat', 'agent', 'env', 'trainOpts');
% 正式开始训练智能体
disp('Starting training with improved reward function...');
trainingStats = train(agent, env, trainOpts);
% 训练后处理：加载最佳权重
best_agent = findBestAgent(trainingStats);

% 用最佳智能体与环境交互
%simOptions = rlSimulationOptions('MaxSteps', maxsteps);
%experience = sim(env, best_agent, simOptions);

% 保存最终的最佳智能体
save('trained_agent_ddpg_final.mat', 'best_agent');
fprintf('训练完成！最佳权重已保存。\n');

% 显示训练总结
fprintf('\n=== 训练总结 ===\n');
fprintf('总训练时长: %.1f 小时\n', trainingStats.TrainingTime/3600);
fprintf('总episode数: %d\n', trainingStats.EpisodeIndex(end));

% 重置函数 - 添加环境随机化
function in = localResetFcn(in, mdl)
    % 随机化负载条件 - 根据2kW系统调整
    % 从轻载(10%)到重载(120%)
    mdlwks = get_param(mdl, 'ModelWorkspace');
    Iout = mdlwks.getVariable('I');
    Iout = Iout*2;
    random_load = 0.1 * Iout + (1.2 * Iout - 0.1 * Iout) * rand();
    in = setVariable(in, 'Load_Current', random_load);
    
    % 随机化初始输出电压
    random_init_vout = 10 + (14 - 10) * rand(); % 在10V到14V之间随机
    in = setVariable(in, 'Initial_Voltage', random_init_vout);
    
    fprintf('Environment reset with Load=%.2fA, Initial Vout=%.2fV\n', ...
        random_load, random_init_vout);
end

% ========== 新增：查找最佳agent函数 ==========
function best_agent = findBestAgent(trainingStats)
    % 获取所有保存的agent文件（按Agent+轮数命名）
    agentFiles = dir(fullfile('saved_agents', 'Agent*.mat'));
    
    if isempty(agentFiles)
        fprintf('警告: 没有找到保存的agent文件，使用最终训练权重\n');
        best_agent = trainingStats.Agent;
        return;
    end
    
    % 按文件名中的数字排序，找到最后一轮的文件
    episodeNumbers = zeros(1, length(agentFiles));
    for i = 1:length(agentFiles)
        filename = agentFiles(i).name;
        % 提取文件名中的数字（Agent后面的数字）
        numStr = regexp(filename, 'Agent(\d+)\.mat', 'tokens');
        if ~isempty(numStr)
            episodeNumbers(i) = str2double(numStr{1}{1});
        else
            episodeNumbers(i) = 0; % 如果不是标准命名，设为0
        end
    end
    
    % 找到最大的轮数（最后一轮）
    [maxEpisode, maxIdx] = max(episodeNumbers);
    lastEpisodeFile = fullfile('saved_agents', agentFiles(maxIdx).name);
    
    fprintf('找到最后一轮文件: %s (第%d轮)\n', lastEpisodeFile, maxEpisode);
    
    % 加载最后一轮文件，获取奖励历史
    try
        lastEpisodeData = load(lastEpisodeFile);
        % 获取所有轮的奖励
        allRewards = lastEpisodeData.savedAgentResult.EpisodeReward;
            
        % 移除空值（如果有的话）
        validRewards = allRewards(~isnan(allRewards) & allRewards ~= 0);
            
        if isempty(validRewards)
            fprintf('警告: 奖励数据为空，使用最后一轮agent\n');
            best_agent = lastEpisodeData.saved_agent;
            return;
        end
            
        % 找到奖励最高的轮数
        [maxReward, bestEpisodeIdx] = max(validRewards);
            
        fprintf('所有轮奖励: %s\n', mat2str(validRewards'));
        fprintf('最高奖励: %.4f (出现在第%d轮)\n', maxReward, bestEpisodeIdx);
            
            % 找到对应轮数的agent文件
        bestEpisodeFile = '';
        for i = 1:length(agentFiles)
            filename = agentFiles(i).name;
            numStr = regexp(filename, 'Agent(\d+)\.mat', 'tokens');
            if ~isempty(numStr) && str2double(numStr{1}{1}) == bestEpisodeIdx
                bestEpisodeFile = fullfile('saved_agents', agentFiles(i).name);
                break;
            end
        end
        % 加载最佳轮数的agent
        bestEpisodeData = load(bestEpisodeFile);
        if isfield(bestEpisodeData, 'saved_agent')
            best_agent = bestEpisodeData.saved_agent;
            fprintf('成功加载最佳agent: %s (奖励: %.4f)\n', bestEpisodeFile, maxReward);
        else
            fprintf('警告: 最佳轮数文件中未找到saved_agent，使用最后一轮agent\n');
            best_agent = lastEpisodeData.saved_agent;
        end
    end
       
end