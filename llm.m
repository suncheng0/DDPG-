clc;
clear;
close all;

% 设置API URL
url = 'http://localhost:1234/v1/chat/completions';  % 本地模型服务地址

% 构建消息体，保持与API要求一致
messages = struct(...
    'role', {'system', 'user'}, ...
    'content', {'You are a helpful assistant.', ''} ...
);

% 定义请求体
payload = struct(...
    'model', 'deepseek', ...  % 替换为你的本地模型名称
    'messages', {messages} ...
);

% JSON编码请求体
payloadJson = jsonencode(payload);

% 设置请求头，确保格式正确
options = weboptions(...
    'HeaderFields', {...
        'Authorization', ['Bearer ' 'sk-']; ...
        'Content-Type', 'application/json'; ...
    }, ...
    'MediaType', 'application/json', ...
    'Timeout', 30 ...  % 延长超时时间
);

% 发送POST请求
response = webwrite(url, payloadJson, options);

% 输出响应结果
disp(response);
responseText = response.choices.message.content;
