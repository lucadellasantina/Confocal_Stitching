function GetImageStats(metadata)
% GetImageStats(metadata)
% Set the values of metadata.voxelStats, and metadata.projections, and if
% appropriate, reload saved value of metadata.origin
%  INPUT:
%  -metadata: MetadataObj

version = '1.0.3';

if nargin ~= 1
  help GetImageStats
  error('Invalid number of inputs');
end

stackPath = metadata.stackPath;
stackSaveName = metadata.stackSaveName;
saveFileName = sprintf('%s%s_ImageStats.mat', stackPath, stackSaveName);

%Check to see if the information we need is saved:
calcStats = false;
saveImageStats = false;
origin = metadata.origin;
if FileExists(saveFileName)
  %load imageStats
  load(saveFileName);
  if exist('ImageStats', 'var')
    % older versions used "ImageStats" instead of "imageStats", but the
    % information is compatible, so no need to re-calculate
    imageStats = convertOld(ImageStats, metadata);
    clear ImageStats
    % save in the newer form
    saveImageStats = true;
  end
  if exist('imageStats', 'var')
    origin = imageStats.origin;
    if thisVersionNewer(version, imageStats.version)
      %If we have a new version of GetImageStats, re-do calculations
      fprintf(['Recalculating image stats because GetImageStats ', ...
        'version changed from %s to %s.\n'], ...
        imageStats.version, version)
      calcStats = true;
    end
  elseif exist('VoxelHist', 'var')
    % This is to provide compatability with VERY old versions of
    % GetImageStats.m   It should be removed soon, because it really only
    % adds bloat and confusion.
    origin = VoxelHist.Origin;
    origin(3) = -origin(3);    %The z dimension has been reversed
    fprintf(['Recalculating image stats because old stack pre-dates ', ...
             'version numbers.\n'])
    calcStats = true;
  else
    fprintf(['Recalculating image stats because old stack pre-dates ', ...
             'version numbers.\n'])
    calcStats = true;
  end
else
  calcStats = true;
end

if calcStats
  imageStats = calcImageStats(metadata, origin);
  imageStats.version = version;
  saveImageStats = ~strcmp(metadata.stackType, 'lei_mat');
end

if saveImageStats
  save(saveFileName, 'imageStats');
end

metadata.origin = imageStats.origin;
metadata.color = imageStats.color;
metadata.voxelStats = imageStats.voxelStats;
metadata.projections = imageStats.projections;
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function imageStats = convertOld(ImageStats, metadata)
imageStats.origin = ImageStats.Origin;
imageStats.voxelStats.hist = ImageStats.Voxels.Hist;
imageStats.voxelStats.blackLevel = ImageStats.Voxels.BlackLevel;
imageStats.voxelStats.whiteLevel = ImageStats.Voxels.WhiteLevel;
imageStats.voxelStats.noiseLevel = ImageStats.NoiseThresh;
imageStats.voxelStats.adjustScale = imageStats.voxelStats.whiteLevel / ...
  (imageStats.voxelStats.whiteLevel - imageStats.voxelStats.blackLevel);
projections.x.image = ImageStats.Projections.X;
projections.y.image = ImageStats.Projections.Y;
projections.z.image = ImageStats.Projections.Z;
projections.x.xPhysical = [0, metadata.physical(2)];
projections.x.yPhysical = [0, metadata.physical(3)];
projections.y.xPhysical = [0, metadata.physical(1)];
projections.y.yPhysical = [0, metadata.physical(3)];
projections.z.xPhysical = [0, metadata.physical(1)];
projections.z.yPhysical = [0, metadata.physical(2)];
imageStats.projections.max = projections;

imageStats.color = GetChannelColor(metadata);

imageStats.version = ImageStats.Version;
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function newer = thisVersionNewer(thisVersion, savedVersion)
if strcmp(thisVersion, savedVersion)
  newer = false;
  return
end

while ~(isempty(thisVersion) && isempty(savedVersion))
  [thisPart, thisVersion] = strtok(thisVersion, '.'); %#ok<STTOK>
  [savedPart, savedVersion] = strtok(savedVersion, '.'); %#ok<STTOK>
  if isempty(thisPart)
    thisNum = 0;
  else
    thisNum = str2double(thisPart);
  end
  if isempty(savedPart)
    savedNum = 0;
  else
    savedNum = str2double(savedPart);
  end
  if thisNum > savedNum
    newer = true;
    return;
  elseif thisNum < savedNum
    newer = false;
    return;
  end
end
newer = false;
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function imageStats = calcImageStats(metadata, origin)
% create a stack object so we can get image slices from the stack
stack = StackObj(metadata, true);

logical = stack.metadata.logical;
numZ = logical(3);
intTypeName = stack.metadata.intTypeName;

% Allocate space.  Don't need to allocate projections.z
projections.x.image = zeros(logical(3), logical(2), intTypeName);
projections.y.image = zeros(logical(3), logical(1), intTypeName);

% get the first slice
tempImage = stack.getSliceZ(1);

% calculate projections and some voxel histogram info
projections.x.image(1,:) = squeeze(max(tempImage, [], 2))';
projections.y.image(1,:) = squeeze(max(tempImage, [], 1));
projections.z.image = tempImage;
bins = 0:(stack.metadata.numVoxelLevels - 1);
voxelStats.hist = hist(tempImage(:), bins);

xImage = projections.x.image;
yImage = projections.y.image;
zImage = projections.z.image;
vHist = voxelStats.hist;
getZ = @stack.getSliceZ;

parBlock = ParallelBlock();
progStr = ['Calculating image statistics for ', metadata.stackSaveName];
ProgressBar(progStr, numZ - 1, 5, true)
parfor z = 2:numZ
  tempImage = feval(getZ, z);
  xImage(z,:) = squeeze(max(tempImage, [], 2))';
  yImage(z,:) = squeeze(max(tempImage, [], 1));
  zImage = max(zImage, tempImage);
  vHist = vHist + hist(tempImage(:), bins);
  ProgressBar(progStr)
end
parBlock.endBlock();

projections.x.image = xImage;
projections.y.image = yImage;
projections.z.image = zImage;
voxelStats.hist = vHist;
clear xImage yImage zImage vHist stack

% include data on the true physical size of these projection images
projections.x.xPhysical = [0, metadata.physical(2)];
projections.x.yPhysical = [0, metadata.physical(3)];
projections.y.xPhysical = [0, metadata.physical(1)];
projections.y.yPhysical = [0, metadata.physical(3)];
projections.z.xPhysical = [0, metadata.physical(1)];
projections.z.yPhysical = [0, metadata.physical(2)];

lowEnd = round(0.2 * bins(end));
[~, voxelStats.blackLevel] = max(voxelStats.hist(1:lowEnd));
voxelStats.whiteLevel = find(voxelStats.hist > 0, 1, 'last');
voxelStats.adjustScale = voxelStats.whiteLevel / ...
    (voxelStats.whiteLevel - voxelStats.blackLevel);
voxelStats.noiseLevel = -1;

imageStats.origin = origin;
imageStats.projections.max = projections;
imageStats.voxelStats = voxelStats;
imageStats.color = GetChannelColor(metadata);
return
