function varargout = ConfocalColorChooser(varargin)
% CONFOCALCOLORCHOOSER M-file for ConfocalColorChooser.fig
%      CONFOCALCOLORCHOOSER, by itself, creates a new CONFOCALCOLORCHOOSER or raises the existing
%      singleton*.
%
%      H = CONFOCALCOLORCHOOSER returns the handle to a new CONFOCALCOLORCHOOSER or the handle to
%      the existing singleton*.
%
%      CONFOCALCOLORCHOOSER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CONFOCALCOLORCHOOSER.M with the given input arguments.
%
%      CONFOCALCOLORCHOOSER('Property','Value',...) creates a new CONFOCALCOLORCHOOSER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ConfocalColorChooser_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ConfocalColorChooser_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ConfocalColorChooser

% Last Modified by GUIDE v2.5 18-Jun-2010 10:34:56

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ConfocalColorChooser_OpeningFcn, ...
                   'gui_OutputFcn',  @ConfocalColorChooser_OutputFcn, ...
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

     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
     % Beginning of helper functions (not directly event-driven)  %
     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editCallback(hObject, ~, handles, dimNum)
colorStr = get(hObject, 'String');
color = get(handles.buttonOK, 'UserData');
colorNum = str2double(colorStr);
if isnan(colorNum) || colorNum < 0
  colorNum = color(dimNum);
  colorStr = num2str(colorNum);
  set(hObject, 'String', colorStr);
else
  color(dimNum) = colorNum;
  set(handles.buttonOK, 'UserData', color);
  drawColor(handles);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function drawColor(handles)
axes(handles.colorAxes); %#ok<MAXES>
delete(get(gca, 'children'));
color = get(handles.buttonOK, 'UserData');
color = color / max(color);

numLevels = 256;
position = get(handles.colorAxes, 'position');
ratio = position(3) / position(4);
width = round(numLevels * ratio);
colorMat = zeros(numLevels, width, 3, 'uint8');
color = permute(color, [1 3 2]);
for n = 1:numLevels
  color_n = color * n;
  colorLine = repmat(color_n, [1, width, 1]);
  colorMat(n,:,:) = colorLine;
end
image(colorMat);

return



       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       %  Beginning of guide-generated functions (open/create)   %
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



% --- Executes just before ConfocalColorChooser is made visible.
function ConfocalColorChooser_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<INUSL>
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ConfocalColorChooser (see VARARGIN)

% Choose default command line output for ConfocalColorChooser
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

color = ones(1,3);
origColor = ones(1,3);
if length(varargin) >= 1
  color = varargin{1};
  if length(varargin) >= 2
    origColor = varargin{2};
  end
end

% save the initial color in case of cancel:
set(hObject, 'UserData', color);

% save the original channel color in case reset is desired:
set(handles.buttonOriginal, 'BackgroundColor', origColor)
set(handles.buttonOriginal, 'ForegroundColor', 1 - origColor)

% set the current color to the initial color:
set(handles.buttonOK, 'UserData', color)
set(handles.editRed, 'String', num2str(color(1)))
set(handles.editGreen, 'String', num2str(color(2)))
set(handles.editBlue, 'String', num2str(color(3)))

% draw the initial color
drawColor(handles)
% UIWAIT makes ConfocalColorChooser wait for user response (see UIRESUME)
% uiwait(handles.ConfocalColorChooser);



% --- Outputs from this function are returned to the command line.
function varargout = ConfocalColorChooser_OutputFcn(hObject, eventdata, handles)  %#ok<INUSL>
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



% --- Executes during object creation, after setting all properties.
function editRed_CreateFcn(hObject, eventdata, handles) %#ok<INUSD,DEFNU>
% hObject    handle to editRed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function editGreen_CreateFcn(hObject, eventdata, handles) %#ok<INUSD,DEFNU>
% hObject    handle to editGreen (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function editBlue_CreateFcn(hObject, eventdata, handles) %#ok<INUSD,DEFNU>
% hObject    handle to editBlue (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       %                Beginning of Callbacks                   %
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



function editRed_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to editRed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editRed as text
%        str2double(get(hObject,'String')) returns contents of editRed as a double
editCallback(hObject, eventdata, handles, 1);



function editGreen_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to editGreen (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editGreen as text
%        str2double(get(hObject,'String')) returns contents of editGreen as a double
editCallback(hObject, eventdata, handles, 2);



function editBlue_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to editBlue (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editBlue as text
%        str2double(get(hObject,'String')) returns contents of editBlue as a double
editCallback(hObject, eventdata, handles, 3);



% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles) %#ok<INUSL,DEFNU>
% hObject    handle to buttonOK (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
color = get(hObject, 'UserData');
if any(color > 0)
  color = color / max(color);
  % only use the selected color if it's not black
  set(handles.ConfocalColorChooser, 'UserData', color);
end
uiresume(gcbf);



% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles) %#ok<INUSD,DEFNU>
% hObject    handle to buttonCancel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uiresume(gcbf);



% --- Executes on button press in buttonOriginal.
function buttonOriginal_Callback(hObject, eventdata, handles) %#ok<INUSL,DEFNU>
% hObject    handle to buttonOriginal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% set the current color to the original color:
color = get(hObject, 'BackgroundColor');
set(handles.buttonOK, 'UserData', color)
set(handles.editRed, 'String', num2str(color(1)))
set(handles.editGreen, 'String', num2str(color(2)))
set(handles.editBlue, 'String', num2str(color(3)))
drawColor(handles)