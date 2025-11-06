function varargout = LOAD(varargin)
% LOAD MATLAB code for LOAD.fig
%      LOAD, by itself, creates a new LOAD or raises the existing
%      singleton*.
%
%      H = LOAD returns the handle to a new LOAD or the handle to
%      the existing singleton*.
%
%      LOAD('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in LOAD.M with the given input arguments.
%
%      LOAD('Property','Value',...) creates a new LOAD or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before LOAD_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to LOAD_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help LOAD

% Last Modified by GUIDE v2.5 01-Nov-2025 12:23:07

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @LOAD_OpeningFcn, ...
                   'gui_OutputFcn',  @LOAD_OutputFcn, ...
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


% --- Executes just before LOAD is made visible.
function LOAD_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to LOAD (see VARARGIN)

% Choose default command line output for LOAD
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes LOAD wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = LOAD_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton1.


% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
    if isappdata(0, 'MainGUIHandle')
        
        mainHandle = getappdata(0, 'MainGUIHandle');
        mainHandles = guidata(mainHandle);  % 主窗口的handles结构体
        msgbox('获得主窗口句柄', '成功');
        
        % 清空主窗口的坐标轴（使用mainHandles，不是子窗口的handles）
        axes(mainHandles.axes1);  % 切换到主窗口的axes1
        cla;
        axes(mainHandles.axes2);  % 切换到主窗口的axes2
        cla;
        
        % 更新主窗口的文本（使用mainHandles）
        set(mainHandles.text1, 'String', '当前是DDPG');
        set(mainHandles.text4, 'String', 'trained_agent_ddpg.mat');  % 显示加载的权重文件名
        % 加载智能体并传递到基础工作区
        load('trained_agent_ddpg.mat');
        agent = saved_agent;
        assignin('base', 'agent', agent);
        msgbox('DDPG智能体权重加载成功！', '加载成功');
    else
        errordlg('无法访问主窗口', '错误');
    end



function edit1_Callback(hObject, eventdata, handles)

function edit1_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end

function pushbutton3_Callback(hObject, eventdata, handles)
    try
        % 1. 从edit1获取权重文件路径（用户输入的路径）
        weightPath = get(handles.edit1, 'String');
        % 2. 验证路径是否为空
        if isempty(weightPath)
            errordlg('权重文件路径不能为空，请在edit1中输入完整路径', '输入错误');
            return;
        end
        % 3. 验证文件是否存在（含.mat扩展名检查）
        if ~endsWith(weightPath, '.mat')
            weightPath = [weightPath '.mat'];  % 自动补充.mat扩展名
        end
        if ~exist(weightPath, 'file')
            errordlg(['权重文件不存在：' weightPath '请检查路径是否正确'], '文件错误');
            return;
        end
        % 4. 加载权重文件并传递到基础工作区
        
        load(weightPath);  % 加载用户指定的.mat文件
        % 5. 验证文件中是否包含agent变量
        if ~exist('agent', 'var') && ~exist('saved_agent', 'var')
            error('加载的权重文件中未找到agent变量，请确认文件格式正确');
        end
        if exist('agent','var')
            assignin('base', 'agent', agent);  % 将agent存入基础工作区
        else
            assignin('base', 'agent', saved_agent);
        end
        % 6. （可选）更新主窗口状态（如果需要）
        if isappdata(0, 'MainGUIHandle')
            mainHandle = getappdata(0, 'MainGUIHandle');
            mainHandles = guidata(mainHandle);
            % 更新主窗口text1显示当前加载状态
            set(mainHandles.text1, 'String', '自定义路径');
            % 更新主窗口text4显示文件路径
            set(mainHandles.text4, 'String', weightPath);
        end
        
        % 7. 提示加载成功
        msgbox(['权重文件加载成功：' weightPath], '加载成功');
        
    catch ME
        % 错误处理
        errordlg(['加载失败：' ME.message], '错误');
        disp(['权重加载错误详情：' ME.message]);  % 命令行打印详细信息
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
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    power_value = str2double(get(handles.edit2, 'String')); % 从edit2读取功率值
    update_simulink_parameters(power_value);
    msgbox('Simulink参数更新成功！', '参数更新');

