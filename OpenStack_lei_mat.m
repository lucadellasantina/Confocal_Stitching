function metadataStructs = OpenStack_lei_mat(stackFileName, numNewStacks)
% metadataStructs = OpenStack_lei_mat(stackFileName, numNewStacks)
% Gets metadata information and stack interaction functions for image
% stacks of type .lei_mat
% Don't call this function directly.  It is called indirectly whenever a
% StackObj or MetadataObj of the appropriate type is created.
%  INPUTS:
%   -stackFileName: name of file with stack metadata
%   OPTIONAL:
%   -numNewewStacks: default to 0.  if > 0, create a new stacks associated
%                    with the stackFileName, don't try to load in data
if nargin < 2
  numNewStacks = 0;
end

if numNewStacks > 0
  varStruct = createNewMetadata(stackFileName, numNewStacks);
else
  varStruct = load(stackFileName, '-mat');
  if isfield(varStruct, 'StackList')
    % this is an older version of the .lei_mat format.  Convert it
    varStruct = convertOldMetadata(varStruct.StackList);
    
    % save the new metadata structures
    stackNames = fieldnames(varStruct);
    for n = 1:length(stackNames)
      saveConverted(stackFileName, varStruct.(stackNames{n}), n > 1);
    end
  end
end

ind = find(stackFileName == filesep, 1, 'last');
stackPath = stackFileName(1:ind);
stackNames = fieldnames(varStruct);
metadataStructs = [];
for n = 1:length(stackNames)
  % get the nth saved metadata structure
  stackName = stackNames{n};
  metadata = varStruct.(stackName);
  
  % set a few things, in case it's a new file, or something crazy happened
  metadata.stackType = 'lei_mat';
  metadata.stackFileName = stackFileName;
  metadata.stackPath = stackPath;
  
  % set the handles for interacting with stack
  metadata = getHandles_lei_mat(metadata);
  
  % add this struct to the list
  metadataStructs = [metadataStructs, metadata]; %#ok<AGROW>
end

return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function varStruct = createNewMetadata(stackFileName, numNewStacks)
ind2 = strfind(stackFileName, '.lei_mat') - 1;
if ~isempty(ind2)
  ind1 = find(stackFileName == filesep) + 1;
  seriesName = stackFileName(ind1(end):ind2(1));
else
  error('stack file name must end in ".lei_mat"')
end
for n = 1:numNewStacks
  metadata = struct();

  % set some defaults.  They can all be overwritten later, but something
  % must be there to create a MetadataObj
  metadata.readOnly = false;
  metadata.stackName = sprintf('%s_ch%.2d', seriesName, n);
  metadata.seriesNum = 0;
  metadata.seriesName = seriesName;
  metadata.numChannels = numNewStacks;
  metadata.channelNum = n - 1;
  metadata.channelName = sprintf('ch%.2d', n);
  metadata.intTypeName = 'uint8';
  % note, don't need to specify metadata.intType, it's created later
  metadata.numBits = 8;
  metadata.numVoxelLevels = 256;
  metadata.logical = [0, 0, 0];
  metadata.physical = [0, 0, 0];
  metadata.origin = [0, 0, 0];
  metadata.time = 0;
  
  metadata.sliceList = {};
  
  metadata.color = zeros(1,3);
  metadata.color(n) = 1;
  
  metadata.voxelStats.hist = [];
  metadata.voxelStats.blackLevel = NaN;
  metadata.voxelStats.whiteLevel = NaN;
  metadata.voxelStats.adjustScale = NaN;
  metadata.voxelStats.noiseLevel = -1;
  
  metadata.projections.max = struct();
  
  metadata.miscInfo = struct();
  
  % save this struct into a super-structure
  matName = makeMatfileName(metadata);
  %stackSaveName = makeStackSaveName(metadata);
  %varStruct.(stackSaveName) = metadata;
  varStruct.(matName) = metadata;
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function varStruct = convertOldMetadata(stackList)
numStacks = length(stackList);
for n = 1:numStacks
  stack_n = stackList{n};
  stackInfo = stack_n.StackInfo;
  if isfield(stackInfo, 'Misc')
    misc = stackInfo.Misc;
  else
    % note, don't need to specify metadata.intType, it's created later
    misc = struct('IntTypeName', 'uint8', 'NumBits', 8, ...
                  'NumIntensityLevels', 256);
  end
  metadata = struct();
  
  metadata.readOnly = false;
  metadata.stackName = stackInfo.ChanName;
  metadata.seriesNum = stackInfo.SeriesNum;
  metadata.seriesName = stackInfo.SeriesName;
  metadata.numChannels = stackInfo.NumChan;
  metadata.channelNum = stackInfo.Chan;
  metadata.channelName = sprintf('ch%.2d', stackInfo.Chan);
  metadata.intTypeName = misc.IntTypeName;
  metadata.numBits = misc.NumBits;
  metadata.numVoxelLevels = misc.NumIntensityLevels;
  metadata.logical = stackInfo.Logical;
  metadata.physical = stackInfo.Physical;
  metadata.origin = stackInfo.Origin;
  metadata.makeStackSaveFile();
  
  metadata.sliceList = stack_n.TifList;
  
  if isfield(stackInfo, 'Voxels') && isfield(stack_n, 'projections')
    metadata.voxelStats.hist = stackinfo.voxels.hist;
    metadata.voxelStats.blacklevel = stackinfo.voxels.blacklevel;
    metadata.voxelStats.whitelevel = stackinfo.voxels.whitelevel;
    metadata.voxelStats.adjustscale = metadata.voxelStats.whitelevel / ...
      (metadata.voxelStats.whitelevel - metadata.voxelStats.blacklevel);
    metadata.voxelStats.noiselevel = -1;

    proj.x.image = stack_n.projections.x;
    proj.y.image = stack_n.projections.y;
    proj.z.image = stack_n.projections.z;
    proj.x.xphysical = [0, metadata.physical(2)];
    proj.x.yphysical = [0, metadata.physical(3)];
    proj.y.xphysical = [0, metadata.physical(1)];
    proj.y.yphysical = [0, metadata.physical(3)];
    proj.z.xphysical = [0, metadata.physical(1)];
    proj.z.yphysical = [0, metadata.physical(2)];
    metadata.projections.max = proj;
  else
    % tell MetadataObj to call GetImageStats:
    metadata.voxelStats = [];
    metadata.projections = [];
  end
  
  miscInfo = struct();
  miscNames = fieldnames(misc);
  for m = 1:length(miscNames)
    field_m = miscNames{m};
    if ismember(field_m, ...
        {'NumBits', 'IntType', 'IntTypeName', 'NumIntensityLevels'});
      % these fields have been moved elsewhere, so don't include them in
      % miscInfo anymore
      continue
    end
    newField = field_m;
    newField(1) = lower(field_m(1));
    miscInfo.(newField) = misc.(field_m);
  end
  metadata.miscInfo = miscInfo;
  
  metadata.color = GetChannelColor(metadata);
  
  % save this struct into a super-structure
  matName = metadata.makeMatfileName();
  varStruct.(matName) = metadata;
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function saveConverted(stackFileName, metadataStruct, append)
matName = makeMatfileName(metadataStruct.stackName);
eval(sprintf('%s = metadataStruct;', matName))
if append
  save(stackFileName, matName, '-append');
