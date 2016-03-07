function varargout = confocal(varargin)
% CONFOCAL M-file for confocal.fig
%      CONFOCAL, by itself, creates a new CONFOCAL or raises the existing
%      singleton*.
%
%      H = CONFOCAL returns the handle to a new CONFOCAL or the handle to
%      the existing singleton*.
%
%      CONFOCAL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CONFOCAL.M with the given input arguments.
%
%      CONFOCAL('Property','Value',...) creates a new CONFOCAL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before confocal_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to confocal_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

%{
Where data is stored:
  MoveBox.String:  stackNames, cell array of stack names (may refer to more
                   than one stack if channels are grouped)
  MoveBox.UserData: stackList, list of loaded StackObj objects
  MoveBox.Value:  index of currently selected stack(s) name, from
                  MoveBox.String
  XBox.UserData:  origins, list of stack origins
  ChannelListBox.String:  stackNames, list of channels in stack file
  ChannelListBox.UserData: metadataList, list of MetadataObj objects from
                           stack file
  YBox.UserData:  basePath, convenient path selected by last loaded stack
                  file
  
  axesXY.UserData:  needsPlot, true/false
  axesZY.UserData:  needsPlot, true/false
  axesXZ.UserData:  needsPlot, true/false

  ControlPanel.UserData: channelColors, structure with fields:
            -channelList:  list of all unique channel numbers
            -ch_[channel num]: struct with fields
                -.color: 1 x 3 RGB triplets (0.0 - 1.0, at least one of
                           r, g, or b = 1.0)
                -.buttonHandle:  handle to button governing this channel
                                 number
%}
% Edit the above text to modify the response to help confocal

% Last Modified by GUIDE v2.5 10-Jun-2010 15:52:23

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                  'gui_OpeningFcn', @confocal_OpeningFcn, ...
                   'gui_OutputFcn',  @confocal_OutputFcn, ...
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
function setChannelList(handles)
% set the channel list box first
groupChannels = get(handles.GroupChannels, 'Value');
metadataList = get(handles.ChannelListBox, 'UserData');
if groupChannels
  stackNames = unique({metadataList.seriesName});
else
  stackNames = {metadataList.stackName};
end
% set the list of names in the box
set(handles.ChannelListBox, 'String', stackNames);
% set the selected index to be the first
set(handles.ChannelListBox,'Value', 1);

% correct list of stack names in MoveBox.String, to agree with the list of
% stacks in MoveBox.UserData
stackList = get(handles.MoveBox, 'UserData');

numStacks = length(stackList);
channelNames = {};
if groupChannels
  for n = 1:length(stackList)
    name_n = getFullStackName(handles, stackList(n));
    if ~ismember(name_n, channelNames)
      channelNames = [channelNames, {name_n}]; %#ok<AGROW>
    end
  end  
else
  channelNames = cell(1, numStacks);
  for n = 1:length(stackList)
    channelNames{n} = getFullStackName(handles, stackList(n));
  end
end

set(handles.MoveBox, 'String', channelNames)
set(handles.MoveBox, 'Value', length(channelNames))
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function proj = getSeriesProjection(stackList, stackInds, dimName, ...
                                    groupChannels, useStackColor)
% channelColors is optional, assigns an RGB color to each channel
if groupChannels
  if nargin < 5
    useStackColor = true;
  end
  metadata = stackList(stackInds(1)).metadata;
  
  if useStackColor
    numColors = 3;
  else
    numColors = 1;
    for n = 1:length(stackInds)
      numColors = max(numColors, ...
                      stackList(stackInds(n)).metadata.numChannels);
    end
  end
  switch dimName
    case 'x', projSize = [metadata.logical(3), metadata.logical(2), numColors];
    case 'y', projSize = [metadata.logical(3), metadata.logical(1), numColors];
    case 'z', projSize = [metadata.logical(2), metadata.logical(1), numColors];
  end
  proj = zeros(projSize, metadata.intTypeName);

  if useStackColor
     for n = 1:length(stackInds)
      metadata = stackList(stackInds(n)).metadata;
      for m = 1:3
        proj(:,:,m) = proj(:,:,m) + ...
          metadata.color(m) * metadata.projections.max.(dimName).image;
      end
    end
  else
    for n = 1:length(stackInds);
      metadata = stackList(stackInds(n)).metadata;
      colorInd = metadata.channelNum + 1;
      proj(:,:,colorInd) = metadata.projections.max.(dimName).image;
    end
  end
else
  proj = stackList(stackInds(1)).metadata.projections.max.(dimName).image;
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function fullName = getFullStackName(handles, stack)
if isa(stack, 'StackObj')
  metadata = stack.metadata;
