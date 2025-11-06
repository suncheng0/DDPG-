function varargout = deepseek(varargin)
% DEEPSEEK MATLAB code for deepseek.fig
%      DEEPSEEK, by itself, creates a new DEEPSEEK or raises the existing
%      singleton*.
%
%      H = DEEPSEEK returns the handle to a new DEEPSEEK or the handle to
%      the existing singleton*.
%
%      DEEPSEEK('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DEEPSEEK.M with the given input arguments.
%
%      DEEPSEEK('Property','Value',...) creates a new DEEPSEEK or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before deepseek_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to deepseek_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help deepseek

% Last Modified by GUIDE v2.5 09-Oct-2025 21:54:20

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @deepseek_OpeningFcn, ...
                   'gui_OutputFcn',  @deepseek_OutputFcn, ...
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
% End initialization code - DO NOT EDIT


% --- Executes just before deepseek is made visible.
function deepseek_OpeningFcn(hObject, eventdata, handles, varargin)
    % 初始化UI组件
    set(handles.edit1, 'String', '请输入你的问题...');
    set(handles.edit2, 'String', '模型将在这里显示回答...');
    set(handles.pushbutton1, 'String', '发送问题');
    
    % 设置文本框为多行显示
    set(handles.edit1, 'Max', 2);  % 允许多行输入
    set(handles.edit2, 'Max', 2);  % 允许多行输出
    set(handles.edit1, 'HorizontalAlignment', 'left');  % 左对齐
    set(handles.edit2, 'HorizontalAlignment', 'left');  % 左对齐

    % 初始化对话历史存储
    handles.chat_history = [];
    % 存储API配置到handles结构
    handles.api_url = 'http://localhost:1234/v1/chat/completions';  % 本地模型服务地址
    handles.model_name = 'deepseek';  % 模型名称
    handles.api_key = 'sk-';  % API密钥
    
    % Choose default command line output for deepseek
    handles.output = hObject;
    
    % Update handles structure
    guidata(hObject, handles);


% --- Outputs from this function are returned to the command line.
function varargout = deepseek_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
set(hObject, 'HorizontalAlignment', 'left');
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit2_Callback(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit2 as text
%        str2double(get(hObject,'String')) returns contents of edit2 as a double


% --- Executes during object creation, after setting all properties.
function edit2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
set(hObject, 'HorizontalAlignment', 'left');
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% 从输入框获取用户问题
user_question = get(handles.edit1, 'String');
disp(user_question)

%% 强化版：确保输入为字符行向量（1×N）
% 1. 处理空输入
if isempty(user_question)
    warndlg('请输入问题后再发送', '提示');
    return;
end

% 2. 处理cell数组（多行输入）
if iscell(user_question)
    % 用换行符拼接cell中的所有行，转换为字符串
    user_question = strjoin(user_question, char(10));  
end

% 3. 确保是字符类型（非数值/结构体等）
if ~ischar(user_question)
    % 转换为字符类型（适用于数值等可转换类型）
    user_question = char(user_question);
end
%% 新增：强制转换为行向量
if size(user_question, 1) > 1  % 若行数 > 1（不是行向量）
    % 按“行优先”拼接所有字符为单行
    user_question = strjoin(cellstr(user_question), '');  
end

% -------- 新增：检查转换后的user_question --------
disp('===== 转换后 user_question 调试信息 =====');
disp('转换后的 user_question 内容：');
disp(user_question);  % 打印字符串内容
disp(['转换后的 user_question 数据类型：' class(user_question)]);  % 打印数据类型（应是 'char'）
disp(['转换后的 user_question 尺寸（行×列）：' mat2str(size(user_question))]);  % 打印尺寸（应是 1×N 的行向量）
% 4. 统一换行符（处理Windows回车符）
user_question = strrep(user_question, char(13), char(10));  

% 5. 去除首尾多余空格
user_question = strtrim(user_question);

% 6. 处理列向量（转为行向量）
if size(user_question, 1) > 1 && size(user_question, 2) == 1
    user_question = user_question';  % 转置为行向量
end

% 7. 最终校验：必须是行向量
if ~isrow(user_question)
    % 强制转换为行向量（按列拼接）
    user_question = user_question(:)';
end

%% 输入预处理（清理特殊字符，确保每次strrep前是行向量）
% 确保是行向量（关键：避免strrep报错）
if ~isrow(user_question)
    user_question = user_question(:)';
end
% 替换换行符为空格（若需保留换行，可删除这行，根据需求调整）
user_question = strrep(user_question, char(10), ' ');  
% 替换回车符为空格（若需保留回车，可删除这行）
user_question = strrep(user_question, char(13), ' ');  
% 去除首尾空格
user_question = strtrim(user_question);
% 合并连续空格为单个
user_question = regexprep(user_question, '\s+', ' ');

% 再次检查输入是否为空
if isempty(user_question)
    warndlg('输入内容不能为空，请重新输入', '提示');
    return;
end

% 显示正在加载的提示
set(handles.edit2, 'String', '正在获取模型回答...');
drawnow;  % 立即更新UI

try
    % 构建消息体 - 包含完整对话历史
    if isempty(handles.chat_history)
        % 首次对话
        messages = [struct('role', 'system', 'content', 'You are a helpful assistant.'), ...
                    struct('role', 'user', 'content', user_question)];
    else
        % 后续对话，包含历史记录
        messages = [handles.chat_history, struct('role', 'user', 'content', user_question)];
    end

    % 定义请求体
    payload = struct(...
        'model', handles.model_name, ...
        'messages', messages ...
    );

    % JSON编码请求体
    payloadJson = jsonencode(payload);
    disp('请求JSON内容：');
    disp(payloadJson);

    % 设置请求头
    options = weboptions(...
        'HeaderFields', {...
            'Authorization', ['Bearer ' handles.api_key]; ...
            'Content-Type', 'application/json'; ...
        }, ...
        'MediaType', 'application/json', ...
        'Timeout', 60 ...
    );

    % 发送POST请求
    response = webwrite(handles.api_url, payloadJson, options);

    % 提取回答
    if isfield(response, 'choices') && ~isempty(response.choices)
        responseText = response.choices(1).message.content;
        
        % 更新对话历史
        handles.chat_history = [messages, struct('role', 'assistant', 'content', responseText)];
        
        % 格式化对话显示
        display_text = '';
        for i = 1:length(handles.chat_history)
            % 1. 提取内容并确保为char类型（避免string类型导致的编码问题）
            content = handles.chat_history(i).content;
            if isstring(content)
                content = char(content);  % 转换为char类型
            end
            
            % 2. 正确处理换行符（保留代码格式）
            content = strrep(content, '\n', char(10));  % 模型返回的\n转为MATLAB换行
            content = strrep(content, '\t', char(9));   % 处理制表符（代码缩进）
            
            % 3. 处理特殊字符（确保非ASCII字符正常显示）
            content = native2unicode(unicode2native(content), 'UTF-8');  % 强制UTF-8编码
            
            % 4. 拼接对话内容（区分用户和助手）
            if strcmp(handles.chat_history(i).role, 'user')
                display_text = [display_text '用户: ' content char(10) char(10)];  % 双换行分隔
            elseif strcmp(handles.chat_history(i).role, 'assistant')
                display_text = [display_text '助手: ' content char(10) char(10)];
            end
        end
        
        % 5. 最终确保display_text为char类型（避免cell或string）
        if ~ischar(display_text)
            display_text = char(display_text);
        end
        
        % 更新显示
        set(handles.edit2, 'String', display_text);

    else
        current_text = get(handles.edit2, 'String');
        set(handles.edit2, 'String', [current_text char(10) char(10) '未能从响应中提取有效回答']);
    end

catch ME
    current_text = get(handles.edit2, 'String');
    error_msg = sprintf('请求发生错误:\n%s', ME.message);
    set(handles.edit2, 'String', [current_text char(10) char(10) error_msg]);
    disp(error_msg);
end

% 保存更新后的handles
guidata(hObject, handles);
