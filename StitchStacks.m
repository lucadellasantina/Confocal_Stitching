function newStackList = StitchStacks(stackList, stackFileName, options)
% newStackList = StitchStacks(stackList, stackFileName, options)
% Stitches together the stacks in stackList, creating a new list of stacks.
% Generally this function should be called from within confocal.m
%
%  INPUTS:
%   -stackList:  list of StackObjs.  It's the caller's job to make sure
%                that they are compatible for stitching (e.g. have the same
%                number of bits per voxel) and are properly aligned (as set
%                in metadata.origin)
%   -stackFileName: filename associated with the stitched together stacks
%   -options:  structure with boolean fields
%     groupChannels: make one stack per channel if true, otherwise create
%                    one stack from all stacks in stackList
%     adjustDark: discouraged for all but worst scans.  if true, remap
%                 dynamic range so voxelStats.blackLevel -> 0 and
%                 voxelStats.whiteLevel -> numVoxelLevels
% OUTPUT:
%  -newStackList: list of StackObjs

% create the new stacks as virtual stacks
forceVirtual = true;

% divide up the Stacks into the different channels
[channels, chanStitchList, done] = getChanStitchList(stackList, options);
if done
  % if no stitching is needed, return an empty stack
  newStackList = [];
  return
end
numChannels = length(channels);

%Get some data to help stitch
stackStats = getStackStats(stackList);

% create the stack objects
newStackList = StackObj(stackFileName, forceVirtual, numChannels);

%Now do the stitching, one channel at a time
numSteps = numChannels * stackStats(1).logical(3);
ProgressBar('Stitching', numSteps);
parBlock = ParallelBlock();
parfor n = 1:numChannels
  channel = channels(n);
  stitchList = chanStitchList{n};
  newStack = newStackList(n);
  oldStacks_n = stackList(stitchList); %#ok<PFBNS>
  stackStats_n = stackStats(stitchList); %#ok<PFBNS>
  % set up the metadata of the new stack
  setMetadata(newStack, channel, oldStacks_n, stackStats_n);

  % do the actual stitching, finish assigning metadata
  doStitch(newStack, oldStacks_n, stackStats_n, options);
  
  % save stack
  newStack.save();
  
  % this is necessary because of parfor
  newStackList(n) = newStack;
end
parBlock.endBlock();

% save the stitched stacks in ome.tiff format
Save_OME_TIFF(newStackList);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [channels, chanStitchList, done] = ...
  getChanStitchList(stackList, options)
% get
%  channels: the list of all unique channel numbers
%  chanStitchList: a list of indices to each stack of a given channel number
%  done: a boolean, true indicates no stitching is necessary
numStacks = length(stackList);
if options.groupChannels
  % get the list of each stack's channel number
  channelList = zeros(1, numStacks);
  for n = 1:numStacks
    channelList(n) = stackList(n).metadata.channelNum;
  end
  channels = unique(channelList);
  
  numChannels = length(channels);
  chanStitchList = cell(1, numChannels);
  done = true;
  for n = 1:numChannels
    chan = channels(n);
    thisList = find(channelList == chan);
    chanStitchList{n} = thisList;
    if length(thisList) > 1
      done = false;
    end
  end
  
else
  channels = 0;
  chanStitchList = {1:numStacks};
  done = (numStacks < 2);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function stackStats = getStackStats(stackList)
minCoords = [Inf, Inf, Inf];
maxCoords = [-Inf, -Inf, -Inf];
voxelSize = [Inf, Inf, Inf];

numStacks = length(stackList);

% First get the physical extent and resolution.  Keep the largest physical
% extent, and smallest resolution element
for n = 1:numStacks
  metadata = stackList(n).metadata;
  physical = metadata.physical;
  origin = metadata.origin;
  logical = metadata.logical;
  
  thisMaxCoords = origin + physical;
  minCoords = min(minCoords, origin);
  maxCoords = max(maxCoords, thisMaxCoords);
  
  thisVoxelSize = physical ./ logical;
  voxelSize = min(voxelSize, thisVoxelSize);
end

logical = ceil((maxCoords - minCoords) ./ voxelSize);