else
  metadata = stack;
end
groupChannels = get(handles.GroupChannels, 'Value');
if groupChannels
  fullName = [metadata.seriesName, ' :: ', metadata.stackFileName];
else
  fullName = [metadata.stackName, ' :: ', metadata.stackFileName];
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function selectedList = getSelectedChannels(handles, selectedIndex)
if nargin < 2
  selectedIndex = get(handles.MoveBox,'Value');
end
groupChannels = get(handles.GroupChannels, 'Value');
if groupChannels
  stackList = get(handles.MoveBox, 'UserData');
  stackNames = get(handles.MoveBox, 'String');
  selectedName = stackNames{selectedIndex};

  selectedList = [];
  for n = 1:length(stackList)
    if strcmp(selectedName, getFullStackName(handles, stackList(n)))
      selectedList = [selectedList, n]; %#ok<AGROW>
    end
  end
else
  selectedList = selectedIndex;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotList = getPlotList(handles)
groupChannels = get(handles.GroupChannels, 'Value');
if groupChannels
  stackNames = get(handles.MoveBox, 'String');
  numGroups = length(stackNames);
  plotList = cell(1, numGroups);
  for n = 1:numGroups
    plotList{n} = getSelectedChannels(handles, n);
  end
else
  stackList = get(handles.MoveBox, 'UserData');
  plotList = num2cell(1:length(stackList));
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotStacks(handles)
stackList = get(handles.MoveBox, 'UserData');
if isempty(stackList)
  return
end
xyChanged = get(handles.axesXY, 'UserData');
zyChanged = get(handles.axesZY, 'UserData');
xzChanged = get(handles.axesXZ, 'UserData');
if ~xyChanged && ~zyChanged && ~zxChanged
  return
end

plotList = getPlotList(handles);

if xyChanged
  plotProj(handles, stackList, plotList, 'z')
end
if zyChanged
  plotProj(handles, stackList, plotList, 'x')
end
if xzChanged
  plotProj(handles, stackList, plotList, 'y')
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotProj(handles, stackList, plotList, projType)
switch projType
  case 'x', dimX = 3; dimY = 2; axesHandle = handles.axesZY;
  case 'y', dimX = 1; dimY = 3; axesHandle = handles.axesXZ;
  case 'z', dimX = 1; dimY = 2; axesHandle = handles.axesXY;
end    
if isempty(plotList)
  % nothing to draw, so clear the plot and return
  axes(axesHandle); %#ok<MAXES>
  delete(get(gca, 'children'));
  return
end

origins = get(handles.XBox, 'UserData');
groupChannels = get(handles.GroupChannels, 'Value');
drawAlpha = get(handles.Transparency, 'Value');

numPlot = length(plotList);
projList = cell(1, numPlot);
xRange = zeros(numPlot, 2);
yRange = zeros(numPlot, 2);
for n = 1:numPlot
  % get the stack indices that correspond to
  thisPlotInds = plotList{n};
  projList{n} = ...
    getSeriesProjection(stackList, thisPlotInds, projType, groupChannels);
  if projType == 'x'
    % the x projection is drawn transposed, so as to line up with the z
    % projection in the main gui
    projList{n} = permute(projList{n}, [2 1 3]);
  end
  
  origin = origins(thisPlotInds(1),:) * 1e6;
  physical = stackList(thisPlotInds(1)).metadata.physical * 1e6;
  xRange(n,:) = [origin(dimX), origin(dimX) + physical(dimX)];
  yRange(n,:) = [origin(dimY), origin(dimY) + physical(dimY)];
end

totalXRange = [min(xRange(:,1)), max(xRange(:,2))];
totalYRange = [min(yRange(:,1)), max(yRange(:,2))];

axes(axesHandle); %#ok<MAXES>
delete(get(gca, 'children'));
xlim(totalXRange);
ylim(totalYRange);
set(axesHandle, 'ydir', 'reverse', 'YTickMode', 'auto', ...
    'XTickMode', 'auto');

