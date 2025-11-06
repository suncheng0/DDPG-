function varargout = m_c_k_GUI(varargin)
    %入口函数
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @m_c_k_GUI_OpeningFcn, ...
                       'gui_OutputFcn',  @m_c_k_GUI_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end
    
    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
end
% End initialization code - DO NOT EDIT


% --- Executes just before m_c_k_GUI is made visible.
function m_c_k_GUI_OpeningFcn(hObject, eventdata, handles, varargin)
    %获得窗口句柄
    handles.output = hObject; 
    setappdata(0, 'MainGUIHandle', hObject);    % 存储主窗口句柄到根对象的应用数据
    guidata(hObject, handles);
end
%%%%%%%
function varargout = m_c_k_GUI_OutputFcn(hObject, eventdata, handles) 
    %用于处理 GUI 界面的输出
    varargout{1} = handles.output;
end
function pushbutton1_Callback(hObject, eventdata, handles)
    modelPath = 'answer.slx';  % 模型路径
    agentExist = evalin('base', 'exist(''agent'', ''var'')');  % 合法用法：检查基础工作区变量
    if agentExist ~= 1  % 1表示变量存在，其他值（0/2/3等）表示不存在
        errordlg('未检测到智能体！请先通过button3或button4加载SAC/DDPG权重', '仿真错误');
        return;  % 未加载agent则终止仿真
    end 

%%%%%%%%
evalin('base', 'clear out');  % 在基础工作区清除out
%%%%%%%%
    simOut = sim(modelPath);  % 直接仿真
assignin('base', 'out', simOut); 
    curV = simOut.curV;  % 电压
    tout = simOut.tout;  % 时间向量

global g_tout;
g_tout = tout;

    % 提取电压信号值（从signals子结构体）
    if ~isfield(curV, 'signals') || ~isfield(curV.signals, 'values')
        error('电压信号结构体中缺少signals.values字段，请检查示波器配置');
    end
    voltageData = curV.signals.values;

    % ==============================================
    % 检查数据长度匹配（避免绘图错误）
    % ==============================================
    plotLen = min(length(tout), length(voltageData));
    if plotLen ~= length(tout) || plotLen ~= length(voltageData)
        warning('时间与电压数据长度不匹配，已自动截断至最短长度（%d）', plotLen);
        toutPlot = tout(1:plotLen);
        voltagePlot = voltageData(1:plotLen);
    else
        toutPlot = tout;
        voltagePlot = voltageData;
    end

    % ==============================================
    % 在axes1中绘制电压波形（唯一绘图区域）
    % ==============================================
    axes(handles.axes1);  % 指定绘图区域为axes1
    cla;  % 清空之前的图像，避免波形叠加

    % 绘制电压波形（根据当前算法自动区分颜色，可选）
    % 从handles获取当前算法（若button3/4中已存储），无则默认黑色
    if isfield(handles, 'current_algorithm')
        if strcmp(handles.current_algorithm, 'SAC')
            plotColor = 'b-';  % SAC算法用蓝色
            algoName = 'SAC';
        elseif strcmp(handles.current_algorithm, 'DDPG')
            plotColor = 'r-';  % DDPG算法用红色
            algoName = 'DDPG';
        else
            plotColor = 'k-';  % 未知算法用黑色
            algoName = '当前';
        end
    else
        plotColor = 'k-';
        algoName = '当前';
    end

    % 绘制波形并添加样式
    plot(toutPlot, voltagePlot, plotColor, 'LineWidth', 1.2);
    grid on;  % 显示网格
    xlabel('时间 (s)', 'FontSize', 8);  % 适配axes1尺寸的字体大小
    ylabel('电压 (V)', 'FontSize', 8);  % 明确标注信号类型（电压）
    title([algoName '算法-电压波形（目标12V）'], 'FontSize', 8, 'FontWeight', 'bold');
    box on;  % 显示坐标轴边框

    % （可选）添加目标电压12V参考线，便于观察控制效果
    hold on;
    plot(toutPlot, ones(size(toutPlot))*12, 'g--', 'LineWidth', 1, 'DisplayName', '目标12V');
    legend('实际电压', '目标12V', 'FontSize', 8);  % 显示图例
    hold off;

       % ==============================================
        % 4. 提取curI电流信号数据并绘制到axes2（修正后逻辑）
        % ==============================================
        % 检查并提取curI数据
        curI = simOut.curI;
        if ~isfield(curI, 'signals') || length(curI.signals) ~= 2
            error('电流信号signals应为1×2结构体数组，请检查示波器配置');
        end

        % 从signals结构体数组中分别获取两条曲线的values
        currentData1 = curI.signals(1).values;
        currentData2 = curI.signals(2).values;

        % 检查数据长度（修改min函数调用方式）
        lenTout = length(tout);
        lenData1 = length(currentData1);
        lenData2 = length(currentData2);
        plotLenI = min([lenTout, lenData1, lenData2]); % 将长度放入数组后求最小值
        toutPlotI = tout(1:plotLenI);
        currentPlot1 = currentData1(1:plotLenI);
        currentPlot2 = currentData2(1:plotLenI);

        % 绘制到axes2
        axes(handles.axes2);
        cla;
        plot(toutPlotI, currentPlot1, 'm-', 'LineWidth', 1.2, 'DisplayName', '电流曲线1');
        hold on;
        plot(toutPlotI, currentPlot2, 'c-', 'LineWidth', 1.2, 'DisplayName', '电流曲线2');
        hold off;
        grid on;
        xlabel('时间 (s)', 'FontSize', 10);
        ylabel('电流 (A)', 'FontSize', 10);
        title([algoName '算法-电流波形'], 'FontSize', 12, 'FontWeight', 'bold');
        legend('show', 'FontSize', 8);
        box on;






    % ==============================================
    % 保存仿真结果到handles（供后续分析使用）
    % ==============================================
    handles.simOut = simOut;
    guidata(hObject, handles);  % 更新handles结构体

    % （可选）弹出仿真成功提示
    msgbox([algoName '算法仿真完成，波形已绘制到axes1'], '仿真成功');


    try
        % 检查 LOAD GUI 是否已存在
        loadFig = findall(0, 'Type', 'figure', 'Name', 'contol');
        
        if isempty(loadFig)
            % 如果不存在，创建新实例
            control;
        else
            % 如果已存在，将其前置显示
            figure(loadFig);
        end
    catch ME
        % 错误处理
        errordlg(['无法打开 control 窗口: ' ME.message], '错误');
    end



