function newStackList = ...
  DownSampleStack(stackList, stackFileName, cropScaleStruct)
% Stack = DownSampleStack(stackList, stackFileName, cropScaleStruct)
% Crops and then down-samples an image stack.  Voxel size may INCREASE or
% remain constant in any dimension but it may not decrease on any
% dimension.
%  INPUT:
%    -stackList: vector of StackObj.  The stacks should all be from the
%                same series (i.e. they are different channels)
%    -stackFileName: filename associated with new stacks
%    -cropScaleStruct: structure with fields:
%                       scaleVec:  describes increase in voxel size
%                       rangeX, rangeY, rangeZ: describe crop ranges in
%                                               terms of voxels
%                       sizeVec:  vector of length 3, specifying x, y, and
%                                 z sizes in pixels

%Do a few quick input checks
if nargin ~= 3
  help DownSampleStack
  error('Incorrect number of arguments.')
end
if any(cropScaleStruct.scaleVec < 1)
    error('DownSampleStack can only downsize, must select scaleVec >= 1')
end

% for now, create virtual stacks, although since they are being
%  downsampled, it's likely to be okay to change this later
forceVirtual = true;

numStacks = length(stackList);
newStackList = StackObj(stackFileName, forceVirtual, numStacks);

numSteps = numStacks * getTotalSlices(cropScaleStruct);
ProgressBar('Downsampling', numSteps)
for n=1:numStacks
  % create metadata for new stack
  setMetadata(newStackList(n), stackList(n), cropScaleStruct);
  % downsample each stack.
  doDownSample(newStackList(n), stackList(n), cropScaleStruct);
end

% save the stitched stacks in ome.tiff format
Save_OME_TIFF(newStackList);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function numSlices = getTotalSlices(cropScaleStruct)
ZLow = cropScaleStruct.rangeZ(1);
ZHigh = cropScaleStruct.rangeZ(2);
scaleVec = cropScaleStruct.scaleVec;
numSlices = round((ZHigh + 1 - ZLow) / scaleVec(3));
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function setMetadata(newStack, oldStack, cropScaleStruct)
oldMetadata = oldStack.metadata;
metadata = newStack.metadata;

oldLogical = 1 + ...
  [diff(cropScaleStruct.rangeX), ...
   diff(cropScaleStruct.rangeY), ...
   diff(cropScaleStruct.rangeZ)];
newLogical = round(oldLogical ./ cropScaleStruct.scaleVec);
newPhysical = oldMetadata.physical .* (oldLogical ./ oldMetadata.logical);
oldVSize = oldMetadata.physical / oldMetadata.logical;
newOrigin = oldMetadata.origin + oldVSize .* ...
  [cropScaleStruct.rangeX(1), ...
   cropScaleStruct.rangeY(1), ...
   cropScaleStruct.rangeZ(1)];

metadata.stackName = [metadata.seriesName, '_', oldMetadata.channelName];
metadata.seriesNum = oldMetadata.seriesNum;
metadata.channelNum = oldMetadata.channelNum;
metadata.numChannels = oldMetadata.numChannels;
metadata.channelName = oldMetadata.channelName;
if isfield(cropScaleStruct, 'numBits')
  metadata.numBits = cropScaleStruct.numBits;
  metadata.intTypeName = sprintf('uint%d', 8 * ceil(metadata.numBits / 8));
else
  metadata.numBits = oldMetadata.numBits;
  metadata.intTypeName = oldMetadata.intTypeName;
end
metadata.numVoxelLevels = 2^metadata.numBits;
metadata.handles.intType = eval(['@', metadata.intTypeName]);
metadata.logical = newLogical;
metadata.physical = newPhysical;
metadata.origin = newOrigin;

metadata.color = oldMetadata.color;
metadata.makeStackSaveName();

metadata.sliceList = {};

projections.x.image = [];
projections.y.image = [];
projections.z.image = [];
projections.x.xPhysical = [0, newPhysical(2)];
projections.x.yPhysical = [0, newPhysical(3)];
projections.y.xPhysical = [0, newPhysical(1)];
projections.y.yPhysical = [0, newPhysical(3)];
projections.z.xPhysical = [0, newPhysical(1)];
projections.z.yPhysical = [0, newPhysical(2)];
metadata.projections.max = projections;