stackStats.minCoords = minCoords;
stackStats.maxCoords = maxCoords;
stackStats.voxelSize = voxelSize;
stackStats.logical = logical;
stackStats.physical = stackStats.logical .* stackStats.voxelSize;
stackStats.shift = zeros(1, 3);
stackStats.interp = struct();
stackStats = repmat(stackStats, [numStacks, 1]);

% Now go back and get:
%  -shifts (origin with respect to stitched stack, in terms of number of
%           pixels)
%  -interpolation information (whether each stack needs to be interpolated,
%                           and if so, quantifying the interpolation needs)
for n = 1:numStacks
  metadata = stackList(n).metadata;
  origin = metadata.origin;
  physical = metadata.physical;
  thisLogical = metadata.logical;
  
  stackStats(n).shift = round((origin - minCoords) ./ voxelSize);
  newLogical = round(physical ./ voxelSize);
  diffLogical = newLogical - thisLogical;

  interpStruct = struct();
  interpStruct.interpZ = (diffLogical(3) > 0);
  interpStruct.interpXY = (diffLogical(1) > 0 || diffLogical(2) > 0);
  interpStruct.logical = newLogical;

  if interpStruct.interpZ
    zOld = origin(3) + physical(3) * ...
      (-0.5 + 1:thisLogical(3)) / thisLogical(3);
    zNew = origin(3) + physical(3) * ...
      (-0.5 + 1:newLogical(3)) / newLogical(3);

    ind1 = zeros(newLogical(3));
    coef1 = zeros(newLogical(3), 'single');
    m = 2;
    for k = 1:(newLogical(3)-1);
      if zOld(m) <= zNew(k)
        m = m + 1;
      end
      ind1(k) = m - 1;
      coef1(k) = (zOld(m) - zNew(k)) / (zOld(m) - zOld(m-1));
      if coef1(k) > 1.0
        coef1(k) = 1.0;
      end
    end
    ind1(end) = thisLogical(3);
    coef1(end) = 1;
    
    interpStruct.ind1 = ind1;
    interpStruct.coef1 = coef1;
    interpStruct.slice1 = zeros(newLogical(2), newLogical(1), 'single');
    interpStruct.slice2 = zeros(newLogical(2), newLogical(1), 'single');
    interpStruct.lastNum = 0;
  end
  if interpStruct.interpXY
    % create interpolation info for XY plane
    % notes:
    %   -the -0.5 is included because we interpolate from the middle of
    %    bins
    %   -the overall addition of 0.5 is because the interpolation is done
    %    assuming the original image was 1:thisLogical, i.e. this is a
    %    conversion factor
    newX = 0.5 + (-0.5 + 1:newLogical(1)) * ...
                 (thisLogical(1) / newLogical(1));
    newY = 0.5 + (-0.5 + 1:newLogical(2))' * ...
                 (thisLogical(2) / newLogical(2));
    interpStruct.newX = newX;
    interpStruct.newY = newY;
  end

  stackStats(n).interp = interpStruct;
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function setMetadata(newStack, channel, oldStackList, stackStats)
source1 = oldStackList(1).metadata;
metadata = newStack.metadata;

metadata.stackName = [metadata.seriesName, '_', source1.channelName];

seriesName = strtok(metadata.stackFileName, '.');
ind = strfind(seriesName, '/');
if any(ind)
  ind = ind(end);
  seriesName = seriesName(ind+1:end);
end

metadata.seriesName = seriesName; % source1.seriesName;
metadata.seriesNum = 0; % source1.seriesNum;
metadata.channelNum = channel;
metadata.channelName = source1.channelName;
metadata.intTypeName = source1.intTypeName;
metadata.numBits = source1.numBits;
metadata.numVoxelLevels = source1.numVoxelLevels;
metadata.handles.intType = eval(['@', metadata.intTypeName]);
metadata.logical = stackStats(1).logical;
metadata.physical = stackStats(1).physical;
metadata.origin = stackStats(1).minCoords;
metadata.time = 0;  % only one stack in this series

metadata.color = source1.color;

