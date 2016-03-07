function varargout = ViewStack(varargin)
% VIEWSTACK M-file for ViewStack.fig
%      VIEWSTACK, by itself, creates a new VIEWSTACK or raises the existing
%      singleton*.
%
%      H = VIEWSTACK returns the handle to a new VIEWSTACK or the handle to
%      the existing singleton*.
%
%      VIEWSTACK('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in VIEWSTACK.M with the given input arguments.
%
%      VIEWSTACK('Property','Value',...) creates a new VIEWSTACK or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ViewStack_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ViewStack_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ViewStack

% Last Modified by GUIDE v2.5 31-May-2010 10:02:36

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ViewStack_OpeningFcn, ...
                   'gui_OutputFcn',  @ViewStack_OutputFcn, ...
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
function showSlice(handles)
lastViewDim = get(handles.DimensionPanel, 'UserData');
saveViewStatePre(handles, lastViewDim);

[slice, dimStr, sliceNum, viewState, numLevels] = getViewSlice(handles);

delete(get(handles.ProjAxes, 'children'));
axes(handles.ProjAxes); %#ok<MAXES>
image(viewState.x, viewState.y, slice);
if size(slice, 3) == 1
  colormap(gray(numLevels));
end
axis image;
ylim(viewState.ylim);
xlim(viewState.xlim);
pan on;
set(handles.DimensionPanel, 'UserData', dimStr);
saveViewStatePost(handles, dimStr, sliceNum);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [slice, dimStr, varargout] = getViewSlice(handles, useStackColor)
sliceNum = get(handles.SliceSlider, 'Value');
dimStr = get(get(handles.DimensionPanel, 'SelectedObject'), 'String');
buttonName = [dimStr, 'Button'];
viewState = get(handles.(buttonName), 'UserData');

stackList = get(handles.SliceSlider, 'UserData');
metadata = stackList(1).metadata;
logical = metadata.logical;
numChan = length(stackList);
switch dimStr
  case 'X', sliceSize = [logical(3), logical(2), 3];
  case 'Y', sliceSize = [logical(3), logical(1), 3];
  case 'Z', sliceSize = [logical(2), logical(1), 3];
end
sliceFunc = ['getSlice', dimStr];

if nargin < 2
  useStackColor = true;
end

if useStackColor
  slice = zeros(sliceSize, metadata.intTypeName);
  for n = 1:numChan
    metadata = stackList(n).metadata;
    slice_n = stackList(n).(sliceFunc)(sliceNum);
    for m = 1:3
      slice(:,:,m) = slice(:,:,m) + metadata.color(m) * slice_n;
    end    
  end
else
  switch numChan
    case 1, slice = stackList.(sliceFunc)(sliceNum);
    case 2
      % if two channels, draw in magenta, green
      slice = zeros(sliceSize, metadata.intTypeName);
      slice(:,:,1) = stackList(1).(sliceFunc)(sliceNum);
      slice(:,:,2) = stackList(2).(sliceFunc)(sliceNum);
      slice(:,:,3) = slice(:,:,1);
    case 3
      % three channels, draw in red, green, blue
      slice = zeros(sliceSize, metadata.intTypeName);
      slice(:,:,1) = stackList(1).(sliceFunc)(sliceNum);
      slice(:,:,2) = stackList(2).(sliceFunc)(sliceNum);
      slice(:,:,3) = stackList(3).(sliceFunc)(sliceNum);
  end
end

% adjust brightness in accordance with Min/Max brightness settings
imMaxVal = metadata.numVoxelLevels - 1;
minVal = str2double(get(handles.MinBrightEdit, 'String'));
maxVal = str2double(get(handles.MaxBrightEdit, 'String'));
if maxVal < imMaxVal || minVal > 0
  slice = metadata.handles.intType(...
    (slice - minVal) * (imMaxVal / (maxVal - minVal)));
end

if metadata.numBits == 12
  % 12 bit images need to be multiplied by 16
  slice(:) = slice(:) * 16;
end

if nargout > 2
  varargout = {sliceNum, viewState, imMaxVal + 1};
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function newSlice = resizeSlice(slice, sliceSize)
[ySize, xSize, numColors] = size(slice);

diff = xSize * sliceSize(2) - ySize * sliceSize(1);
if diff > 0
  newY = round(xSize * sliceSize(2) / sliceSize(1));
  newSlice = zeros(newY, xSize, numColors);
  for n = 1:numColors
    newSlice(:,:,n) = interp2(slice(:,:,n), ...
			      1:xSize, (1:newY)' * (ySize / newY), ...
			      '*nearest', 0);
  end
elseif diff < 0
  newX = round(ySize * sliceSize(1) / sliceSize(2));
  newSlice = zeros(ySize, newX, numColors);
  for n = 1:numColors
    newSlice(:,:,n) = interp2(slice(:,:,n), ...
			      (1:newX) * (xSize / newX), (1:ySize)', ...
			      '*nearest', 0);
  end
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function saveViewStatePre(handles, lastViewDim)
if isempty(lastViewDim)
  return
end
buttonName = [lastViewDim, 'Button'];
viewState = get(handles.(buttonName), 'UserData');
viewState.xlim = xlim;
viewState.ylim = ylim;
set(handles.(buttonName), 'UserData', viewState);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function saveViewStatePost(handles, viewDim, sliceNum)
buttonName = [viewDim, 'Button'];
viewState = get(handles.(buttonName), 'UserData');
viewState.sliceNum = sliceNum;
set(handles.(buttonName), 'UserData', viewState);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function adjustZoom(handles)
yTemp = ylim;
xTemp = xlim;
dimStr = get(get(handles.DimensionPanel, 'SelectedObject'), 'String');
buttonStr = [dimStr, 'Button'];
viewState = get(handles.(buttonStr), 'UserData');
x = viewState.x;
y = viewState.y;

set(handles.ProjAxes, 'Units', 'pixels');
position = get(handles.ProjAxes, 'Position');
set(handles.ProjAxes, 'Units', 'characters');

axesWidthToHeight = position(3) / position(4);
width = xTemp(2) - xTemp(1);
height = yTemp(2) - yTemp(1);
imageWidthToHeight = width / height;
ratio = axesWidthToHeight / imageWidthToHeight;
if ratio > 1
  width = width * ratio;
else
  height = height / ratio;
end

if width > x(2)
  width = x(2);
end
if height > y(2)
  height = y(2);
end

xMid = (xTemp(1) + xTemp(2)) / 2;
xTemp = [xMid - width/2, xMid + width/2];
yMid = (yTemp(1) + yTemp(2)) / 2;
yTemp = [yMid - height/2, yMid + height/2];

if xTemp(1) < 0
  xTemp = [0, width];
elseif xTemp(2) > x(2)
  xTemp = [x(2) - width, x(2)];
end
if yTemp(1) < 0
  yTemp = [0, height];
elseif yTemp(2) > y(2)
  yTemp = [y(2) - height, y(2)];
end

ylim(yTemp);
xlim(xTemp);
showSlice(handles);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function safeName = makeSafeVariableName(methodName)
safeName = methodName;
badCharInds = regexp(methodName, '\W');
safeName(badCharInds) = '_';
safeName(1) = lower(safeName(1));
return



       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       %  Beginning of guide-generated functions (open/create)   %
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

       

% --- Executes just before ViewStack is made visible.
function ViewStack_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to ViewStack (see VARARGIN)

% Choose default command line output for ViewStack
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes ViewStack wait for user response (see UIRESUME)
% uiwait(handles.figure1);

stackList = varargin{1};

saveFilePath = varargin{2};

set(handles.SliceSlider, 'UserData', stackList);
set(handles.SliceText, 'UserData', saveFilePath);

logical = stackList(1).metadata.logical;
num = logical(3);
set(handles.SliceSlider, 'Min', 1);
set(handles.SliceSlider, 'Max', num);
set(handles.SliceSlider, 'SliderStep', [1/(num-1), .1]);
set(handles.SliceSlider, 'Value', 1);

set(handles.SliceText, 'String', '1');

physical = stackList(1).metadata.physical * 1e6;
viewState.sliceNum = 1;
viewState.xlim = [0, physical(2)];
viewState.ylim = [0, physical(3)];
viewState.x = viewState.xlim;
viewState.y = viewState.ylim;
viewState.dimension = 1;
set(handles.XButton, 'UserData', viewState);
viewState.xlim(2) = physical(1);
viewState.x = viewState.xlim;
viewState.dimension = 2;
set(handles.YButton, 'UserData', viewState);
viewState.ylim(2) = physical(2);
viewState.y = viewState.ylim;
viewState.dimension = 3;
set(handles.ZButton, 'UserData', viewState);

origin = stackList(1).metadata.origin;
cropScaleStruct = struct(...
  'scaleVec', [1.0 1.0 1.0], ...
  'rangeX', [1 logical(1)], ...
  'rangeY', [1 logical(2)], ...
  'rangeZ', [1 logical(3)], ...
  'logical', logical, 'physical', physical, ...
  'origin', origin, ...
  'numBits', stackList(1).metadata.numBits, ...
  'downsampled', false, 'cropped', false, ...
  'saveStack', false);
set(handles.CropScaleButton, 'UserData', cropScaleStruct);
  
numVoxelLevels = stackList(1).metadata.numVoxelLevels;
set(handles.MaxBrightEdit, 'String', num2str(numVoxelLevels - 1))

numChan = length(stackList);
if numChan > 1
  % if more than one channel, 'UseColor' option is meaningless
  set(handles.UseColor, 'Enable', 'off')
else
  set(handles.UseColor, 'Enable', 'on')
end



figure1_ResizeFcn(hObject, eventdata, handles)
% use a timer to start the parallel environment.  Using the timer allows
%  the construction of confocal to continue while matlabpool starts up in
%  the background
t = timer('TimerFcn', @attachParallelCallback, ...
          'StartDelay', 0.1, ...
          'UserData', hObject);
start(t);
return



function attachParallelCallback(obj, event, string_arg)
% attach a ParallelBlock object to the UserData in confocal, guaranteeing
%  that the parallel environment is open as long as the confocal window is
%  open, and shutting it down when it's no longer required.
confocalObj = get(obj, 'UserData');
set(confocalObj, 'UserData', ParallelBlock());
return



% --- Outputs from this function are returned to the command line.
function varargout = ViewStack_OutputFcn(hObject, eventdata, handles) %#ok<*INUSL>
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



% --- Executes during object creation, after setting all properties.
function SliceSlider_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU,*INUSD>
% hObject    handle to SliceSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



% --- Executes during object creation, after setting all properties.
function SliceText_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to SliceText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function MinBrightEdit_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to MinBrightEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function MaxBrightEdit_CreateFcn(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to MaxBrightEdit (see GCBO)
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



% --- Executes on slider movement.
function SliceSlider_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to SliceSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
sliceNum = get(handles.SliceSlider, 'Value');
if sliceNum ~= round(sliceNum)
  sliceNum = round(sliceNum);
  set(handles.SliceSlider, 'Value', sliceNum)
end
set(handles.SliceText, 'String', num2str(sliceNum));
showSlice(handles);



function SliceText_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to SliceText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of SliceText as text
%        str2double(get(hObject,'String')) returns contents of SliceText as a double
sliceNum = str2double(get(hObject, 'String'));
if isnan(sliceNum)
  sliceNum = get(handles.SliceSlider, 'Value');
  set(hObject, 'String', num2str(sliceNum));
  return
elseif sliceNum ~= round(sliceNum)
  sliceNum = round(sliceNum);
  set(hObject, 'String', num2str(sliceNum))
end

maxSlice = get(handles.SliceSlider, 'Max');
if sliceNum < 1
  sliceNum = 1;
elseif sliceNum > maxSlice
  sliceNum = maxSlice;
end
set(handles.SliceSlider, 'Value', sliceNum);
showSlice(handles);



% --- Executes on button press in XButton, YButton, or ZButton.
function ProjectionButtons_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to XButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of XButton

stackList = get(handles.SliceSlider, 'UserData');
viewState = get(hObject, 'UserData');
num = stackList(1).metadata.logical(viewState.dimension);
set(handles.SliceSlider, 'Min', 1);
set(handles.SliceSlider, 'Max', num);
set(handles.SliceSlider, 'SliderStep', [1/(num-1), .1]);
set(handles.SliceSlider, 'Value', viewState.sliceNum);

% if we need to look at an 'X' or 'Y' projection, load stack into memory
%  (i.e. make a non-virtual stack)
dimStr = get(hObject, 'String');
if dimStr == 'X' || dimStr == 'Y'
  virtualChanged = false;
  
  for n = 1:length(stackList)
    if stackList(n).isVirtual
      %Set mouse pointer to indicate busy:
      set(gcbf,'Pointer','watch');
      drawnow;
      stackList(n).loadStackImage();
      virtualChanged = true;
    end
  end
  if virtualChanged
    set(handles.SliceSlider, 'UserData', stackList);
    %Set mouse pointer to indicate not busy
    set(gcbf,'Pointer','arrow');
    drawnow;
  end
end

showSlice(handles);



% --- Executes on button press in MakeProjections.
function MakeProjections_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to MakeProjections (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%Set mouse pointer to indicate busy:
set(gcbf,'Pointer','watch');
drawnow;

stackList = get(handles.SliceSlider, 'UserData');

styleStruct.method = ...
  get(get(handles.MethodPanel, 'SelectedObject'), 'String');
styleStruct.method = makeSafeVariableName(styleStruct.method);

styleStruct.numBits = 8;
styleStruct.useColor = (get(handles.UseColor, 'Value') == 1);
styleStruct.toneMap = (get(handles.ToneMap, 'Value') == 1);
styleStruct.enhanceBlue = (get(handles.EnhanceBlue, 'Value') == 1);
cropScaleStruct = get(handles.CropScaleButton, 'UserData');
styleStruct.xRange = cropScaleStruct.rangeX;
styleStruct.yRange = cropScaleStruct.rangeY;
styleStruct.zRange = cropScaleStruct.rangeZ;

% call routine to produce the projection
projections = ProjectStack(stackList, styleStruct);

dirName = uigetdir(get(handles.SliceText, 'UserData'), ...
		   'Save location for projections');
if ~ischar(dirName)
  dirName = uigetdir(get(handles.SliceText, 'UserData'), ...
		     'Save location for projections');
  if ~ischar(dirName)
    %Set mouse pointer to indicate not busy:
    set(gcbf,'Pointer','arrow');
    drawnow;
    return
  end
end

numChan = length(stackList);
if numChan > 1
  colorString = '';
elseif styleStruct.useColor
  colorString = 'Color';
else
  colorString = 'Gray';
end
if styleStruct.toneMap
  enhanceStr = 'ToneMap';
else
  enhanceStr = 'Normal';
end
if strcmp(styleStruct.method, 'standard_Deviation')
  projStyle = 'STD';
else
  projStyle = styleStruct.method;
  projStyle(1) = upper(projStyle(1));
end

%Save the projection along each dimension to a separate file.
for projAxis = 1:3
  switch projAxis
    case 1,
      projImage = projections.x;
      axisString = 'X';
    case 2,
      projImage = projections.y;
      axisString = 'Y';
    case 3,
      projImage = projections.z;
      axisString = 'Z';
    otherwise,
      %Set mouse pointer to indicate not busy:
      set(gcbf,'Pointer','arrow');
      drawnow;
      error('Invalid projection axis');
  end
  
  if size(projImage, 3) == 1
    maxImageVal = max(max(projImage));
    map = double(gray(maxImageVal + 1));
    colormap(map);
  end
  

  baseName = [colorString, projStyle, enhanceStr, axisString];
  saveName = [dirName, filesep, baseName, '.tif'];
  imwrite(projImage, saveName, 'tif', 'Compression', 'lzw');
end
%Set mouse pointer to indicate not busy:
set(gcbf,'Pointer','arrow');
drawnow;



% --- Executes on button press in SaveSlice.
function SaveSlice_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to SaveSlice (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

sliceNumStr = get(handles.SliceText, 'String');
[slice, dimStr] = getViewSlice(handles);

stackList = get(handles.SliceSlider, 'UserData');
physical = stackList(1).metadata.physical * 1e6;
switch dimStr
 case 'X', sliceSize = physical([2,3]);
 case 'Y', sliceSize = physical([1,3]);
 case 'Z', sliceSize = physical([1,2]);
end

slice = resizeSlice(slice, sliceSize);

fileName = sprintf('Slice_%s_%s.tif', dimStr, sliceNumStr);

workingDir = pwd;
cd(get(handles.SliceText, 'UserData'));
[imageFile, imagePath, ~] ...
    = uiputfile('*.tif', 'Save slice image', fileName);
cd(workingDir);

if ischar(imageFile)
  saveName = [imagePath, filesep, imageFile];
  imwrite(slice, saveName, 'tif', 'Compression', 'none');
end



% --- Executes on button press in ZoomInButton.
function ZoomInButton_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to ZoomInButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
axis(axis / 2);
adjustZoom(handles);



% --- Executes on button press in ZoomOutButton.
function ZoomOutButton_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to ZoomOutButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
axis(axis * 2);
adjustZoom(handles);



function MinBrightEdit_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to MinBrightEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of MinBrightEdit as text
%        str2double(get(hObject,'String')) returns contents of MinBrightEdit as a double
val = str2double(get(hObject, 'String'));
if isnan(val)
  val = get(hObject, 'UserData');
  set(hObject, 'String', num2str(val));
else
  set(hObject, 'UserData', val);
  showSlice(handles);
end



function MaxBrightEdit_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to MaxBrightEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of MaxBrightEdit as text
%        str2double(get(hObject,'String')) returns contents of MaxBrightEdit as a double
val = str2double(get(hObject, 'String'));
if isnan(val)
  val = get(hObject, 'UserData');
  set(hObject, 'String', num2str(val));
else
  set(hObject, 'UserData', val);
  showSlice(handles);
end



% --- Executes on button press in CropScaleButton.
function CropScaleButton_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to CropScaleButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
stackList = get(handles.SliceSlider, 'UserData');
saveFilePath = get(handles.SliceText, 'UserData');

cropScaleStruct = get(hObject, 'UserData');

h = CropScale(cropScaleStruct);
uiwait(h);
try
  cropScaleStruct = get(h, 'UserData');
  close(h);
  set(hObject, 'UserData', cropScaleStruct)
catch weirdErr
  % This shouldn't happen.  Not sure why I don't rethrow(weirdErr)
  fprintf(2, 'Couldn''t get data from crop/scale.\n');
  fprintf(2, weirdErr.message);
  return
end

% Determine if stack needs to be saved
if ~cropScaleStruct.saveStack || ...
    ~(cropScaleStruct.downSampled || cropScaleStruct.cropped)
  return
end

workingDir = pwd;
cd(saveFilePath);
[fileName, pathName] = uiputfile('.lei_mat', 'Choose Save Location');
if ~ischar(fileName)
  return
end
if ~strcmp(fileName((end-7):end), '.lei_mat')
   fileName = [fileName, '.lei_mat']; 
end
cd(workingDir);
stackFileName = [pathName, fileName];

%Set mouse pointer to indicate busy:
set(gcbf,'Pointer','watch');
drawnow;

oldStackList = stackList;
stackList = DownSampleStack(oldStackList, stackFileName, cropScaleStruct);

set(handles.SliceSlider, 'UserData', stackList);
clear oldStackList;

logical = stackList(1).metadata.logical;
physical = stackList(1).metadata.physical;
origin = stackList(1).metadata.origin;
num = logical(3);
oldNum = get(handles.SliceSlider, 'Max');
newSliderVal = round(get(handles.SliceSlider, 'Value') * num/ oldNum);
set(handles.SliceSlider, 'Min', 1);
set(handles.SliceSlider, 'Max', num);
set(handles.SliceSlider, 'SliderStep', [1/(num-1), .1]);
set(handles.SliceSlider, 'Value', newSliderVal);
set(handles.SliceText, 'String', num2str(newSliderVal));

cropScaleStruct.scaleVec(:) = 1.0;
cropScaleStruct.rangeX = [1 logical(1)];
cropScaleStruct.rangeY = [1 logical(2)];
cropScaleStruct.rangeZ = [1 logical(3)];
cropScaleStruct.logical = logical;
cropScaleStruct.physical = physical;
cropScaleStruct.origin = origin;
cropScaleStruct.downSampled = false;
cropScaleStruct.cropped = false;
cropScaleStruct.saveStack = false;
set(handles.CropScaleButton, 'UserData', cropScaleStruct);

showSlice(handles);

%Set mouse pointer to indicate not busy:
set(gcbf,'Pointer','arrow');
drawnow;
return



% --- Executes on button press in ShowHistButton.
function ShowHistButton_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to ShowHistButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
stackList = get(handles.SliceSlider, 'UserData');
numStacks = length(stackList);
NamedFigure('Intensity Histogram')
clf
maxHist = max(stackList(1).metadata.voxelStats.hist);
if numStacks == 1
  h = axes('Position', [0.0 0.0 1.0 1.0]);
  
  hist = stackList(1).metadata.voxelStats.hist;
  maxBin = length(hist) - 1;
  
  bar(h, 0:maxBin, hist, 'k')
  
  set(h, 'XLimMode', 'manual')
  set(h, 'XLim', [0 maxBin])
  set(h, 'YLimMode', 'manual')
  set(h, 'YLim', [1 maxHist])
  set(h, 'YScale', 'log')
else
  for n = 2:numStacks
    tempHist = max(stackList(n).metadata.voxelStats.hist);
    if tempHist > maxHist
      maxHist = tempHist;
    end
  end
  axes('Position', [0.0 0.0 1.0 1.0], 'Visible', 'off');
  xPad = 0.075;
  yPad = 0.075;
  ySpace = 0.0;
  width = 1.0 - 1.5 * xPad;
  height = (1.0 - 1.5 * yPad - 2 * ySpace) / numStacks;
  x = xPad;
  colors = {'r', 'g', 'b'};
  for n = 1:numStacks
    y = yPad + (height + ySpace) * (numStacks - n);
    h = axes('Position', [x, y, width, height]);
    
    hist = stackList(1).metadata.voxelStats.hist;
    maxBin = length(hist) - 1;
    
    bar(h, 0:maxBin, hist, colors{n})
    
    set(h, 'XLimMode', 'manual')
    set(h, 'XLim', [0 maxBin])
    if n < numStacks
      set(h, 'xTickLabel', {})
      set(h, 'yTickLabel', {})
    end
    set(h, 'YLimMode', 'manual')
    set(h, 'YLim', [1 maxHist])
    set(h, 'YScale', 'log')
  end
end



% --- Executes when figure1 is resized.
function figure1_ResizeFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isempty(handles)
  return
end

controlPos = get(handles.ControlPanel, 'Position');
controlWidth = controlPos(3);
controlHeight = controlPos(4);

xPad = 5;
margin = 1;

sliderPos = get(handles.SliceSlider, 'Position');
sliderWidth = sliderPos(3);
axisPadX = 50;
axisPadY = 20;

minHeight = 2 * margin + controlHeight;

minWidth = controlWidth + xPad + sliderWidth + axisPadX + 2 * margin + 50;

figureSize = get(hObject, 'Position');
width = figureSize(3);
height = figureSize(4);
changeSize = false;
if width < minWidth
  width = minWidth;
  figureSize(3) = minWidth;
  changeSize = true;
end
if height < minHeight
  height = minHeight;
  figureSize(4) = minHeight;
  changeSize = true;
end
if changeSize
  set(hObject, 'Position', figureSize);
  movegui(hObject, 'onscreen')
end

y = height - margin - controlHeight;
set(handles.ControlPanel, 'Position', ...
  [margin, y, controlWidth, controlHeight]);

x = margin + controlWidth + xPad;
set(handles.SliceSlider, 'Position', ...
  [x, margin, sliderWidth, height - 2*margin]);

x = x + axisPadX;
set(handles.ProjAxes, 'Position', ...
  [x, axisPadY, width - x - xPad, height - axisPadY - margin]);

showSlice(handles);