metadata.miscInfo = oldMetadata.miscInfo;
metadata.miscInfo.downSampleFile = oldMetadata.stackFileName;
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function doDownSample(newStack, oldStack, cropScaleStruct)

oldMetadata = oldStack.metadata;
xLow = cropScaleStruct.rangeX(1); xHigh = cropScaleStruct.rangeX(2);
yLow = cropScaleStruct.rangeY(1); yHigh = cropScaleStruct.rangeY(2);
zLow = cropScaleStruct.rangeZ(1); zHigh = cropScaleStruct.rangeZ(2);
oldSubLogical = 1 + [xHigh - xLow, yHigh - yLow, zHigh - zLow];
rect = [cropScaleStruct.rangeX; cropScaleStruct.rangeY];

newMetadata = newStack.metadata;
newLogical = newMetadata.logical;
intTypeName = newMetadata.intTypeName;
intType = newMetadata.handles.intType;
xFact = newLogical(1) / oldSubLogical(1);
yFact = newLogical(2) / oldSubLogical(2);
zFact = newLogical(3) / oldSubLogical(3);
bitRatio = newMetadata.numVoxelLevels / oldMetadata.numVoxelLevels;

startInds = zLow:zFact:zHigh;
stopInds = (zLow+zFact-1):zFact:zHigh;

smallSlice = zeros(newLogical(2), newLogical(1));
tempSlice = zeros(newLogical(2), newLogical(1));

projX = zeros(newLogical(3), newLogical(2), intTypeName);
projY = zeros(newLogical(3), newLogical(1), intTypeName);
projZ = zeros(newLogical(2), newLogical(1), intTypeName);


bins = 0:(newMetadata.numVoxelLevels - 1);
voxelStats.hist = zeros(size(bins));
%profile clear on -history
for n=1:length(startInds)
  %Make image from z-slices startInds:stopInds (some may be fractional):
  ind = startInds(n);
  if ind < ceil(ind)
    % some fractional piece left over from before.  Add it in.
    coef = ceil(ind) - ind;
    tempSlice = coef * smallSlice;
    ind = ceil(ind);
  else
    % no previous fractional piece.  Start with 0.
    tempSlice(:) = 0;
  end
  stopInt = floor(stopInds(n));
  for ind=ind:stopInt
    % add in whole slices
    oldSlice = double(oldStack.getSliceZ(ind, rect));
    tempSlice = tempSlice + DownSampleImage(oldSlice, xFact, yFact);
  end
  if stopInt < stopInds(n)
    % there's a fractional slice left.  Add it in.
    coef = stopInds(n) - stopInt;
    ind = ceil(stopInds(n));
    oldSlice = double(oldStack.getSliceZ(ind, rect));
    smallSlice = DownSampleImage(oldSlice, xFact, yFact);
    tempSlice = tempSlice + coef * smallSlice;
  end
  % scale the result
  tempSlice = tempSlice * (zFact * bitRatio);
  % convert voxels to integer values
  intSlice = intType(tempSlice);
  
  % save the slice
  newStack.setSliceZ(n, intSlice);

  % calculate maximum projections of downsampled stack:
  projX(n,:) = max(intSlice, [], 2);
  projY(n,:) = max(intSlice, [], 1);
  projZ = max(intSlice, projZ);
  
  % update voxelStats
  voxelStats.hist = voxelStats.hist + hist(intSlice(:), bins);
  
  ProgressBar('Downsampling')
end
%profile off

newMetadata.projections.max.x.image = projX;
newMetadata.projections.max.y.image = projY;
newMetadata.projections.max.z.image = projZ;

lowEnd = round(0.2 * bins(end));
[~, voxelStats.blackLevel] = max(voxelStats.hist(1:lowEnd));
voxelStats.whiteLevel = find(voxelStats.hist > 0, 1, 'last');
voxelStats.adjustScale = voxelStats.whiteLevel / ...
    (voxelStats.whiteLevel - voxelStats.blackLevel);
voxelStats.noiseLevel = -1;
newMetadata.voxelStats = voxelStats;

newStack.save();
return