hold on
if drawAlpha
  % draw with transparency
  if ~groupChannels
    % draw transparent black and white
    % set the background white
    set(gca, 'Color', [1,1,1]);
    % make colormap where low values are white and high values black
    numVoxelLevels = stackList(1).metadata.numVoxelLevels;
    colormap(flipud(gray(numVoxelLevels)))
    % set transparency to be high for low values, low for high values
    alphamap(linspace(0, 1, numVoxelLevels));
    maxVal = stackList(1).metadata.handles.intType(numVoxelLevels - 1);
    for n = 1:length(projList)
      % draw a white rectangle with transparency determined by image value
      image(xRange(n,:), yRange(n,:), repmat(maxVal,size(projList{n})), ...
	          'AlphaData', projList{n},...
            'AlphaDataMapping', 'direct');
    end
  else
    % draw transparent color
    % set the background black
    set(gca, 'Color', [0,0,0]);
    
    % set transparency to be high for low values, low for high values
    numVoxelLevels = stackList(1).metadata.numVoxelLevels;
    numBits = stackList(1).metadata.numBits;
    alphamap(linspace(0, 1, numVoxelLevels));
    if numBits == 12
      scale = 16;  %Scale to allow projection to reach max value
                   % (otherwise goes to 2^12 instead of 2^16)
      for n = 1:length(projList)
        % set transparency to be the mean of the color values
        alphaIm = max(projList{n}, [], 3);
        % draw image with transparancy
        image(xRange(n,:), yRange(n,:), scale * projList{n}, ...
              'AlphaData', alphaIm, 'AlphaDataMapping', 'direct');
      end
    else
      for n = 1:length(projList)
        alphaIm = max(projList{n}, [], 3);
        image(xRange(n,:), yRange(n,:), projList{n}, ...
              'AlphaData', alphaIm, 'AlphaDataMapping', 'direct');
      end
    end
  end
else
  % draw opaquely
  if ~groupChannels
    % draw opaque black and white
    numVoxelLevels = stackList(1).metadata.numVoxelLevels;
    colormap(gray(numVoxelLevels))
  end
  % draw opaque color
  set(gca, 'Color', [1,1,1]);  
  
  numBits = stackList(1).metadata.numBits;
  if numBits == 12
    scale = 16;  %Scale to allow projection to reach max value
                 % (otherwise goes to 2^12 instead of 2^16)
    for n = 1:length(projList)
      image(xRange(n,:), yRange(n,:), scale * projList{n});
    end    
  else
    for n = 1:length(projList)
      image(xRange(n,:), yRange(n,:), projList{n});
    end
  end
end

% depending on the projection dimension, adjust ticks on plot
switch projType
  case 'z', set(axesHandle, 'XTick', [])
  case 'x'
    cushion = 0.1;
    set(axesHandle, 'YTick', []);
    xRange = xlim;
    xTick = get(axesHandle, 'XTick');
    if (xTick(1) - xRange(1)) / diff(xRange) < cushion
      xTick = xTick(2:end);
    end
    if (xRange(2) - xTick(end)) / diff(xRange) < cushion
      xTick = xTick(1:(end-1));
    end
    set(axesHandle, 'XTick', xTick);
  case 'y'
end
hold off

% record that the projection has been updated
set(axesHandle, 'UserData', false);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function clearPlot(axesHandle)
cla(axesHandle)
set(axesHandle, 'XTick', [])
set(axesHandle, 'YTick', [])
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateChannelColors(handles, addMetadata)
% Update the channel colors of the newly added channels
channelColors = get(handles.ControlPanel, 'UserData');
channelList = channelColors.channelList;
for n = 1:length(addMetadata)
  if ismember(addMetadata(n).channelNum, channelList)
    fieldName = sprintf('ch_%d', addMetadata(n).channelNum);
    assignColor = channelColors.(fieldName).color;
    if any(abs(addMetadata(n).color - assignColor) > 1e-6)
      addMetadata(n).color = assignColor;
      addMetadata(n).save();
    end
  end
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function createChannelColorButtons(handles)
stackList = get(handles.MoveBox, 'UserData');
if isempty(stackList)
  metadataList = [];
  channelList = [];
else
  metadataList = [stackList.metadata];
  channelList = unique([metadataList.channelNum]);
end

channelColors = get(handles.ControlPanel, 'UserData');
oldChannelList = channelColors.channelList;

