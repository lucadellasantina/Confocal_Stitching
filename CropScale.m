function varargout = CropScale(varargin)
% CROPSCALE M-file for CropScale.fig
%      CROPSCALE, by itself, creates a new CROPSCALE or raises the existing
%      singleton*.
%
%      H = CROPSCALE returns the handle to a new CROPSCALE or the handle to
%      the existing singleton*.
%
%      CROPSCALE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CROPSCALE.M with the given input arguments.
%
%      CROPSCALE('Property','Value',...) creates a new CROPSCALE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before CropScale_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to CropScale_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help CropScale

% Last Modified by GUIDE v2.5 15-Jun-2010 09:51:53

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CropScale_OpeningFcn, ...
                   'gui_OutputFcn',  @CropScale_OutputFcn, ...
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


% --- Executes just before CropScale is made visible.
function CropScale_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<INUSL>
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to CropScale (see VARARGIN)

% Choose default command line output for CropScale
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes CropScale wait for user response (see UIRESUME)
% uiwait(handles.figure1);

set(hObject, 'Name', 'Crop/Scale')
cropScaleStruct = varargin{1};
set(handles.figure1, 'UserData', cropScaleStruct);
set(handles.RadioMicrons, 'Value', 1)
resetFields(handles);

% --- Outputs from this function are returned to the command line.
function varargout = CropScale_OutputFcn(hObject, eventdata, handles)  %#ok<INUSL>
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
     % Beginning of helper functions (not directly event-driven)  %
     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function resetFields(handles)
cropScaleStruct = get(handles.figure1, 'UserData');

minX = cropScaleStruct.rangeX(1); maxX = cropScaleStruct.rangeX(2);
minY = cropScaleStruct.rangeY(1); maxY = cropScaleStruct.rangeY(2);
minZ = cropScaleStruct.rangeZ(1); maxZ = cropScaleStruct.rangeZ(2);

voxSize = cropScaleStruct.physical ./ cropScaleStruct.logical;
origin = cropScaleStruct.origin;
set(handles.editMinX, 'UserData', ...
		  struct('origin', origin(1), 'voxSize', voxSize(1), ...
			 'value', minX, 'min', 1, ...
			 'hMax', handles.editMaxX))
set(handles.editMinY, 'UserData', ...
		  struct('origin', origin(2), 'voxSize', voxSize(2), ...
			 'value', minY, 'min', 1, ...
			 'hMax', handles.editMaxY))
set(handles.editMinZ, 'UserData', ...
		  struct('origin', origin(3), 'voxSize', voxSize(3), ...
			 'value', minZ, 'min', 1, ...
			 'hMax', handles.editMaxZ))
set(handles.editMaxX, 'UserData', ...
		  struct('origin', origin(1), 'voxSize', voxSize(1), ...
			 'value', maxX, 'max', cropScaleStruct.logical(1), ...
			 'hMin', handles.editMinX))
set(handles.editMaxY, 'UserData', ...
		  struct('origin', origin(2), 'voxSize', voxSize(2), ...
			 'value', maxY, 'max', cropScaleStruct.logical(2), ...
			 'hMin', handles.editMinY))
set(handles.editMaxZ, 'UserData', ...
		  struct('origin', origin(3), 'voxSize', voxSize(3), ...
			 'value', maxZ, 'max', cropScaleStruct.logical(3), ...
			 'hMin', handles.editMinZ))

set(handles.editNumBits, 'UserData', cropScaleStruct.numBits);
     
if get(handles.RadioMicrons, 'Value')
  minXStr = num2str(origin(1) + voxSize(1) * (minX - 1));
  maxXStr = num2str(origin(1) + voxSize(1) * maxX);
  minYStr = num2str(origin(2) + voxSize(2) * (minY - 1));
  maxYStr = num2str(origin(2) + voxSize(2) * maxY);
  minZStr = num2str(origin(3) + voxSize(3) * (minZ - 1));
  maxZStr = num2str(origin(3) + voxSize(3) * maxZ);
else
  minXStr = num2str(minX); maxXStr = num2str(maxX);
  minYStr = num2str(minY); maxYStr = num2str(maxY);
  minZStr = num2str(minZ); maxZStr = num2str(maxZ);
end

set(handles.editMinX, 'String', minXStr)
set(handles.editMinY, 'String', minYStr)
set(handles.editMinZ, 'String', minZStr)
set(handles.editMaxX, 'String', maxXStr)
set(handles.editMaxY, 'String', maxYStr)
set(handles.editMaxZ, 'String', maxZStr)
set(handles.editXSize, 'String', '1.0')
set(handles.editYSize, 'String', '1.0')
set(handles.editZSize, 'String', '1.0')
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function toggleEditStyle(hObject, handles)
dataStruct = get(hObject, 'UserData');
pixels = dataStruct.value;
isMin = StringCheck(get(hObject, 'tag'), 'Min');

