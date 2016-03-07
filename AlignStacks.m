function originList = AlignStacks(xyList, yzList, xzList, originList, ...
				  physicalList, alignLastOnly)
if nargin < 6
  alignLastOnly = false;
end
% Set maximum number of pixels to shift at any one time:
maxStep = 3;

% Make sure images are on the same scale, and have consistent color info.
[logicalList, xyList, yzList, xzList, voxelSize] = ...
    rescaleImages(xyList, yzList, xzList, physicalList);

% Down-sample the projections to help with gross positioning
[dsLogical, dsXY, dsYZ, dsXZ, dsVoxelSize] = ...
    downSampleProjections(logicalList, xyList, yzList, ...
			  xzList, voxelSize, maxStep);

%If we can't downsample, dsVoxelSize will be empty
useDS = ~isempty(dsVoxelSize);
useDS = false;

% Convert the initial origins to pixel shifts:
shiftList = originToShift(originList, voxelSize);
% Down-sampled shifts start out empty, and are progressively
%  calculated as needed
dsShifts = {};
if alignLastOnly
  % only align the last stack
  nList = length(originList);
  if useDS
    scale = voxelSize ./ dsVoxelSize;
    for n = 1:(length(originList)-1)
      dsShifts{n} = round(shiftList{n} .* scale); %#ok<AGROW>
    end
  end