metadata.miscInfo = source1.miscInfo;

metadata.makeStackSaveName();

% keep track of source information
originalStackFiles = {};
for n = 1:length(oldStackList)
  stackFileName = oldStackList(n).metadata.stackFileName;
  if ~ismember(stackFileName, originalStackFiles)
    originalStackFiles = [originalStackFiles, {stackFileName}]; %#ok<AGROW>
  end
end
metadata.miscInfo.originalStackFiles = originalStackFiles;
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function doStitch(newStack, oldStacks, stackStats, options)

numOldStacks = length(oldStacks);
logical = stackStats(1).logical;
physical = stackStats(1).physical;
numZ = logical(3);
intTypeName = newStack.metadata.intTypeName;
tempSlice = zeros(logical(2), logical(1), intTypeName);
mask = zeros(logical(2), logical(1), 'uint16');

projections.x.image = zeros(logical(3), logical(2), intTypeName);
projections.y.image = zeros(logical(3), logical(1), intTypeName);
projections.z.image = zeros(logical(2), logical(1), intTypeName);
projections.x.xPhysical = [0, physical(2)];
projections.x.yPhysical = [0, physical(3)];
projections.y.xPhysical = [0, physical(1)];
projections.y.yPhysical = [0, physical(3)];
projections.z.xPhysical = [0, physical(1)];
projections.z.yPhysical = [0, physical(2)];

numBins = newStack.metadata.numVoxelLevels;
bins = 0:(numBins - 1);
voxelStats.hist = zeros(size(bins));

%Loop through the new stitched slices, calculating the
%  maximum projections as we go
for n = 1:numZ
  mask(:) = 0;
  tempSlice(:) = 0;
  
  % The next section pieces together a stitched stack slice from the slices
  % of the original (old) stacks. This is the "hard" version, which only
  % uses one stack per voxel. In principle, one could use a "soft" version
  % where stacks are weighted by variance
  %
  % mask starts out empty, same size as tempSlice
  % For each stack in oldStacks
  %   find correct x and y indices in original image (xL, xH), (yL, yH)
  %   overlapMask = mask(yL:YH,XL:XH)
  %   maskVals = unique(overlapMask)
  %   ind = find(overlapMask == 0)
  %   indOrig = getIndOrig(ind, YL, YH, XL, XH, size(TempSlice));
  %   TempSlice(indOrig) = StackSlice(ind);
  %   Mask(indOrig) = stackNum
  %   for each nonzero maskVal
  %     ind = find(overlapMask = maskVal)
  %     indOrig = getIndOrig(ind, YL, YH, XL, XH, size(TempSlice));
  %     varOrig = variance(TempSlice(indOrig))
  %     varNew = variance(StackSlice(ind))
  %     if varNew > varOrig
  %       TempSlice(indOrig) = StackSlice(ind)
  %       Mask(indOrig) = stackNum
  %     end
  %   end
  
  for stackNum = 1:numOldStacks
    % get the nth slice from this stack
    [stackSlice, stackStats] = ...
      getStackSlice(oldStacks, stackNum, n, stackStats, options);
    % if the stack slice isn't empty, add it to the stitched slice
    if ~isempty(stackSlice)
      % get size and shift info for the stack slice
      [ySize, xSize] = size(stackSlice);
      shift = stackStats(stackNum).shift;
      % get the low and high x and y values (where stackSlice fits in final
      % stitched slice)
      yL = 1 + shift(2); yH = shift(2) + ySize;
      xL = 1 + shift(1); xH = shift(1) + xSize;
      
      % get the mask on the section of overlap
      overlapMask = mask(yL:yH,xL:xH);
      % find the indices that have no prior image in them
      ind = find(overlapMask == 0);
      % find the correpsonding indices on the stitched slice
      indOrig = getIndOrig(ind, yL, xL, ySize, xSize, ...
                           logical(2), logical(1));
      
      % copy the stack slice onto the empty parts of the stitched slice
      tempSlice(indOrig) = stackSlice(ind);
      mask(indOrig) = stackNum;
      % get all the previously filled overlap regions, broken down by which
      % stack had filled them
      maskVals = setdiff(unique(overlapMask(:)), 0);
      for maskValInd = 1:length(maskVals)
        maskVal = maskVals(maskValInd);
        ind = find(overlapMask == maskVal);
        indOrig = getIndOrig(ind, yL, xL, ySize, xSize, ...
          logical(2), logical(1));
        % get the standard deviation of image values on this section of
        % overlap.  This is a proxy for signal amplitude.
        stdStack = std(stackSlice(ind));
        stdOrig = std(single(tempSlice(indOrig)));
        % Use the stack that has the greatest amplitude.  The logic here is
        % that bleached sections will have decreased amplitude, and should
        % be discarded
        if stdStack > stdOrig
          % the stack slice has the greatest amplitude, so copy it in
          tempSlice(indOrig) = stackSlice(ind);
          mask(indOrig) = stackNum;
        end
      end
    end
  end
  
  projections.x.image(n,:) = max(tempSlice, [], 2);
  projections.y.image(n,:) = max(tempSlice, [], 1);
  projections.z.image = max(tempSlice, projections.z.image);
  voxelStats.hist = voxelStats.hist + hist(tempSlice(:), bins);
  
  newStack.setSliceZ(n, tempSlice);
  ProgressBar('Stitching')