newChannels = setdiff(channelList, oldChannelList);
removedChannels = setdiff(oldChannelList, channelList);
if ~isempty(newChannels) || ~isempty(removedChannels)
  % remove any old channel buttons
  for n = 1:length(oldChannelList)
    fieldName = sprintf('ch_%d', oldChannelList(n));
    buttonHandle = channelColors.(fieldName).buttonHandle;
    children = get(handles.MoveBox, 'children');
    children = setdiff(children, buttonHandle);
    set(handles.MoveBox, 'children', children);
    delete(buttonHandle);
    channelColors = rmfield(channelColors, fieldName);
  end
  % next draw in all the channel buttons
  channelColors.channelList = channelList;
  for n = 1:length(channelList)
    channelNum = channelList(n);
    for m = 1:length(metadataList)
      if metadataList(m).channelNum == channelNum
        color = metadataList(m).color;
        break
      end
    end
    
    % button parameters:
    parent = handles.ControlPanel;
    width = 20;
    height = 20;
    x = 100 + width * (n - 1);
    y = 185 - height;
    buttonPos = [x, y, width, height];
    buttonString = num2str(channelNum);
    buttonCallback = ...
      @(hObj, events) colorButtonPress(hObj, channelNum, handles);
    
    % create the button
    buttonHandle = uicontrol(parent, ...
      'style', 'pushbutton', ...
      'units', 'pixels', ...
      'Position', buttonPos, ...
      'String', buttonString, ...
      'CallBack', buttonCallback, ...
      'BackgroundColor', color, ...
      'ForegroundColor', 1 - color);
    
    % save the information into channelColors
    fieldName = sprintf('ch_%d', channelNum);
    channelColors.(fieldName) = ...
      struct('color', color, 'buttonHandle', buttonHandle);
  end
  
  % save the channelColors struct to ControlPanel.UserData
  set(handles.ControlPanel, 'UserData', channelColors);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function colorButtonPress(hObj, channelNum, handles)

% get some information first
stackList = get(handles.MoveBox, 'UserData');
metadataList = [stackList.metadata];
for n = 1:length(metadataList)
  if metadataList(n).channelNum == channelNum
    % get the original color for this channel
    origColor = GetChannelColor(metadataList(n));
    break
  end
end
% get the current color for this channel
color = get(hObj, 'BackgroundColor');

h = ConfocalColorChooser(color, origColor);
uiwait(h);
color = get(h, 'UserData');
close(h)

set(hObj, 'BackgroundColor', color)
set(hObj, 'ForegroundColor', 1 - color)

channelColors = get(handles.ControlPanel, 'UserData');
fieldName = sprintf('ch_%d', channelNum);
channelColors.(fieldName).color = color;
set(handles.ControlPanel, 'UserData', channelColors);

% change the color of the stacks with this channelNum
for n = 1:length(metadataList)
  if metadataList(n).channelNum == channelNum
    metadataList(n).color = color;
    metadataList(n).save();
  end
end

% Plot the stacks
set(handles.axesXY, 'UserData', true)
set(handles.axesZY, 'UserData', true)
set(handles.axesXZ, 'UserData', true)
plotStacks(handles)
return

       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       %  Beginning of guide-generated functions (open/create)   %
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Executes just before confocal is made visible.
function confocal_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<*INUSL>
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to confocal (see VARARGIN)

% UIWAIT makes confocal wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% Choose default command line output for confocal
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

thisScriptName = mfilename('fullpath');

ind = strfind(thisScriptName, filesep);
if isempty(ind)
  scriptPath = '';
else
  scriptPath = thisScriptName(1:ind(end));
end

% set the list of opened channels to be empty
set(handles.MoveBox, 'String', {});
% set the channelColors to be empty
set(handles.ControlPanel, 'UserData', struct('channelList', []));

% set the version string
fid = fopen([scriptPath, 'VERSION.txt'], 'r');
if fid > 0
  versionLine = fgetl(fid);
  fclose(fid);
  set(handles.VersionLabel, 'String', versionLine);
end

% use a timer to start the parallel environment.  Using the timer allows
%  the construction of confocal to continue while matlabpool starts up in
%  the background
%t = timer('TimerFcn', @attachParallelCallback, ...
%          'StartDelay', 0.1, ...
%          'UserData', hObject);
%start(t);
set(hObject, 'UserData', ParallelBlock())
return



function attachParallelCallback(obj, event, string_arg) %#ok<INUSD>
% attach a ParallelBlock object to the UserData in confocal, guaranteeing
%  that the parallel environment is open as long as the confocal window is
%  open, and shutting it down when it's no longer required.
confocalObj = get(obj, 'UserData');
set(confocalObj, 'UserData', ParallelBlock());
return



% --- Outputs from this function are returned to the command line.
function varargout = confocal_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes during object creation, after setting all properties.
function MoveBox_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
% hObject    handle to MoveBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function ChannelListBox_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
% hObject    handle to ChannelListBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && ...
    isequal(get(hObject,'BackgroundColor'), ...
            get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function XBox_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
% hObject    handle to XBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function YBox_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
% hObject    handle to YBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject, 'UserData', pwd);

% --- Executes during object creation, after setting all properties.
function ZBox_CreateFcn(hObject, ~, ~) %#ok<DEFNU>
% hObject    handle to ZBox (see GCBO)
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


