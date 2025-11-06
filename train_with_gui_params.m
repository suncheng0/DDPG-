function train_with_gui_params()
    % 读取GUI传递的全局参数（仅保留电压环P/I上下限，删除模型名称参数）
    global TRAIN_PARAMS;
    % 仅检查电压环P/I上下限是否存在（因已删除edit5，无需检查model_name）
    if ~isfield(TRAIN_PARAMS, 'p_p_min') || ~isfield(TRAIN_PARAMS, 'p_p_max') || ...
       ~isfield(TRAIN_PARAMS, 'p_i_min') || ~isfield(TRAIN_PARAMS, 'p_i_max')
        errordlg('电压环P/I上下限参数未正确传递，请检查GUI输入', '参数错误');
        return;
    end

    % ---------------------- 环境参数设置 ----------------------
    Ts = 0.0005;   % 采样时间 (50us)
    Tf = 0.01;     % 总仿真时间
    global agent;  % 仅保留训练用的智能体变量
    saveCounter = 0;

    % ---------------------- GPU/CPU配置 ----------------------
    if gpuDeviceCount > 0
        disp('GPU detected. Enabling GPU acceleration...');
        useGPU = false;
        if isempty(gcp('nocreate'))
            parpool('local');
        end
    else
        disp('No GPU detected. Using CPU only.');
        useGPU = false;
    end

    % ---------------------- Simulink模型加载 ----------------------
    mdl = 'answer';
    if ~exist(mdl, 'file')
        errordlg(['模型文件不存在: ' mdl], '模型错误');
        return;
    end
    open_system(mdl);

    % ---------------------- 观测空间与动作空间定义 ----------------------
    obsInfo = rlNumericSpec([6 1]);  % 6维观测空间

    % 动作空间（使用GUI传递的电压环P/I上下限）
    actionLower = [
        TRAIN_PARAMS.p_p_min;  % 电压环P下限（来自GUI）
        TRAIN_PARAMS.p_i_min;  % 电压环I下限（来自GUI）
        0.03                  % 电流环P下限（固定）
    ];
    actionUpper = [
        TRAIN_PARAMS.p_p_max;  % 电压环P上限（来自GUI）
        TRAIN_PARAMS.p_i_max;  % 电压环I上限（来自GUI）
        0.05                   % 电流环P上限（固定）
    ];
    actionInfo = rlNumericSpec([3 1], 'LowerLimit', actionLower, 'UpperLimit', actionUpper);

    % ---------------------- 环境与智能体块配置 ----------------------
    agent_blk = [mdl '/RL Agent'];
    env = rlSimulinkEnv(mdl, agent_blk, obsInfo, actionInfo);
    env.ResetFcn = @(in)localResetFcn(in, mdl);  % 环境重置函数

    rng(0);  % 固定随机种子

    % ---------------------- Critic网络构建 ----------------------
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

    criticOpts = rlRepresentationOptions('LearnRate', 1e-4, 'GradientThreshold', 1);
    if useGPU
        criticOpts.UseDevice = 'gpu';
        disp('Critic network will use GPU acceleration.');
    end
    critic = rlQValueRepresentation(criticNetwork, obsInfo, actionInfo, ...
        'Observation', {'State'}, 'Action', {'Action'}, criticOpts);

    % ---------------------- Actor网络构建 ----------------------
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

    actorOptions = rlRepresentationOptions('LearnRate', 2e-5, 'GradientThreshold', 1);
    if useGPU
        actorOptions.UseDevice = 'gpu';
        disp('Actor network will use GPU acceleration.');
    end
    actor = rlDeterministicActorRepresentation(actorNetwork, obsInfo, actionInfo, ...
        'Observation', {'State'}, 'Action', {'Action'}, actorOptions);

    % ---------------------- DDPG智能体创建 ----------------------
    agentOpts = rlDDPGAgentOptions(...
        'SampleTime', Ts, ...
        'TargetSmoothFactor', 0.01, ...
        'DiscountFactor', 0.99, ...
        'MiniBatchSize', 256, ...
        'ExperienceBufferLength', 1e6);
    agentOpts.NoiseOptions.Variance = 500;
    agentOpts.NoiseOptions.VarianceDecayRate = 0.99;
    agentOpts.NoiseOptions.VarianceMin = 50;

    agent = rlDDPGAgent(actor, critic, agentOpts);

    % ---------------------- 训练选项设置 ----------------------
    maxepisodes = 30;  % 训练回合数
    maxsteps = ceil(Tf / Ts);

    trainOpts = rlTrainingOptions(...
        'MaxEpisodes', maxepisodes, ...
        'MaxStepsPerEpisode', maxsteps, ...
        'ScoreAveragingWindowLength', 20, ...
        'Verbose', false, ...
        'Plots', 'training-progress', ...
        'StopTrainingCriteria', 'AverageReward', ...
        'StopTrainingValue', 50000, ...
        'SaveAgentCriteria', 'EpisodeReward', ...
        'SaveAgentValue', 50, ...
        'SaveAgentDirectory', 'saved_agents', ...
        'UseParallel', useGPU);

    % 创建保存目录
    if ~exist('saved_agents', 'dir')
        mkdir('saved_agents');
    end
    % 保存训练配置
    save('training_setup.mat', 'agent', 'env', 'trainOpts');

    

    % ---------------------- 启动训练 ----------------------
    disp('Starting training with improved reward function...');
    trainingStats = train(agent, env, trainOpts);

    % ---------------------- 训练后处理：保存最后一轮agent（固定名称newmodel） ----------------------
    % 固定模型名称为newmodel，保存至saved_agents目录
    save_path = fullfile('saved_agents', 'newmodel_final_agent.mat');
    save(save_path, 'agent');  % 保存最后一轮训练的agent
    fprintf('训练完成！模型已保存至：%s\n', save_path);


% ---------------------- 嵌套函数：环境重置 ----------------------
function in = localResetFcn(in, mdl)
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

end  % 主函数结束