if get(handles.RadioMicrons, 'Value')
  %switch from pixels to microns
  editStr = num2str(...
      dataStruct.origin + (pixels - isMin) * dataStruct.voxSize);
else
  %switch from microns to pixels
  editStr = num2str(pixels);
end
set(hObject, 'String', editStr)
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateEdit(hObject, handles)
editVal = str2double(get(hObject, 'String'));
dataStruct = get(hObject, 'UserData');
isMin = StringCheck(get(hObject, 'tag'), 'Min');
if isMin
  maxStruct = get(dataStruct.hMax, 'UserData');
  maxVal = maxStruct.value;
  minVal = dataStruct.min;
else
  minStruct = get(dataStruct.hMin, 'UserData');
  minVal = minStruct.value;
  maxVal = dataStruct.max;
end

if get(handles.RadioMicrons, 'Value')
  editVal = isMin + (editVal - dataStruct.origin) / dataStruct.voxSize;
end

newPix = round(editVal);
if newPix < minVal
  newPix = minVal;
elseif newPix > maxVal
  newPix = maxVal;
end
dataStruct.value = newPix;
set(hObject, 'UserData', dataStruct);

if get(handles.RadioMicrons, 'Value')
  editVal = dataStruct.origin + (newPix - isMin) * dataStruct.voxSize;
else
  editVal = newPix;
end

set(hObject, 'String', num2str(editVal));
return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function value = getEditValue(hObject)
dataStruct = get(hObject, 'UserData');
value = dataStruct.value;
return

       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       %  Beginning of guide-generated functions (open/create)   %
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Executes during object creation, after setting all properties.
function editXSize_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editXSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editYSize_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editYSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editZSize_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editZSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editMinX_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editMinX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editMinY_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editMinY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editMaxX_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editMaxX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editMaxY_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editMaxY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editMinZ_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editMinZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editMaxZ_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editMaxZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editNumBits_CreateFcn(hObject, eventdata, handles) %#ok<INUSD,DEFNU>
% hObject    handle to editNumBits (see GCBO)
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
       

% --- Executes on button press in OKButton.
function OKButton_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to OKButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
cropScaleStruct = get(handles.figure1, 'UserData');

scaleVec = [str2double(get(handles.editXSize, 'String')), ...
	    str2double(get(handles.editYSize, 'String')), ...
	    str2double(get(handles.editZSize, 'String'))];
rangeX = [getEditValue(handles.editMinX), ...
	  getEditValue(handles.editMaxX)];
rangeY = [getEditValue(handles.editMinY), ...
	  getEditValue(handles.editMaxY)];
rangeZ = [getEditValue(handles.editMinZ), ...
	  getEditValue(handles.editMaxZ)];
  
numBits = str2double(get(handles.editNumBits, 'String'));

downSampled = sum(scaleVec == 1) ~= 3;
cropped = rangeX(1) > 1 || rangeX(2) < cropScaleStruct.logical(1) || ...
  rangeY(1) > 1 || rangeY(2) < cropScaleStruct.logical(2) || ...
  rangeZ(1) > 1 || rangeZ(2) < cropScaleStruct.logical(3);


cropScaleStruct.scaleVec = scaleVec;
cropScaleStruct.rangeX = rangeX;
cropScaleStruct.rangeY = rangeY;
cropScaleStruct.rangeZ = rangeZ;
cropScaleStruct.numBits = numBits;
cropScaleStruct.downSampled = downSampled;
cropScaleStruct.cropped = cropped;
cropScaleStruct.saveStack = false;
set(handles.figure1, 'UserData', cropScaleStruct);
uiresume(gcbf);

% --- Executes on button press in SaveStackButton.
function SaveStackButton_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to SaveStackButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
cropScaleStruct = get(handles.figure1, 'UserData');

scaleVec = [str2double(get(handles.editXSize, 'String')), ...
	    str2double(get(handles.editYSize, 'String')), ...
	    str2double(get(handles.editZSize, 'String'))];
rangeX = [getEditValue(handles.editMinX), ...
	  getEditValue(handles.editMaxX)];
rangeY = [getEditValue(handles.editMinY), ...
	  getEditValue(handles.editMaxY)];
rangeZ = [getEditValue(handles.editMinZ), ...
	  getEditValue(handles.editMaxZ)];

numBits = str2double(get(handles.editNumBits, 'String'));