else
  save(stackFileName, matName);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function matName = makeMatfileName(metaStruct)
% create a matlab-compatible variable name from the stack name

safeName = [metaStruct.seriesName, '_', ...
            sprintf('ch%0.2d', metaStruct.channelNum)];
badCharInds = regexp(safeName, '\W');
if ~isempty(badCharInds)
  safeName(badCharInds) = '_';
end
metaStruct.stackSaveName = safeName;
matName = ['stack_', safeName];
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function metadata = getHandles_lei_mat(metadata)
metadata.handles.intType = eval(['@', metadata.intTypeName]);
metadata.handles.setSliceZ = @setSliceZ_lei_mat;
metadata.handles.getSliceX = @getSliceX_lei_mat;
metadata.handles.getSliceY = @getSliceY_lei_mat;
metadata.handles.getSliceZ = @getSliceZ_lei_mat;
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function setSliceZ_lei_mat(metadata, sliceNum, sliceImage)
try
  tifName = metadata.sliceList{sliceNum};
catch %#ok<CTCH>
  tifName = '';
end
if isempty(tifName)
  tifName = sprintf('%s_z%.3d_ch%.2d.tif', ...
    metadata.seriesName, sliceNum, metadata.channelNum);
  metadata.sliceList{sliceNum} = tifName;
end

fileName = [metadata.stackPath, tifName];
if metadata.numBits == 8
  % don't compress low-bit images, because some programs can't open those
  % compressed images
  compression = 'none';
else
  % these guys are getting big, and simple programs probably can't handle
  % them anyway
  compression = 'lzw';
end
imwrite(sliceImage, fileName, 'Compression', compression);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice = getSliceX_lei_mat(metadata, sliceNum, rect)
if nargin < 3
  sizeRows = metadata.logical(3);
  sizeCols = metadata.logical(2);
  pixelRegion = {[1, sizeCols], [sliceNum, sliceNum]};
  zStart = 1;
else
  sizeRows = rect(2,2) - rect(2,1);
  sizeCols = rect(1,2) - rect(1,1);
  pixelRegion = {rect(1,:), [sliceNum, sliceNum]};
  zStart = rect(2,1);
end

slice = zeros(sizeRows, sizeCols, metadata.intTypeName);
zSliceNum = zStart;
for n = 1:sizeRows
  fName = [metadata.stackPath, metadata.sliceList{zSliceNum}];
  slice(n,:) = imread(fName, 'PixelRegion', pixelRegion);
  zSliceNum = zSliceNum + 1;
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice = getSliceY_lei_mat(metadata, sliceNum, rect)
if nargin < 3
  sizeRows = metadata.logical(3);
  sizeCols = metadata.logical(1);
  pixelRegion = {[sliceNum, sliceNum], [1, sizeCols]};
  zStart = 1;
else
  sizeRows = rect(2,2) - rect(2,1);
  sizeCols = rect(1,2) - rect(1,1);
  pixelRegion = {[sliceNum, sliceNum], rect(1,:)};
  zStart = rect(2,1);
end

slice = zeros(sizeRows, sizeCols, metadata.intTypeName);
zSliceNum = zStart;
for n = 1:sizeRows
  fName = [metadata.stackPath, metadata.sliceList{zSliceNum}];
  slice(n,:) = imread(fName, 'PixelRegion', pixelRegion);
  zSliceNum = zSliceNum + 1;
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice = getSliceZ_lei_mat(metadata, sliceNum, rect)
fName = [metadata.stackPath, metadata.sliceList{sliceNum}];
if nargin < 3
  slice = metadata.handles.intType(imread(fName));
else
  slice = metadata.handles.intType(...
    imread(fName, 'PixelRegion', {rect(2,:), rect(1,:)}));
end
return