end

lowEnd = round(0.2 * bins(end));
[~, voxelStats.blackLevel] = max(voxelStats.hist(1:lowEnd));
voxelStats.whiteLevel = find(voxelStats.hist > 0, 1, 'last');
voxelStats.adjustScale = voxelStats.whiteLevel / ...
  (voxelStats.whiteLevel - voxelStats.blackLevel);
voxelStats.noiseLevel = -1;

newStack.metadata.projections.max = projections;
newStack.metadata.voxelStats = voxelStats;
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function  [stackSlice, stackStats] = ...
  getStackSlice(stackList, stackNum, n, stackStats, options)
stack = stackList(stackNum);
metadata = stack.metadata;
shift = stackStats(stackNum).shift;

n = n - shift(3);
if n < 1 || n > metadata.logical(3)
  stackSlice = [];
  return
end

voxelStats = metadata.voxelStats;
interp = stackStats(stackNum).interp;

if interp.interpZ
  ind1 = interp.ind1(n);
  coef1 = interp.coef1(n);
  %fprintf('ind1 = %g, coef1 = %g\n', ind1, coef1)
  if interp.lastNum < ind1
    %Get the next image:
    interp.slice1 = single(stack.getSliceZ(ind1));
    interp.lastNum = ind1;
    if options.adjustDark
      interp.slice1(:) = voxelStats.adjustScale * ...
        max(interp.slice1(:) - voxelStats.blackLevel, 0);
    end
  elseif interp.lastNum == ind1
    interp.slice1 = interp.slice2;
  end
  if interp.lastNum < ind1+1
    %Get the next image:
    interp.slice2 = single(stack.getSliceZ(ind1+1));
    interp.lastNum = ind1+1;
    if options.adjustDark
      interp.slice2(:) = voxelStats.adjustScale * ...
        max(interp.slice2(:) - voxelStata.blackLevel, 0);
    end  
  end
  if coef1 < 1
    stackSlice = interp.slice1 * coef1 + interp.slice2 * (1 - coef1);
  else
    stackSlice = interp.slice1;
  end
  stackStats(stackNum).interp = interp;
else
  %Get the image:
  stackSlice = single(stack.getSliceZ(n));
  if options.adjustDark
    stackSlice(:) = voxelStats.adjustScale * ...
      max(stackSlice(:) - voxelStats.blackLevel, 0);
  end
end

%Next do any XY interpolation
if interp.interpXY
  stackSlice = interp2(stackSlice, interp.newY, interp.newX, '*linear', 0);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function indOrig = getIndOrig(ind, yL, xL, ySize, xSize, ...
                              origYSize, origXSize)
[ySub, xSub] = ind2sub([ySize, xSize], ind);
ySub = ySub + (yL - 1);
xSub = xSub + (xL - 1);
indOrig = sub2ind([origYSize, origXSize], ySub, xSub);
return
