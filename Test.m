function varargout = Test(varargin)
% TEST MATLAB code for Test.fig
%      TEST, by itself, creates a new TEST or raises the existing
%      singleton*.
%
%      H = TEST returns the handle to a new TEST or the handle to
%      the existing singleton*.
%
%      TEST('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in TEST.M with the given input arguments.
%
%      TEST('Property','Value',...) creates a new TEST or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Test_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Test_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".

% Last Modified by GUIDE v2.5 20-Sep-2025 14:00:21

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Test_OpeningFcn, ...
                   'gui_OutputFcn',  @Test_OutputFcn, ...
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


% --- Executes just before Test is made visible.
function Test_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
handles.output = hObject;
guidata(hObject, handles);
% uiwait(handles.figure1);
% Làm trống axes1 với khung vuông
axes(handles.axes1);
cla reset;
axis off;           % tắt trục
axis image;         % giữ tỉ lệ vuông cho khung
rectangle('Position',[0 0 800 1024],'EdgeColor','k'); % vẽ khung placeholder 256x256

% Làm trống axes2 với khung vuông
axes(handles.axes2);
cla reset;
axis off;
axis image;
rectangle('Position',[0 0 800 1024],'EdgeColor','k');
set(handles.pushbutton1, 'BackgroundColor', [1 0 0]); % màu đỏ
set(handles.pushbutton2, 'BackgroundColor', [0 0 1]); % màu xanh
set(handles.pushbutton3, 'BackgroundColor', [0 0 1]); % màu xanh
set(handles.pushbutton4, 'BackgroundColor', [0.8 0.8 0.8]); % màu xám
set(handles.figure1, 'Color', [0.9 0.95 1]); % xanh nhạt



% --- Outputs from this function are returned to the command line.
function varargout = Test_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;



% --- Executes on button press in pushbutton1. (Exit)
function pushbutton1_Callback(hObject, eventdata, handles) 
    choice = questdlg('Are you sure you want to exit?', ...
        'Exit Application', ...
        'Yes','No','No');
    if strcmp(choice,'Yes')
        close(gcf);
    end


% --- Executes on button press in pushbutton2. (Chọn ảnh)
function pushbutton2_Callback(hObject, eventdata, handles) 
    [filename, pathname] = uigetfile({'*.png;*.jpg;*.bmp'}, 'Chọn ảnh');
    if isequal(filename,0)
        return;
    end
    imgPath = fullfile(pathname, filename);
    img = imread(imgPath);
    
    % Nếu ảnh màu thì chuyển sang grayscale
    if size(img,3) == 3
        img = rgb2gray(img);
    end
    
    handles.img = double(img); % Lưu vào handles
    
    % Hiển thị ảnh
    axes(handles.axes1);
    imshow(uint8(handles.img));
    axis(handles.axes1, 'off'); 
    
    % --- Tính dung lượng ảnh gốc (ảnh xám) ---
    orig_bytes = numel(img); % số pixel
    orig_kb = orig_bytes / 1024;
    set(handles.OrigImgSize, 'String', ...
        sprintf('OrigImgSize= %.2f KB', orig_kb));

    guidata(hObject, handles); % cập nhật dữ liệu



% --- Executes on button press in pushbutton3. (run DPCM)
function pushbutton3_Callback(hObject, eventdata, handles)
    % Bảo vệ: kiểm tra handles.img
    if ~isfield(handles, 'img') || isempty(handles.img)
        errordlg('Không có ảnh trong handles.img. Hãy load ảnh trước.','Error');
        return;
    end

    % --- Lấy ảnh gốc và chuyển sang double grayscale ---
    img_orig = handles.img;
    if size(img_orig,3) == 3
        img_gray = rgb2gray(img_orig);
    else
        img_gray = img_orig;
    end
    img = double(img_gray);      % phạm vi mong đợi: [0,255]

    [rows, cols] = size(img);

    % --- THAM SỐ (có thể thay đổi) ---
    Qstep = 2;            % bước lượng tử (2: đẹp, 4: mất nhiều, 8: rất nén)
    useDither = true;     % bật subtractive dither để giảm banding
    ditherSeed = 12345;   % seed cố định để encoder/decoder tái tạo cùng dither

    % --- Tạo ma trận dither (subtractive) với seed cố định ---
    if useDither
        rngState = rng;
        rng(ditherSeed, 'twister');
        D = (rand(rows, cols) - 0.5) * Qstep;
        rng(rngState);
    else
        D = zeros(rows, cols);
    end

    % --- ENCODER ---
    q_index = zeros(rows, cols);
    recon_enc = zeros(rows, cols);

    for r = 1:rows
        for c = 1:cols
            if r == 1 && c == 1
                pred = 0;
            elseif r == 1
                pred = recon_enc(r, c-1);
            elseif c == 1
                pred = recon_enc(r-1, c);
            else
                left = recon_enc(r, c-1);
                top = recon_enc(r-1, c);
                topleft = recon_enc(r-1, c-1);
                pred = median([left, top, left + top - topleft]);
            end

            e = img(r,c) - pred;
            d = D(r,c);
            e_dithered = e + d;

            q = round(e_dithered / Qstep);
            deq = q * Qstep;
            e_hat = deq - d;

            recon_enc(r,c) = pred + e_hat;
            q_index(r,c) = q;
        end
    end

    % --- DECODER ---
    recon_dec = zeros(rows, cols);
    for r = 1:rows
        for c = 1:cols
            if r == 1 && c == 1
                pred = 0;
            elseif r == 1
                pred = recon_dec(r, c-1);
            elseif c == 1
                pred = recon_dec(r-1, c);
            else
                left = recon_dec(r, c-1);
                top = recon_dec(r-1, c);
                topleft = recon_dec(r-1, c-1);
                pred = median([left, top, left + top - topleft]);
            end

            q = q_index(r,c);
            deq = q * Qstep;
            d = D(r,c);
            e_hat = deq - d;
            recon_dec(r,c) = pred + e_hat;
        end
    end

    % --- Clip và convert về uint8 ---
    recon_dec = min(max(recon_dec, 0), 255);
    reconstructed_uint8 = uint8(round(recon_dec));

    % --- Hiển thị ảnh ---
    if isfield(handles, 'axes1') && ishandle(handles.axes1)
        axes(handles.axes1);
        imshow(uint8(img));
        axis(handles.axes1, 'off');
    end
    if isfield(handles, 'axes2') && ishandle(handles.axes2)
        axes(handles.axes2);
        imshow(reconstructed_uint8);
        axis(handles.axes2, 'off');
    end

    % --- Tính số liệu đánh giá ---
    diff = double(img) - double(reconstructed_uint8);
    mse = mean(diff(:).^2);
    if mse == 0
        psnr_val = Inf;
        snr_val = Inf;
    else
        psnr_val = 10 * log10((255^2) / mse);
        snr_val = 10 * log10(sum(double(img(:)).^2) / sum(diff(:).^2));
    end

    if isfield(handles, 'MSE')
        set(handles.MSE, 'String', sprintf('MSE = %.2f', mse));
    end
    if isfield(handles, 'PSNR')
        set(handles.PSNR, 'String', sprintf('PSNR = %.2f dB', psnr_val));
    end
    if isfield(handles, 'SNR')
        set(handles.SNR, 'String', sprintf('SNR = %.2f dB', snr_val));
    end


    % --- Kích thước dữ liệu nén ---
    max_symbol = double(max(q_index(:)));
    bits_per_symbol = ceil(log2(max_symbol + 1));
    Nsymbols = numel(q_index);

    CompDataSize_kb = (Nsymbols * bits_per_symbol) / 8192;   % KB
    CompImgSize_kb  = (rows * cols * bits_per_symbol) / 8192;
    StorageSize_kb  = CompDataSize_kb;  % mô phỏng lưu trữ = dữ liệu nén
    CompBitrate     = (CompDataSize_kb * 8192) / (rows * cols); % bpp

    % --- Hiển thị GUI ---
    set(handles.CompDataSize, 'String', sprintf('CompDataSize = %.2f KB', CompDataSize_kb));
    set(handles.CompImgSize,  'String', sprintf('CompImgSize = %.2f KB', CompImgSize_kb));
    set(handles.StorageSize,  'String', sprintf('StorageSize = %.2f KB', StorageSize_kb));
    set(handles.CompBitrate,  'String', sprintf('CompBitrate = %.2f bpp', CompBitrate));

    % --- Hiển thị ---
    set(handles.CompDataSize, 'String', sprintf('CompDataSize = %.2f KB', CompData_kb));
    set(handles.CompImgSize,  'String', sprintf('CompImgSize = %.2f KB', CompImg_kb));
    set(handles.StorageSize,  'String', sprintf('StorageSize = %.2f KB', Storage_kb));
    set(handles.CompBitrate,  'String', sprintf('CompBitrate = %.2f bpp', Comp_bitrate));


    % --- Lưu kết quả ---
    handles.reconstructed = reconstructed_uint8;
    handles.dpcm.q_index = q_index;
    handles.dpcm.Qstep = Qstep;
    handles.dpcm.useDither = useDither;
    handles.dpcm.ditherSeed = ditherSeed;
    guidata(hObject, handles);


  

% --- Executes on button press in pushbutton4. (Reset)
function pushbutton4_Callback(hObject, eventdata, handles) 
    % Xoá dữ liệu trong handles
    if isfield(handles, 'img')
        handles = rmfield(handles, 'img');
    end
    if isfield(handles, 'reconstructed')
        handles = rmfield(handles, 'reconstructed');
    end

    % Xoá ảnh trong axes
    cla(handles.axes1, 'reset');
    cla(handles.axes2, 'reset');

    % Xoá text kết quả
    set(handles.MSE, 'String', 'MSE');
    set(handles.PSNR, 'String', 'PSNR');
    set(handles.SNR, 'String', 'SNR');
    set(handles.OrigImgSize, 'String', 'OrigImgSize');
    set(handles.CompDataSize, 'String', 'CompDataSize');
    set(handles.CompImgSize, 'String', 'CompImgSize');
    set(handles.CompBitrate, 'String', 'CompBitrate');


    axes(handles.axes1);
    cla reset;
    axis off;           % tắt trục
    axis image;         % giữ tỉ lệ vuông cho khung
    rectangle('Position',[0 0 800 1024],'EdgeColor','k'); % vẽ khung placeholder 256x256
    
    % Làm trống axes2 với khung vuông
    axes(handles.axes2);
    cla reset;
    axis off;
    axis image;
    rectangle('Position',[0 0 800 1024],'EdgeColor','k');

    % Cập nhật lại GUI
    guidata(hObject, handles);