% --- Executes on button press in LoadDir.
function LoadDir_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to LoadDir (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

workingDir = pwd;
cd(get(handles.YBox, 'UserData'));
[stackFile, stackPath] = ...
  uigetfile('*.lif;*.lei;*.lei_mat', 'Open Stack File');
cd(workingDir);

if ~ischar(stackPath)
  return
end

%Set mouse pointer to indicate busy:
set(gcbf,'Pointer','watch');
drawnow;

stackFileName = [stackPath, stackFile];
fullMetadataList = OpenMetadata(stackFileName);

% some metadata corresponds to snapshots.  We only want true stacks,
% corresponding to images with logical(3) > 1
metadataList = [];
for n = 1:length(fullMetadataList)
  if fullMetadataList(n).logical(3) > 1
    metadataList = [metadataList, fullMetadataList(n)]; %#ok<AGROW>
  end
end
clear fullMetadataList;

groupChannels = get(handles.GroupChannels, 'Value');
if groupChannels
  stackNames = unique({metadataList.seriesName});
else
  stackNames = {metadataList.stackName};
end

set(handles.ChannelListBox, 'UserData', metadataList);
set(handles.ChannelListBox, 'String', stackNames);
set(handles.ChannelListBox, 'Value', 1);

if strcmp(metadataList(1).stackType, '.lei')
  % set the path to be one level up from the stack file
  if stackPath(end) == filesep
    stackPath = stackPath(1:(end-1));
  end
  slashes = strfind(stackPath, filesep);
  lastPos = slashes(end)-1;

  newPath = stackPath(1:lastPos);
  if ~isempty(strfind(workingDir, newPath))
    newPath = workingDir;
  end
else
  % set the path to be in the same path as the stack file
  newPath = stackPath;
end
set(handles.YBox, 'UserData', newPath);
%Set mouse pointer to indicate not busy:
set(gcbf,'Pointer','arrow');
drawnow
return

% --- Executes on button press in AddChannel.
function AddChannel_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to AddChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
forceVirtual = true;  %force stacks to open virtually

items = get(handles.ChannelListBox, 'String');
if isempty(items)
  % if there are items in listbox, return
  return
end

%Set mouse pointer to indicate busy:
set(gcbf,'Pointer','watch');
drawnow;

% get some informatinon about what's selected, to determine what needs to
% be added
selectedIndex = get(handles.ChannelListBox,'Value');
newMetadataList = get(handles.ChannelListBox, 'UserData');
newStackNames = get(handles.ChannelListBox, 'String');
addName = newStackNames{selectedIndex};
groupChannels = get(handles.GroupChannels, 'Value');

% find the list of new channels to add
if groupChannels
  addList = strcmp({newMetadataList.seriesName}, addName);
  addMetadata = newMetadataList(addList);
else
  addMetadata = newMetadataList(selectedIndex);
end

% get the list of channels already added
stackList = get(handles.MoveBox, 'UserData');
loadedChannelNames = get(handles.MoveBox, 'String');

% Check to see if any stacks are already there
% keep track of which of the selected stacks really must be added
numToAdd = length(addMetadata);
numLoaded = length(stackList);
addList = true(1, numToAdd);
for m = 1:numToAdd
  for n = 1:numLoaded
    meta_n = stackList(n).metadata;
    if strcmp(addMetadata(m).stackFileName, meta_n.stackFileName) && ...
        strcmp(addMetadata(m).stackName, meta_n.stackName)
      addList(m) = false;
      break
    end
  end
end

if ~any(addList)
  %nothing to add, so end function
  %Set mouse pointer to indicate not busy:
  set(gcbf,'Pointer','arrow');
  drawnow
  return
end

% create StackObj objects for the new metadata, and add it to the list of
% loaded stacks
addMetadata = addMetadata(addList);
addStacks = StackObj(addMetadata, forceVirtual);
stackList = [stackList, addStacks];
set(handles.MoveBox, 'UserData', stackList);

addName = getFullStackName(handles, addMetadata(1));
if ~ismember(addName, loadedChannelNames)
  % the name is new, so add it to the end of the list of loaded names
  loadedChannelNames = [loadedChannelNames; {addName}];
  set(handles.MoveBox, 'String', loadedChannelNames);
  set(handles.MoveBox, 'Value', length(loadedChannelNames));
end

% update the list of origins of loaded stacks
origins = get(handles.XBox, 'UserData');
numAdd = length(addMetadata);
addOrigins = zeros(numAdd, 3);
for n = 1:numAdd
  addOrigins(n,:) = addMetadata(n).origin;
end
set(handles.XBox, 'UserData', [origins; addOrigins]);

% Update the movement controls
xStr = num2str(addOrigins(end, 1) * 1e6);
yStr = num2str(addOrigins(end, 2) * 1e6);
zStr = num2str(addOrigins(end, 3) * 1e6);
set(handles.XBox, 'String', xStr)
set(handles.YBox, 'String', yStr)
set(handles.ZBox, 'String', zStr)

% Update the channel colors of the newly added channels
updateChannelColors(handles, addMetadata);

% Update the channel color buttons
createChannelColorButtons(handles);

% Plot the stacks
set(handles.axesXY, 'UserData', true)
set(handles.axesZY, 'UserData', true)
set(handles.axesXZ, 'UserData', true)
plotStacks(handles)

% Set mouse pointer to indicate not busy:
set(gcbf,'Pointer','arrow')
drawnow

% --- Executes on button press in RemoveChannel.
function RemoveChannel_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to RemoveChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% check to be sure there's something sensible to remove
selectedIndex = get(handles.MoveBox,'Value');
if selectedIndex <= 0
  return
end
channelList = get(handles.MoveBox, 'String');
if isempty(channelList)
  return
end

% delete the selected stack
numNames = length(channelList);
if numNames == 1   %Deleted the last stack
  selectedIndex = 1;
  set(handles.MoveBox, 'Value', selectedIndex);
  set(handles.MoveBox, 'String', {});
  set(handles.MoveBox, 'UserData', []);
  set(handles.XBox, 'UserData', []);
  xStr = '';
  yStr = '';
  zStr = '';
  clearPlot(handles.axesXY);
  clearPlot(handles.axesZY);
  clearPlot(handles.axesXZ);  
else  %Delete one stack, keep the rest:
  keepNamesInds = setdiff(1:numNames, selectedIndex);
  stackList = get(handles.MoveBox, 'UserData');
  deleteList = getSelectedChannels(handles, selectedIndex);
  keepStackInds = setdiff(1:length(stackList), deleteList);

  selectedIndex = length(keepNamesInds);
  set(handles.MoveBox, 'Value', selectedIndex);
  
  %Update the list in MoveBox
  channelList = channelList(keepNamesInds);
  set(handles.MoveBox, 'String', channelList);  
  
  %Update the stack data
  stackList = stackList(keepStackInds);
  set(handles.MoveBox, 'UserData', stackList);

  %Update the origin data
  origins = get(handles.XBox, 'UserData');
  origins = origins(keepStackInds,:);
  set(handles.XBox, 'UserData', origins);

  %Update the movement controls
  origin = origins(size(origins, 1),:);
  xStr = num2str(origin(1) * 1e6);
  yStr = num2str(origin(2) * 1e6);
  zStr = num2str(origin(3) * 1e6);
end

% update the coordinate box values
set(handles.XBox, 'String', xStr);
set(handles.YBox, 'String', yStr);
set(handles.ZBox, 'String', zStr);

% Update the channel color buttons
createChannelColorButtons(handles);

%Plot the stacks
set(handles.axesXY, 'UserData', true);
set(handles.axesZY, 'UserData', true);
set(handles.axesXZ, 'UserData', true);
plotStacks(handles);
return

% --- Executes on selection change in MoveBox.
function MoveBox_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to MoveBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns MoveBox contents as cell array
%        contents{get(hObject,'Value')} returns selected item from MoveBox
stackNamesList = get(hObject, 'String');
numNames = length(stackNamesList);
if numNames <= 1
  return
end

selectedIndex = get(hObject, 'Value');
stackList = get(hObject, 'UserData');
origins = get(handles.XBox, 'UserData');
numStacks = length(stackList);

%Need to get selectedList before any swapping goes on!
selectedList = getSelectedChannels(handles, selectedIndex);
% get the list that wasn't selected
notSelected = setdiff(1:numStacks, selectedList);

%When a channel/series is selected, move it to the bottom of the
% list (draw it last)
newInds = [notSelected, selectedList];
stackList = stackList(newInds);
origins = origins(newInds,:);
% update stackList:
set(hObject, 'UserData', stackList);
% update stackNames:
setChannelList(handles);
% update origins:
set(handles.XBox, 'UserData', origins);

%Update movement control boxes
xVal = origins(numStacks, 1) * 1e6;
yVal = origins(numStacks, 2) * 1e6;
zVal = origins(numStacks, 3) * 1e6;

set(handles.XBox, 'String', num2str(xVal));
set(handles.YBox, 'String', num2str(yVal));
set(handles.ZBox, 'String', num2str(zVal));

%Select last element in list
set(hObject, 'Value', numNames);

%Plot the stacks
set(handles.axesXY, 'UserData', true);
set(handles.axesZY, 'UserData', true);
set(handles.axesXZ, 'UserData', true);
plotStacks(handles);
return

% --- Executes on data entry in XBox, YBox, or ZBox
function CoordBox_CallBack(hObject, eventData, handles)
% hObject    handle to XBox, YBox, or ZBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

val = 1e-6 * str2double(get(hObject, 'String'));
origins = get(handles.XBox, 'UserData');
selectedList = getSelectedChannels(handles);

% flag some projections as needing a re-plot, and assign update dimension
switch get(hObject, 'Tag')
  case 'XBox'
    set(handles.axesXY, 'UserData', true);
    set(handles.axesXZ, 'UserData', true);
    dim = 1;
  case 'YBox'
    set(handles.axesXY, 'UserData', true);
    set(handles.axesZY, 'UserData', true);
    dim = 2;
  case 'ZBox'
    set(handles.axesZY, 'UserData', true);
    set(handles.axesXZ, 'UserData', true);
    dim = 3;
end

if isnan(val)
  val = origins(selectedList(1), dim);
  set(hObject, 'String', num2str(val*1e6));
  return
end
origins(selectedList, dim) = val;

% update origins
set(handles.XBox, 'UserData', origins);

% plot the updated projection view
plotStacks(handles);
return

% --- Executes on button press in SavePositions.
function SavePositions_Callback(hObject, eventdata, handles)  %#ok<DEFNU>
% hObject    handle to SavePositions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

origins = get(handles.XBox, 'UserData');

% Update the value of origin in the stacks
stackList = get(handles.MoveBox, 'UserData');

for n = 1:length(stackList)
  stackList(n).metadata.origin = origins(n,:);
  stackList(n).save();
end

% --- Executes on button press in AutoPosition.
function AutoPosition_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to AutoPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

plotList = getPlotList(handles);
numPlot = length(plotList);
if numPlot < 2
  return
end

%Set mouse pointer to indicate busy:
set(gcbf,'Pointer','watch');
drawnow;

origins = get(handles.XBox, 'UserData');
stackList = get(handles.MoveBox, 'UserData');
groupChannels = get(handles.GroupChannels, 'Value');
alignLastOnly = get(handles.AlignLastBox, 'Value');

xyList = cell(numPlot, 1);
yzList = cell(numPlot, 1);
xzList = cell(numPlot, 1);
originList = cell(numPlot, 1);
physicalList = cell(numPlot, 1);
for n = 1:numPlot
  % for each stack (with channels possibly grouped) get:
  %  the 3 projections, origin, and physical
  thisPlotInds = plotList{n};
  xyList{n} = ...
    getSeriesProjection(stackList, thisPlotInds, 'z', groupChannels, false);
  yzList{n} = ...
    getSeriesProjection(stackList, thisPlotInds, 'x', groupChannels, false);
  xzList{n} = ...
    getSeriesProjection(stackList, thisPlotInds, 'y', groupChannels, false);
  originList{n} = origins(thisPlotInds(1),:);
  physicalList{n} = stackList(thisPlotInds(1)).metadata.physical;
end

% align the stacks and get the new list of origins
originList = AlignStacks(xyList, yzList, xzList, ...
                         originList, physicalList, alignLastOnly);

% update origins
for n = 1:numPlot
  thisPlotInds = plotList{n};
  for m=1:length(thisPlotInds)
    origins(thisPlotInds(m),:) = originList{n};
  end
end
set(handles.XBox, 'UserData', origins);

%Update the movement controls
xStr = num2str(origins(end,1) * 1e6);
yStr = num2str(origins(end,2) * 1e6);
zStr = num2str(origins(end,3) * 1e6);
set(handles.XBox, 'String', xStr);
set(handles.YBox, 'String', yStr);
set(handles.ZBox, 'String', zStr);

%Plot the stacks
set(handles.axesXY, 'UserData', true);
set(handles.axesZY, 'UserData', true);
set(handles.axesXZ, 'UserData', true);
plotStacks(handles);

%Set mouse pointer to indicate not busy
set(gcbf,'Pointer','arrow');
drawnow;
return

% --- Executes on button press in StitchStacks.
function StitchStacks_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to StitchStacks (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%Set mouse pointer to indicate busy:
set(gcbf,'Pointer','watch');
drawnow;

origins = get(handles.XBox, 'UserData');
stackList = get(handles.MoveBox, 'UserData');
options.groupChannels = get(handles.GroupChannels, 'Value');
options.adjustDark = get(handles.AdjustDark, 'Value');

plotList = getPlotList(handles);

switch length(plotList)
 case 0,
  msgbox('You must add a channel before stitching or viewing.', ...
	 'Help', 'warn');
  %Set mouse pointer to indicate not busy:
  set(gcbf,'Pointer','arrow');
  drawnow;
  return
 case 1, 
 otherwise,
  workingDir = pwd;
  cd(get(handles.YBox, 'UserData'));
  [fileName, pathName] = uiputfile('.lei_mat', 'Choose Save Location');
  cd(workingDir);
  if ~ischar(fileName)
    %Set mouse pointer to indicate not busy:
    set(gcbf,'Pointer','arrow');
    drawnow;
    return
  end
  ind = strfind(fileName, '.lei_mat') - 1;
  if isempty(ind)
    stackFileName = [pathName, fileName, '.lei_mat'];
  else
    stackFileName = [pathName, fileName];
  end
  
  % copy the current values of origins into stackList
  for n = 1:length(stackList)
    stackList(n).metadata.origin = origins(n,:);
  end
  % stitch together the new stackList
  newStackList = StitchStacks(stackList, stackFileName, options);
  
  % newStackList will be empty if no stitching is required (only 1 series)
  if ~isempty(newStackList)
    % set the stiched stack to be the new stacklist
    clear stackList;
    stackList = newStackList;
    set(handles.MoveBox, 'UserData', stackList);

    % update origins
    origins = repmat(stackList(1).metadata.origin, ...
      [length(stackList), 1]);
    set(handles.XBox, 'UserData', origins);

    % update the list of stack names (only one stack name)
    stackNames = {getFullStackName(handles, stackList(1))};
    set(handles.MoveBox, 'String', stackNames);
    % set the selected stack to be the only stack
    set(handles.MoveBox, 'Value', 1);
    
    % indicate the projections should be re-drawn
    set(handles.axesXY, 'UserData', true);
    set(handles.axesZY, 'UserData', true);
    set(handles.axesXZ, 'UserData', true);
    %Plot the stacks
    plotStacks(handles);
  end
end

ViewStack(stackList, get(handles.YBox, 'UserData'));
%Set mouse pointer to indicate not busy:
set(gcbf,'Pointer','arrow');
drawnow;

% --- Executes on button press in GroupChannels.
function GroupChannels_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to GroupChannels (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of GroupChannels
%Re-form the list of channel names
setChannelList(handles);
set(handles.axesXY, 'UserData', true);
set(handles.axesZY, 'UserData', true);
set(handles.axesXZ, 'UserData', true);
%Plot the stacks
plotStacks(handles);

% --- Executes on button press in GroupChannels.
function Transparency_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to GroupChannels (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of GroupChannels
%Plot the stacks
set(handles.axesXY, 'UserData', true);
set(handles.axesZY, 'UserData', true);
set(handles.axesXZ, 'UserData', true);
plotStacks(handles);

function YBox_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to YBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of YBox as text
%        str2double(get(hObject,'String')) returns contents of YBox as a double
CoordBox_CallBack(hObject, eventdata, handles);

function XBox_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to XBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of XBox as text
%        str2double(get(hObject,'String')) returns contents of XBox as a double
CoordBox_CallBack(hObject, eventdata, handles);

function ZBox_Callback(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to ZBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ZBox as text
%        str2double(get(hObject,'String')) returns contents of ZBox as a double
CoordBox_CallBack(hObject, eventdata, handles);

% --- Executes when figure1 is resized.
function figure1_ResizeFcn(hObject, eventdata, handles) %#ok<DEFNU>
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty(handles)
  % if this function is called before the figure is properly constructed,
  % return
  return
end

pad = 2;
controlWidth = 386;
topControlHeight = 124;
botControlHeight = 380;

minWidth = 2 * (2 * pad + controlWidth);
minHeight = 3 * pad + topControlHeight + botControlHeight;

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
  %Supposed to resize the window, but doesn't work...
  set(gcbf, 'Position', figureSize);
  movegui(hObject, 'onscreen')
end

drawHeight = height - 2 * pad;
drawWidth = width - 3 * pad - controlWidth;
set(handles.DrawPanel, 'Position', [pad, pad, drawWidth, drawHeight])
leftStart = drawWidth + 2 * pad;
topStart = height - pad - topControlHeight;
set(handles.LoadPanel, 'Position', ...
		  [leftStart, topStart, controlWidth, topControlHeight])
set(handles.ControlPanel, 'Position', ...
		  [leftStart, pad, controlWidth, botControlHeight])
return
