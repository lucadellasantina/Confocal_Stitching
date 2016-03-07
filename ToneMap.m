function varargout = ToneMap(varargin)
% TONEMAP M-file for ToneMap.fig
%      TONEMAP, by itself, creates a new TONEMAP or raises the existing
%      singleton*.
%
%      H = TONEMAP returns the handle to a new TONEMAP or the handle to
%      the existing singleton*.
%
%      TONEMAP('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in TONEMAP.M with the given input arguments.
%
%      TONEMAP('Property','Value',...) creates a new TONEMAP or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ToneMap_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ToneMap_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ToneMap

% Last Modified by GUIDE v2.5 09-Jul-2009 11:24:54

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ToneMap_OpeningFcn, ...
                   'gui_OutputFcn',  @ToneMap_OutputFcn, ...
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

% --- Executes just before ToneMap is made visible.
function ToneMap_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ToneMap (see VARARGIN)

% Choose default command line output for ToneMap
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes ToneMap wait for user response (see UIRESUME)
% uiwait(handles.figure1);

HistStruct.Num = varargin{1};
HistStruct.Vals = varargin{2};
HistStruct.CutVal = varargin{3};

set(handles.OKButton, 'UserData', HistStruct);
set(handles.slider1, 'Max', max(HistStruct.Vals));

set(handles.ThreshEdit, 'String', num2str(HistStruct.CutVal));
set(handles.slider1, 'Value', HistStruct.CutVal);

PlotStats(handles);

% --- Outputs from this function are returned to the command line.
function varargout = ToneMap_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on slider movement.
function slider1_Callback(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
ValString = num2str(get(hObject, 'Value'));
set(handles.ThreshEdit, 'String', ValString);
PlotStats(handles);

% --- Executes during object creation, after setting all properties.
function slider1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function ThreshEdit_Callback(hObject, eventdata, handles)
% hObject    handle to ThreshEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ThreshEdit as text
%        str2double(get(hObject,'String')) returns contents of ThreshEdit as a double
Val = str2num(get(hObject, 'String'));
Max = get(handles.slider1, 'Max');
if(Val < 0)
  Val = 0;
elseif(Val > Max)
  Val = Max;
end
set(handles.slider1, 'Value', Val);
PlotStats(handles);

% --- Executes during object creation, after setting all properties.
function ThreshEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ThreshEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in OKButton.
function OKButton_Callback(hObject, eventdata, handles)
% hObject    handle to OKButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

Val = str2num(get(handles.ThreshEdit, 'String'));
set(handles.figure1, 'UserData', Val);
uiresume(gcbf);

%delete(handles.figure1);


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
delete(hObject);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function PlotStats(handles)
axes(handles.HistAxes);

HistStruct = get(handles.OKButton, 'UserData');
CutVal = get(handles.slider1, 'Value');

MaxNum = max(HistStruct.Num);

delete(get(gca, 'children'));

hold off;
bar(HistStruct.Vals, HistStruct.Num);
hold on;
plot([CutVal, CutVal], [1, MaxNum], 'Color', 'r');
hold off;
set(gca, 'YScale', 'log')
return
