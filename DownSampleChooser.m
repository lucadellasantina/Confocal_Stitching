function varargout = DownSampleChooser(varargin)
% DOWNSAMPLECHOOSER M-file for DownSampleChooser.fig
%      DOWNSAMPLECHOOSER, by itself, creates a new DOWNSAMPLECHOOSER or raises the existing
%      singleton*.
%
%      H = DOWNSAMPLECHOOSER returns the handle to a new DOWNSAMPLECHOOSER or the handle to
%      the existing singleton*.
%
%      DOWNSAMPLECHOOSER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DOWNSAMPLECHOOSER.M with the given input arguments.
%
%      DOWNSAMPLECHOOSER('Property','Value',...) creates a new DOWNSAMPLECHOOSER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before DownSampleChooser_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to DownSampleChooser_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help DownSampleChooser

% Last Modified by GUIDE v2.5 26-Oct-2009 13:03:55

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @DownSampleChooser_OpeningFcn, ...
                   'gui_OutputFcn',  @DownSampleChooser_OutputFcn, ...
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


% --- Executes just before DownSampleChooser is made visible.
function DownSampleChooser_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to DownSampleChooser (see VARARGIN)

% Choose default command line output for DownSampleChooser
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes DownSampleChooser wait for user response (see UIRESUME)
% uiwait(handles.figure1);

if(nargin < 2)
  SizeVec = varargin{1};
else
  StyleStruct = varargin{2};
  SizeVec = [StyleStruct.XRange(2) - StyleStruct.XRange(1) + 1, ...
	     StyleStruct.YRange(2) - StyleStruct.YRange(1) + 1, ...
	     StyleStruct.ZRange(2) - StyleStruct.ZRange(1) + 1];
end

set(handles.figure1, 'UserData', SizeVec);

set(handles.XCurrent, 'String', num2str(SizeVec(1)))
set(handles.YCurrent, 'String', num2str(SizeVec(2)))
set(handles.ZCurrent, 'String', num2str(SizeVec(3)))

set(handles.XSize, 'String', num2str(SizeVec(1)))
set(handles.YSize, 'String', num2str(SizeVec(2)))
set(handles.ZSize, 'String', num2str(SizeVec(3)))

% --- Outputs from this function are returned to the command line.
function varargout = DownSampleChooser_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in OKButton.
function OKButton_Callback(hObject, eventdata, handles)
% hObject    handle to OKButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
SizeVec = [str2num(get(handles.XSize, 'String')), ...
	   str2num(get(handles.YSize, 'String')), ...
	   str2num(get(handles.ZSize, 'String'))];
set(handles.figure1, 'UserData', SizeVec);
uiresume(gcbf);


% --- Executes on button press in CancelButton.
function CancelButton_Callback(hObject, eventdata, handles)
% hObject    handle to CancelButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.figure1, 'UserData', []);
uiresume(gcbf);


function XSize_Callback(hObject, eventdata, handles)
% hObject    handle to XSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of XSize as text
%        str2double(get(hObject,'String')) returns contents of XSize as a double
Size = round(str2num(get(hObject, 'String')));
Current = str2num(get(handles.XCurrent, 'String'));
if(Size <= 0 || Size > Current)
  Size = Current;
end
set(hObject, 'String', num2str(Size))

% --- Executes during object creation, after setting all properties.
function XSize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to XSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function YSize_Callback(hObject, eventdata, handles)
% hObject    handle to YSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of YSize as text
%        str2double(get(hObject,'String')) returns contents of YSize as a double
Size = round(str2num(get(hObject, 'String')));
Current = str2num(get(handles.YCurrent, 'String'));
if(Size <= 0 || Size > Current)
  Size = Current;
end
set(hObject, 'String', num2str(Size))

% --- Executes during object creation, after setting all properties.
function YSize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to YSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ZSize_Callback(hObject, eventdata, handles)
% hObject    handle to ZSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ZSize as text
%        str2double(get(hObject,'String')) returns contents of ZSize as a double
Size = round(str2num(get(hObject, 'String')));
Current = str2num(get(handles.ZCurrent, 'String'));
if(Size <= 0 || Size > Current)
  Size = Current;
end
set(hObject, 'String', num2str(Size))

% --- Executes during object creation, after setting all properties.
function ZSize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ZSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