downSampled = sum(scaleVec == 1) ~= 3;
cropped = rangeX(1) > 1 || rangeX(2) < cropScaleStruct.logical(1) || ...
  rangeY(1) > 1 || rangeY(2) < cropScaleStruct.logical(2) || ...
  rangeZ(1) > 1 || rangeZ(2) < cropScaleStruct.logical(3);

cropScaleStruct.scaleVec = scaleVec;
cropScaleStruct.rangeX = rangeX;
cropScaleStruct.rangeY = rangeY;
cropScaleStruct.rangeZ = rangeZ;
cropScaleStruct.numBits = numBits;
cropScaleStruct.downSampled = downSampled;
cropScaleStruct.cropped = cropped;
cropScaleStruct.saveStack = true;
set(handles.figure1, 'UserData', cropScaleStruct);
uiresume(gcbf);

% --- Executes on button press in CancelButton.
function CancelButton_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to CancelButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%This isn't necessary, just leaving the original data alone cancels:
%set(handles.figure1, 'UserData', []);
uiresume(gcbf);


function editXSize_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editXSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editXSize as text
%        str2double(get(hObject,'String')) returns contents of editXSize as a double
scale = str2double(get(hObject, 'String'));
if scale < 1.0
  scale = 1.0;
  set(hObject, 'String', num2str(scale))
end

function editYSize_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editYSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editYSize as text
%        str2double(get(hObject,'String')) returns contents of
%        editYSize as a double
scale = str2double(get(hObject, 'String'));
if scale < 1.0
  scale = 1.0;
  set(hObject, 'String', num2str(scale))
end

function editZSize_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSD>
% hObject    handle to editZSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editZSize as text
%        str2double(get(hObject,'String')) returns contents of
%        editZSize as a double
scale = str2double(get(hObject, 'String'));
if scale < 1.0
  scale = 1.0;
  set(hObject, 'String', num2str(scale))
end


% --- Executes on button press in ResetButton.
function ResetButton_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to ResetButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
resetFields(handles);


function editMinX_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to editMinX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editMinX as text
%        str2double(get(hObject,'String')) returns contents of editMinX as a double
updateEdit(hObject, handles);

function editMinY_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to editMinY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editMinY as text
%        str2double(get(hObject,'String')) returns contents of editMinY as a double
updateEdit(hObject, handles);

function editMaxX_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to editMaxX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editMaxX as text
%        str2double(get(hObject,'String')) returns contents of editMaxX as a double
updateEdit(hObject, handles);

function editMaxY_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to editMaxY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editMaxY as text
%        str2double(get(hObject,'String')) returns contents of editMaxY as a double
updateEdit(hObject, handles);

function editMaxZ_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to editMaxZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editMaxZ as text
%        str2double(get(hObject,'String')) returns contents of editMaxZ as a double
updateEdit(hObject, handles);

function editMinZ_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to editMinZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editMinZ as text
%        str2double(get(hObject,'String')) returns contents of editMinZ as a double
updateEdit(hObject, handles);

function editNumBits_Callback(hObject, eventdata, handles) %#ok<INUSD,DEFNU>
% hObject    handle to editNumBits (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editNumBits as text
%        str2double(get(hObject,'String')) returns contents of editNumBits as a double
numBits = str2double(get(hObject, 'String'));
roundNumBits = max(8, 4 * round(numBits / 4));
if numBits ~= roundNumBits
  set(hObject, 'String', sprintf('%d', roundNumBits))
end


% --- Executes on button press in RadioMicrons.
function RadioMicrons_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to RadioMicrons (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of RadioMicrons
set(handles.RadioPixels, 'Value', 0)
set(hObject, 'Value', 1)
toggleEditStyle(handles.editMinX, handles);
toggleEditStyle(handles.editMinY, handles);
toggleEditStyle(handles.editMinZ, handles);
toggleEditStyle(handles.editMaxX, handles);
toggleEditStyle(handles.editMaxY, handles);
toggleEditStyle(handles.editMaxZ, handles);

% --- Executes on button press in RadioPixels.
function RadioPixels_Callback(hObject, eventdata, handles) %#ok<DEFNU,INUSL>
% hObject    handle to RadioPixels (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of RadioPixels
set(handles.RadioMicrons, 'Value', 0)
set(hObject, 'Value', 1)
toggleEditStyle(handles.editMinX, handles);
toggleEditStyle(handles.editMinY, handles);
toggleEditStyle(handles.editMinZ, handles);
toggleEditStyle(handles.editMaxX, handles);
toggleEditStyle(handles.editMaxY, handles);
toggleEditStyle(handles.editMaxZ, handles);
