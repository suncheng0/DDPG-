function varargout = contrl(varargin)
% CONTRL MATLAB code for contrl.fig
%      CONTRL, by itself, creates a new CONTRL or raises the existing
%      singleton*.
%
%      H = CONTRL returns the handle to a new CONTRL or the handle to
%      the existing singleton*.
%
%      CONTRL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CONTRL.M with the given input arguments.
%
%      CONTRL('Property','Value',...) creates a new CONTRL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before contrl_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to contrl_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help contrl

% Last Modified by GUIDE v2.5 22-Sep-2025 21:29:31

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @contrl_OpeningFcn, ...
                   'gui_OutputFcn',  @contrl_OutputFcn, ...
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


% --- Executes just before contrl is made visible.
function contrl_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to contrl (see VARARGIN)

% Choose default command line output for contrl
handles.output = hObject;
if isappdata(0, 'MainGUIHandle')
    % 从基础工作区获取主窗口句柄
    mainGUIHandle = getappdata(0, 'MainGUIHandle');
    % 获取主窗口的 handles 结构体（包含主窗口所有控件句柄）
    handles.mainHandles = guidata(mainGUIHandle);
    msgbox('子窗口打开时已成功获取主窗口句柄', '获取成功');
else
    errordlg('子窗口打开时无法获取主窗口句柄，请先确保主窗口已打开', '错误');
    handles.mainHandles = [];  % 标记为未获取到主窗口 handles
end

%% 2. 从基础工作区获取out变量并绘图
try
    % 检查基础工作区是否存在out变量
    outExist = evalin('base', 'exist(''out'', ''var'')');
    if outExist ~= 1
        errordlg('基础工作区中未找到out变量，请先运行仿真生成out', '数据缺失');
        guidata(hObject, handles);
        return;
    end
    
    % 从基础工作区获取out变量
    out = evalin('base', 'out');
    
    % 检查out中是否包含所需字段
    %requiredFields = {'V_P', 'V_I', 'I_P', 'tout'};  % 假设存在时间向量tout
    % 手动生成时间向量（替换原 out.tout）
Ts = 0.0005;   % 模型采样时间（需与 Simulink 中一致）
Tf = 0.01;     % 总仿真时间（需与 Simulink 中一致）
tout = 0:Ts:Tf;   % 生成时间点：0, 0.0005, 0.001, ..., 0.01
tout = tout(1:end-1);  % 去掉最后一个点（避免超出 Tf）
    % 提取数据
    V_P = out.V_P;    % 需绘制到axes1的电压数据
    V_I = out.V_I;    % 需绘制到axes2的电压数据
    I_P = out.I_P;    % 需绘制到axes3的电流数据
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%\
    vp = V_P.signals.values;
    vp = squeeze(vp);  % 转换后为1×21 double（行向量）
%%%%
%disp('=== 原始V_P.signals.values信息 ===');
%disp(['维度: ', mat2str(size(V_P.signals.values))]);  % 打印维度（应为1×1×N）
%disp('前5个数值:');
%disp(V_P.signals.values(1, 1, 1:min(5, size(V_P.signals.values, 3))));  % 显示前5个三维数据
%disp('=== squeeze后的数据信息 ===');
%disp(['维度: ', mat2str(size(vp))]);  % 应为1×N或N×1
%disp('前5个数值:');
%disp(vp(1:min(5, length(vp))));  % 显示转换后的前5个值

    % ==============================================
    % 检查数据长度匹配（避免绘图错误）
    % ==============================================
    plotLen = min(length(tout), length(vp));
    if plotLen ~= length(tout) || plotLen ~= length(vp)
        warning('时间与电压环P数据长度不匹配，已自动截断至最短长度（%d）', plotLen);
        toutPlot = tout(1:plotLen);
        vpPlot = vp(1:plotLen);
    else
        toutPlot = tout;
        vpPlot = vp;
    end
    % ==============================================
    % 在axes1中绘制电压环P波形（唯一绘图区域）
    % ==============================================
    axes(handles.axes1);  % 指定绘图区域为axes1
    cla;  % 清空之前的图像，避免波形叠加

    % 绘制波形并添加样式
    stairs(toutPlot, vpPlot, 'k-', 'LineWidth', 1.2);
    grid on;  % 显示网格
    xlabel('时间 (s)', 'FontSize', 8);  % 适配axes1尺寸的字体大小
    ylabel('P', 'FontSize', 8);  % 明确标注信号类型（电压）
    title(['电压环' 'P'], 'FontSize', 8, 'FontWeight', 'bold');
    box on;  % 显示坐标轴边框



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\
%%%%%%%%%%%%%%%%%%%%%%%%%%%\
    vi = V_I.signals.values;
    vi = squeeze(vi);  % 转换后为1×21 double（行向量）
    % ==============================================
    % 检查数据长度匹配（避免绘图错误）
    % ==============================================
    plotLen = min(length(tout), length(vi));
    if plotLen ~= length(tout) || plotLen ~= length(vi)
        warning('时间与电压环P数据长度不匹配，已自动截断至最短长度（%d）', plotLen);
        toutPlot = tout(1:plotLen);
        viPlot = vi(1:plotLen);
    else
        toutPlot = tout;
        viPlot = vi;
    end
    % ==============================================
    % 在axes1中绘制电压环I波形（唯一绘图区域）
    % ==============================================
    axes(handles.axes2);  % 指定绘图区域为axes2
    cla;  % 清空之前的图像，避免波形叠加

    % 绘制波形并添加样式
    stairs(toutPlot, viPlot, 'k-', 'LineWidth', 1.2);
    grid on;  % 显示网格
    xlabel('时间 (s)', 'FontSize', 8);  % 适配axes2尺寸的字体大小
    ylabel('I', 'FontSize', 8);  % 明确标注信号类型（电压）
    title(['电压环' 'I'], 'FontSize', 8, 'FontWeight', 'bold');
    box on;  % 显示坐标轴边框



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\
%%%%%%%%%%%%%%%%%%%%%%%%%%%\
    ip = I_P.signals.values;
    ip = squeeze(ip);  % 转换后为1×21 double（行向量）
    % ==============================================
    % 检查数据长度匹配（避免绘图错误）
    % ==============================================
    plotLen = min(length(tout), length(ip));
    if plotLen ~= length(tout) || plotLen ~= length(ip)
        warning('时间与电流环P数据长度不匹配，已自动截断至最短长度（%d）', plotLen);
        toutPlot = tout(1:plotLen);
        ipPlot = ip(1:plotLen);
    else
        toutPlot = tout;
        ipPlot = ip;
    end
    % ==============================================
    % 在axes3中绘制电流环P波形（唯一绘图区域）
    % ==============================================
    axes(handles.axes3);  % 指定绘图区域为axes1
    cla;  % 清空之前的图像，避免波形叠加

    % 绘制波形并添加样式
    stairs(toutPlot, ipPlot, 'k-', 'LineWidth', 1.2);
    grid on;  % 显示网格
    xlabel('时间 (s)', 'FontSize', 8);  % 适配axes1尺寸的字体大小
    ylabel('P', 'FontSize', 8);  % 明确标注信号类型（电压）
    title(['电流环' 'P'], 'FontSize', 8, 'FontWeight', 'bold');
    box on;  % 显示坐标轴边框



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\


    msgbox('波形绘制完成：V_P→axes1，V_I→axes2，I_P→axes3', '绘图成功');

catch ME
    errordlg(['绘图失败：' ME.message], '错误');
    disp(['绘图错误详情：' ME.message]);
end

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes contrl wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = contrl_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