else
  % Loop through stacks, starting at n = 2 (first stack doesn't move)
  nList = 2:length(originList);
end
for n = nList
  if useDS
    % if we're using downsampled projections,
    %  first convert the fine shifts to downsampled ones
    dsShifts = fineToDS(n, shiftList, voxelSize, ...
			 dsShifts, dsVoxelSize);

    %  then align the downsampled images
    dsShifts{n} = alignStack_n(dsXY, dsYZ, dsXZ, dsShifts, ...
				dsLogical, n, maxStep);

    %  then convert the new aligned downsampled shifts to
    %     fine shifts
    shiftList = dsToFine(n, shiftList, voxelSize, ...
			 dsShifts, dsVoxelSize);
  end

  % do the fine alignment of stack n
  shiftList{n} = alignStack_n(xyList, yzList, xzList, shiftList, ...
			      logicalList, n, maxStep);
end

%convert the shifts back to physical origins
originList = shiftToOrigin(shiftList, voxelSize, originList);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [logicalList, xyList, yzList, xzList, voxelSize] = ...
    rescaleImages(xyList, yzList, xzList, physicalList)

%interpMethod = '*nearest';
interpMethod = '*linear';

numStacks = length(physicalList);
logicalList = cell(1, numStacks);
voxelSizeList = cell(1, numStacks);
voxelSize = [Inf, Inf, Inf];
for n = 1:numStacks
  logicalList{n} = [size(xyList{n},2), size(xyList{n},1), ...
    size(yzList{n},1)];
  voxelSizeList{n} = physicalList{n} ./ logicalList{n};
  voxelSize = min(voxelSize, voxelSizeList{n});
end

for n = 1:numStacks
  logical = round(physicalList{n} ./ voxelSize);
  oldLogical = logicalList{n};
  Rescale = [logical(1) ~= oldLogical(1), logical(2) ~= oldLogical(2), ...
	     logical(3) ~= oldLogical(3)];

  if Rescale(1) || Rescale(2)
    NewX = (1:logical(1)) * oldLogical(1) / logical(1);
    NewY = (1:logical(2))' * oldLogical(2) / logical(2);
    if(size(xyList{n}, 3) == 1)
      xyList{n} = interp2(double(xyList{n}), NewX, NewY, interpMethod, 0);
    else
      Temp = double(xyList{n});
      xyList{n} = zeros(logical(2), logical(1), size(Temp, 3));
      for m = 1:size(Temp,3)
        xyList{n}(:,:,m) = interp2(Temp(:,:,m), NewX, NewY, ...
          interpMethod, 0);
      end
    end
  else
    xyList{n} = double(xyList{n});
  end
  
  if Rescale(2) || Rescale(3)
    NewY = (1:logical(2))' * oldLogical(2) / logical(2);
    NewZ = (1:logical(3)) * oldLogical(3) / logical(3);
    if size(yzList{n}, 3) == 1
      yzList{n} = interp2(double(yzList{n}), NewY, NewZ, interpMethod, 0);
    else
      Temp = double(yzList{n});
      yzList{n} = zeros(logical(3), logical(2), size(Temp, 3));
      for m = 1:size(Temp,3)
        yzList{n}(:,:,m) = interp2(Temp(:,:,m), NewY, NewZ, ...
          interpMethod, 0);
      end
    end
  else
    yzList{n} = double(yzList{n});
  end
    
  if Rescale(1) || Rescale(3)
    NewX = (1:logical(1)) * oldLogical(1) / logical(1);
    NewZ = (1:logical(3))' * oldLogical(3) / logical(3);
    if(size(xzList{n}, 3) == 1)
      xzList{n} = interp2(double(xzList{n}), NewX, NewZ, interpMethod, 0);
    else
      Temp = double(xzList{n});
      xzList{n} = zeros(logical(3), logical(1), size(Temp, 3));
      for m = 1:size(Temp,3)
        xzList{n}(:,:,m) = interp2(Temp(:,:,m), NewX, NewZ, ...
          interpMethod, 0);
      end
    end
  else
    xzList{n} = double(xzList{n});
  end
  
  logicalList{n} = logical;
end

xyList = makeColorConsistent(xyList);
yzList = makeColorConsistent(yzList);
xzList = makeColorConsistent(xzList);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function imList = makeColorConsistent(imList)
numColors = 1;
for n = 1:length(imList)
  nColors = size(imList{n}, 3);
  if nColors > numColors
    numColors = nColors;
  end
end

if numColors == 1
  return
end

for n = 1:length(imList)
  nColors = size(imList{n}, 3);
  if nColors < numColors
    if nColors == 1
      meanIm = imList{n};
    else
      meanIm = mean(imList{n}(:,:,1:nColors), 3);
    end
    for m = (nColors + 1):numColors
      imList{n}(:,:,m) = meanIm;
    end
  end
end

return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [dsLogical, dsXY, dsYZ, dsXZ, dsVoxelSize] = ...
    downSampleProjections(logicalList, xyList, yzList, ...
			  xzList, voxelSize, maxStep)
maxDSLen = 100;  %No more than 100 voxels per dimension per stack

numStacks = length(logicalList);
maxLogical = logicalList{1};
for n = 2:numStacks
  maxLogical = max(maxLogical, logicalList{n});
end
scale = round(maxLogical / maxDSLen);
%scale = 2 .* [maxStep, maxStep, 1] + 1
scale(scale < 2) = 1;

if sum(scale >= 2) == 0
  %Don't use downsampling, we're close enough
  dsLogical = {}; dsXY = {}; dsYZ = {}; dsXZ = {};
  dsVoxelSize = [];
  return
end

dsVoxelSize = voxelSize .* scale;
dsFact = 1.0 ./ scale;
%Now we have the down-sampled voxel size, so actually downsample
%  the projections
dsXY = cell(size(xyList));
dsYZ = cell(size(yzList));
dsXZ = cell(size(xzList));
dsLogical = cell(size(logicalList));
for n = 1:numStacks
  %downsample XY
  dsXY{n} = DownSampleImage(xyList{n}, dsFact(1), dsFact(2));
  %downsample YZ
  dsYZ{n} = DownSampleImage(yzList{n}, dsFact(2), dsFact(3));
  %downsample XZ
  dsXZ{n} = DownSampleImage(xzList{n}, dsFact(1), dsFact(3));
  %adjust dsLogical
  dsLogical{n} = round(logicalList{n} .* dsFact);
  if size(dsXY{n}, 1) ~= dsLogical{n}(2) || ...
	size(dsXY{n}, 2) ~= dsLogical{n}(1) || ...
	size(dsYZ{n}, 1) ~= dsLogical{n}(3) || ...
	size(dsYZ{n}, 2) ~= dsLogical{n}(2) || ...
	size(dsXZ{n}, 1) ~= dsLogical{n}(3) || ...
	size(dsXZ{n}, 2) ~= dsLogical{n}(1)
    fprintf(2, 'DS image sizes and dsLogical don''t match.\n');
    fprintf(2, ['This is a bug, but you can type "dbcont" to try' ...
		' to continue.\n']);
    keyboard
  end
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function shiftList = originToShift(originList, voxelSize)
shiftList = cell(1, length(originList));
shiftList{1} = zeros(size(originList{1}));
for n = 2:length(originList)
  shiftList{n} = round((originList{n} - originList{1}) ./ voxelSize);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function originList = shiftToOrigin(shiftList, voxelSize, originList)
for n = 2:length(shiftList)
  originList{n} = originList{1} + shiftList{n} .* voxelSize;
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dsShifts = fineToDS(n, shiftList, voxelSize, ...
			      dsShifts, dsVoxelSize)
scale = voxelSize ./ dsVoxelSize;
dsShifts{n-1} = round(shiftList{n-1} .* scale);
dsShifts{n} = round(shiftList{n} .* scale);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function shiftList = dsToFine(n, shiftList, voxelSize, ...
			      dsShifts, dsVoxelSize)
scale = dsVoxelSize ./ voxelSize;

fineDelta = (dsShifts{n} - dsShifts{n-1}) .* scale;
shiftList{n} = round(shiftList{n-1} + fineDelta);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Shift = alignStack_n(xyList, yzList, xzList, shiftList, ...
			                        logicalList, stackNum, maxStep, useScaledMSE)
if nargin < 8
  useScaledMSE = true;
end

%Define relative movement indices
midInd = 1 + maxStep;
maxInd = midInd + maxStep;

%Calculate which stacks and which projections to use in aligning
%  stack n.  useInd is a list of arrays {XYInd, YZInd, XZInd}
useInd = GetUseInd(shiftList, logicalList, stackNum);

%Calculate which if any position dimensions we can align.  Give up
%  if the answer is "none"
Shift = shiftList{stackNum};
if isempty(useInd{1})
  if isempty(useInd{2})
    if isempty(useInd{3})
      return
    end
    XRange = 1:maxInd;
    YRange = midInd;
    ZRange = 1:maxInd;
  elseif isempty(useInd{3})
    XRange = midInd;
    YRange = 1:maxInd;
    ZRange = 1:maxInd;
  else
    XRange = 1:maxInd;
    YRange = 1:maxInd;
    ZRange = 1:maxInd;
  end
elseif isempty(useInd{2}) && isempty(useInd{3})
  XRange = 1:maxInd;
  YRange = 1:maxInd;
  ZRange = midInd;
else
  XRange = 1:maxInd;
  YRange = 1:maxInd;
  ZRange = 1:maxInd;
end

logical = logicalList{stackNum};
%Set up the lists+images to be passed to MeanSquareError() for each
%  dimension
XY = xyList{stackNum};
XYLogical = logical([1,2]);
xyList = xyList(useInd{1});
numUse = length(useInd{1});
XYshiftList = cell(1, numUse); XYlogicalList = cell(1, numUse);
for m = 1:numUse
  XYshiftList{m} = shiftList{useInd{1}(m)}([1,2]);
  XYlogicalList{m} = logicalList{useInd{1}(m)}([1,2]);
end
YZ = yzList{stackNum};
YZLogical = logical([2,3]);
yzList = yzList(useInd{2});
numUse = length(useInd{2});
YZshiftList = cell(1, numUse); YZlogicalList = cell(1, numUse);
for m = 1:length(useInd{2})
  YZshiftList{m} = shiftList{useInd{2}(m)}([2,3]);
  YZlogicalList{m} = logicalList{useInd{2}(m)}([2,3]);
end
XZ = xzList{stackNum};
XZLogical = logical([1,3]);
xzList = xzList(useInd{3});
numUse = length(useInd{3});
XZshiftList = cell(1, numUse); XZlogicalList = cell(1, numUse);
for m = 1:length(useInd{3})
  XZshiftList{m} = shiftList{useInd{3}(m)}([1,3]);
  XZlogicalList{m} = logicalList{useInd{3}(m)}([1,3]);
end

% choose which error function to use
if useScaledMSE
  errorFunc = @scaledMeanSquareError;
else
  errorFunc = @meanSquareError;
end

%Now iterate by filling up a 3D block of nearest neighbor shifts,
%   and choosing the one with the least MSE.  Stop when the center of
%   the block (no new change) equals the least MSE.
MSE_Block = nan(maxInd, maxInd, maxInd);
Done = false;
while ~Done
  for IndX = XRange
    for IndY = YRange
      for IndZ = ZRange
        if isnan(MSE_Block(IndX, IndY, IndZ))
          NewShift = Shift + [IndX - midInd, IndY - midInd, IndZ - midInd];
	  
          XYShift = NewShift([1,2]);
          MSE = errorFunc(XY, XYShift, XYLogical, ...
            xyList, XYshiftList, XYlogicalList);
          YZShift = NewShift([2,3]);
          MSE = MSE + errorFunc(YZ, YZShift, YZLogical, ...
            yzList, YZshiftList, YZlogicalList);
          XZShift = NewShift([1,3]);
          MSE = MSE + errorFunc(XZ, XZShift, XZLogical, ...
            xzList, XZshiftList, XZlogicalList);
          MSE_Block(IndX, IndY, IndZ) = MSE;
        end
      end
    end
  end
  
  [MinVal, MinInd] = min(MSE_Block(:));

  if MSE_Block(midInd, midInd, midInd) == MinVal
    Done = true;
  else
    [IndX, IndY, IndZ] = ind2sub(size(MSE_Block), MinInd);
    thisShift = [IndX - midInd, IndY - midInd, IndZ - midInd];
    Shift = Shift + thisShift;
    
    newX = max(1,1-thisShift(1)):min(maxInd,maxInd-thisShift(1));
    newY = max(1,1-thisShift(2)):min(maxInd,maxInd-thisShift(2));
    newZ = max(1,1-thisShift(3)):min(maxInd,maxInd-thisShift(3));
    oldX = newX + thisShift(1);
    oldY = newY + thisShift(2);
    oldZ = newZ + thisShift(3);
    oldMSE = MSE_Block;
    MSE_Block(:) = NaN;
    MSE_Block(newX,newY,newZ) = oldMSE(oldX,oldY,oldZ);
  end
end

return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function useInd = GetUseInd(shiftList, logicalList, n)
useIndXY = [];
useIndYZ = [];
useIndXZ = [];
Shift_n = shiftList{n};
logical_n = logicalList{n};

mostly = 0.5;

%loop over previous stacks (stack_m where m < n)
for m = 1:(n-1)
  %calculate overlap in each dimension
  Shift_m = shiftList{m};
  logical_m = logicalList{m};
  
  LowPoint = max(Shift_n, Shift_m);
  HighPoint = min(Shift_n + logical_n, Shift_m + logical_m);
  
  Overlap = (HighPoint - LowPoint) ./ max(logical_n, logical_m);
  
  %To be useful at all, every dimension must overlap a little
  if sum(Overlap <= 0) > 0
    %if at least one doesn't, go to next stack
    continue
  end
  %To be useful in particular, the projected dimension must
  %  mostly overlap
  if Overlap(1) >= mostly
    useIndYZ = [useIndYZ, m]; %#ok<AGROW>
  end
  if Overlap(2) >= mostly
    useIndXZ = [useIndXZ, m]; %#ok<AGROW>
  end
  if Overlap(3) >= mostly
    useIndXY = [useIndXY, m]; %#ok<AGROW>
  end
end
useInd = {useIndXY, useIndYZ, useIndXZ};
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function MSE = meanSquareError(Im, Shift, logical, ...
			       ImList, shiftList, logicalList)
MSE = 0;
NColors = size(Im, 3);
for n = 1:length(ImList)
  Im2 = ImList{n};
  Shift2 = shiftList{n};
  logical2 = logicalList{n};
  
  %First calculate the areas of overlap.
  RelShift = Shift - Shift2;

  X1Min = max(1, 1 - RelShift(1));
  X1Max = min(logical(1), logical2(1) - RelShift(1));
  Y1Min = max(1, 1 - RelShift(2));
  Y1Max = min(logical(2), logical2(2) - RelShift(2));
  
  X2Min = max(1, 1 + RelShift(1));
  X2Max = min(logical2(1), logical(1) + RelShift(1));
  Y2Min = max(1, 1 + RelShift(2));
  Y2Max = min(logical2(2), logical(2) + RelShift(2));
  
  if X1Max <= 0 || Y1Max <= 0 || X2Max <= 0 || Y2Max <= 0
    MSE = Inf;
    return
  end
  
  Overlap = (1 + X1Max - X1Min) * (1 + Y1Max - Y1Min) * NColors;

  MSE = MSE + sum(sum(sum((Im2(Y2Min:Y2Max,X2Min:X2Max,:) ...
    -Im(Y1Min:Y1Max,X1Min:X1Max,:)).^2))) ...
    / Overlap;
  if ~isfinite(MSE)
    fprintf(2, 'Infinite/NaN mean square error\n');
    fprintf(2, ['This is a bug, but you can type "dbcont" to try' ...
		            ' to continue.\n']);
    keyboard
  end
end
return



function MSE = scaledMeanSquareError(Im, Shift, logical, ...
			       ImList, shiftList, logicalList)
MSE = 0;
NColors = size(Im, 3);
for n = 1:length(ImList)
  Im2 = ImList{n};
  Shift2 = shiftList{n};
  logical2 = logicalList{n};
  
  %First calculate the areas of overlap.
  RelShift = Shift - Shift2;

  X1Min = max(1, 1 - RelShift(1));
  X1Max = min(logical(1), logical2(1) - RelShift(1));
  Y1Min = max(1, 1 - RelShift(2));
  Y1Max = min(logical(2), logical2(2) - RelShift(2));
  
  X2Min = max(1, 1 + RelShift(1));
  X2Max = min(logical2(1), logical(1) + RelShift(1));
  Y2Min = max(1, 1 + RelShift(2));
  Y2Max = min(logical2(2), logical(2) + RelShift(2));
  
  if X1Max <= 0 || Y1Max <= 0 || X2Max <= 0 || Y2Max <= 0
    MSE = Inf;
    return
  end
  
  Overlap = (1 + X1Max - X1Min) * (1 + Y1Max - Y1Min) * NColors;
  scaled1 = getScaledImage(Im(Y1Min:Y1Max,X1Min:X1Max,:));
  scaled2 = getScaledImage(Im2(Y2Min:Y2Max,X2Min:X2Max,:));
  
  MSE = MSE + sum( (scaled2(:) - scaled1(:)).^2 ) / Overlap;
  if ~isfinite(MSE)
    fprintf(2, 'Infinite/NaN mean square error\n');
    fprintf(2, ['This is a bug, but you can type "dbcont" to try' ...
		            ' to continue.\n']);
    keyboard
  end
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function scaledImage = getScaledImage(rawImage)
numColors = size(rawImage, 3);
if numColors == 1
  meanVal = mean(rawImage(:));
  scaledImage = rawImage / meanVal;
else
  scaledImage = zeros(size(rawImage));
  for n = 1:numColors
    color_n = rawImage(:,:,n);
    meanVal = mean(color_n(:));
    if meanVal == 0
      scaledImage(:,:,n) = 0;
      continue
    end
    scaledImage(:,:,n) = color_n / meanVal;
  end
end
return