end
%%%%%%%%%%

% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)

end
% --- Executes on button press in pushbutton2.
function pushbutton3_Callback(hObject, eventdata, handles)

end


% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles)
    % 打开 LOAD 窗口
    try
        % 检查 LOAD GUI 是否已存在
        loadFig = findall(0, 'Type', 'figure', 'Name', 'LOAD');
        
        if isempty(loadFig)
            % 如果不存在，创建新实例
            LOAD;
        else
            % 如果已存在，将其前置显示
            figure(loadFig);
        end
    catch ME
        % 错误处理
        errordlg(['无法打开 LOAD 窗口: ' ME.message], '错误');
    end
end


% --- Executes on button press in pushbutton15.
function pushbutton15_Callback(hObject, eventdata, handles)
    % 打开 LLM 窗口
    try
        % 检查 deepseek GUI 是否已存在
        loadFig = findall(0, 'Type', 'figure', 'Name', 'deepseek');
        
        if isempty(loadFig)
            % 如果不存在，创建新实例
            deepseek;
        else
            % 如果已存在，将其前置显示
            figure(loadFig);
        end
    catch ME
        % 错误处理
        errordlg(['无法打开 deepseek 窗口: ' ME.message], '错误');
    end

end

% --- Executes on button press in pushbutton16.
function pushbutton16_Callback(hObject, eventdata, handles)
    % 模型文件名称
    modelName = 'answer.slx';
    
    try
        % 检查文件是否存在
        if ~exist(modelName, 'file')
            error('模型文件不存在不存在: %s', modelName);
        end
        
        % 打开模型（不运行，仅在Simulink中打开）
        open_system(modelName);
        
        % 提示打开成功
        msgbox(['模型已成功打开：' modelName], '操作成功');
        
    catch ME
        % 错误处理
        errordlg(['打开模型失败：' ME.message], '错误');
        disp(['模型打开错误详情：' ME.message]);
    end
end


% --- Executes on button press in pushbutton17.
function pushbutton17_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton17 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% 打开 control 窗口
    try
        % 检查 LOAD GUI 是否已存在
        loadFig = findall(0, 'Type', 'figure', 'Name', 'contol');
        
        if isempty(loadFig)
            % 如果不存在，创建新实例
            control;
        else
            % 如果已存在，将其前置显示
            figure(loadFig);
        end
    catch ME
        % 错误处理
        errordlg(['无法打开 control 窗口: ' ME.message], '错误');
    end



end


% --- Executes on button press in pushbutton19.
function pushbutton19_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton19 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% 定义目标模块的完整路径（模型名 + 模块层级路径）
    blockPath = 'answer/caluate  reward/MATLAB Function';
    
    try
        % 步骤1：检查模型文件是否存在（可选，也可直接尝试打开模块）
        modelFile = 'D:/tai_da/922/chengpin/answer.slx';
        if ~exist(modelFile, 'file')
            error('模型文件不存在: %s', modelFile);
        end
        
        % 步骤2：打开指定的 MATLAB Function 模块
        % 若模型未打开，open_system 会自动打开模型并定位到该模块
        open_system(blockPath);
        
        % 提示操作成功
        msgbox(['模块已成功打开：' blockPath], '操作成功');
        
    catch ME
        % 错误处理：捕获并提示错误
        errordlg(['打开模块失败：' ME.message], '错误');
        disp(['模块打开错误详情：' ME.message]);
    end
end

% --- Executes on button press in pushbutton20.
function pushbutton20_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton20 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    untitled;
end


% --- Executes on button press in pushbutton21.
function pushbutton21_Callback(hObject, eventdata, handles)
% 打开 train.fig 子界面
try
    % 检查 train 子界面是否已存在（通过 figure 的 Name 属性判断）
    trainFig = findall(0, 'Type', 'figure', 'Name', 'train');  % 假设 train.fig 的 Name 属性为 'train'
    
    if isempty(trainFig)
        % 若子界面不存在，打开 train.fig
        openfig('train.fig');  % 若 train.fig 与主界面在同一目录，直接用文件名；否则需写完整路径（如 'D:/path/to/train.fig'）
    else
        % 若子界面已存在，将其前置显示
        figure(trainFig);
    end
catch ME
    % 错误处理（如文件不存在、打开失败等）
    errordlg(['无法打开 train 子界面: ' ME.message], '错误');
end
end
