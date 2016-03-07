function projections = ProjectStack(stackList, styleStruct)
% projections = ProjectStack(stackList, styleStruct)
% Forms projection of 3d stacks according to parameters in
% styleStruct
%  INPUTS:
%   -stackList: list of stacks.  If only one stack, the
%       projection is done, and a depth-coded projection is possible.
%       If there is more than one (up to three), they are each assigned
%       a color channel and projected separately.
%   -SsyleStruct: structure with elements
%      -useColor: color-coded by depth
%      -toneMap: use tone-mapping to enhance dimmer features
%      -enhanceBlue: add some white to blue regions (helps make blue
%                    stand out more)
%      -xRange, -yRange, -zRange
%  OUTPUT:
%   -projection: structure with fields
%           -x, y, z:  projection images, suitable for saving or display

if nargin < 2
  styleStruct.numBits = 8;
  styleStruct.useColor = true;
  styleStruct.method = 'max';
  styleStruct.toneMap = true;
  logical = stackList(1).metadata.logical;
  styleStruct.xRange = [1, logical(1)];
  styleStruct.yRange = [1, logical(2)];
  styleStruct.zRange = [1, logical(3)];
end
styleStruct = addInfo(styleStruct, stackList);

if styleStruct.useColor
    colorProject(stackList, styleStruct);
else
  for n = 1:styleStruct.numChan
    greyScaleProject(stackList(n), styleStruct);
  end
end

projections.x = FormatProjection(stackList, styleStruct, 'x');
projections.y = FormatProjection(stackList, styleStruct, 'y');
projections.z = FormatProjection(stackList, styleStruct, 'z');
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function styleStruct = addInfo(styleStruct, stackList)
% set up styleStruct by adding a few extra fields that will be used later
metadata = stackList(1).metadata;
styleStruct.clean = false;
styleStruct.numVoxelLevels = metadata.numVoxelLevels;
styleStruct.numChan = length(stackList);
if styleStruct.numChan > 1
  styleStruct.useColor = false;
end
styleStruct.projField = styleStruct.method;
if styleStruct.useColor
  styleStruct.projField(1) = upper(styleStruct.projField(1));
  styleStruct.projField = ['color', styleStruct.projField];
end
if strcmp(styleStruct.projField, 'max')
  logical = stackList(1).metadata.logical;
  if any(styleStruct.xRange ~= [1, logical(1)]) || ...
      any(styleStruct.yRange ~= [1, logical(2)]) || ...
      any(styleStruct.zRange ~= [1, logical(3)])
    styleStruct.projField = 'maxSubstack';
  end
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function greyScaleProject(stack, styleStruct)
[projections, needProject] = ...
  allocateProjections(stack, styleStruct, false);
if ~needProject
  return
end
projStyle = styleStruct.method;
if strcmp(projStyle, 'standard_Deviation')
  tempSquare = zeros(size(projections.z.image));
end

rect = [styleStruct.xRange(1), styleStruct.xRange(2); ...
        styleStruct.yRange(1), styleStruct.yRange(2); ...
        styleStruct.zRange(1), styleStruct.zRange(2)];

projLogical = rect(:,2) - rect(:,1) + 1;
numZ = projLogical(3);
zLow = rect(3,1);
zHigh = rect(3,2);
rect = rect([1,2], :); %get rid of z-component of rect

maxVal = styleStruct.numVoxelLevels - 1;
%Loop through the slices, calculating the projections as we go
ProgressBar('Making Projections', zHigh - zLow + 1);
for n = zLow:zHigh
  tempImage = stack.getSliceZ(n, rect);
  
  switch projStyle
    case 'max',
      projX = squeeze(max(tempImage, [], 2));
      projY = squeeze(max(tempImage, [], 1));
    case 'sum',
      floatImage = double(tempImage);
      projX = squeeze(sum(floatImage, 2));
      projY = squeeze(sum(floatImage, 1));
    case 'standard_Deviation',
      floatImage = double(tempImage);      
      projX = squeeze(std(floatImage, 0, 2));
      projY = squeeze(std(floatImage, 0, 1));
    case 'transparency',
      floatImage = double(tempImage);      
      alpha = 0.2;
      trans = 1 - (alpha / maxVal) * floatImage;
    
      transX = [ones(projLogical(2),1), cumprod(trans(:,1:(end-1)), 2)];
      transY = [ones(1,projLogical(1)); cumprod(trans(1:(end-1),:), 1)];
      projX = squeeze(sum(transX .* floatImage, 2));
      projY = squeeze(sum(transY .* floatImage, 1));
    otherwise,
      error('%s is an invalid projection type', projStyle);
  end
  
  projections.x.image(n,:) = projX;
  projections.y.image(n,:) = projY;
  
  switch projStyle
   case 'max',
    projections.z.image = max(projections.z.image, tempImage);
   case 'sum',
    projections.z.image = projections.z.image + floatImage;
   case 'standard_Deviation',
    projections.z.image = projections.z.image + floatImage;
    tempSquare = tempSquare + floatImage.^2;
   case 'transparency',
    projections.z.image = projections.z.image .* trans + floatImage;
   otherwise,
    error('%s is an invalid projection type', projStyle);
  end
  ProgressBar('Making Projections');
end

switch projStyle
 case 'standard_Deviation',
  projections.z.image = ...
    sqrt((tempSquare - (projections.z.image.^2)./numZ) / (numZ - 1));
 otherwise, 
end

% projection complete, copy it into the appropriate metadata field
stack.metadata.projections.(styleStruct.projField) = projections;
stack.save();
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function projections = colorProject(stack, styleStruct)
[projections, needProject] = ...
  allocateProjections(stack, styleStruct, true);
if ~needProject
  return
end
projStyle = styleStruct.method;
if strcmp(projStyle, 'standard_Deviation')
  tempSquare = zeros(size(projections.z.image), 'double');
end

rect = [styleStruct.xRange(1), styleStruct.xRange(2); ...
        styleStruct.yRange(1), styleStruct.yRange(2); ...
	      styleStruct.zRange(1), styleStruct.zRange(2)];
projLogical = rect(:,2) - rect(:,1) + 1;
numZ = projLogical(3);
[xColors, yColors] = getXYColors(projLogical);
tempImage = zeros(projLogical(2), projLogical(1), 3, 'double');

maxVal = styleStruct.numVoxelLevels - 1;
%Loop through the slices, calculating the projections as we go
ProgressBar('Making Projections', rect(3,2) - rect(3,1) + 1);
for n = rect(3,1):rect(3,2)
  tempSlice = double(stack.getSliceZ(n, rect));
  
  tempImage(:,:,1) = tempSlice;
  tempImage(:,:,2) = tempSlice;
  tempImage(:,:,3) = tempSlice;
  
  switch projStyle
   case 'max',
    projX = squeeze(max(tempImage .* xColors, [], 2));
    projY = squeeze(max(tempImage .* yColors, [], 1));
   case 'sum',
    projX = squeeze(sum(tempImage .* xColors, 2));
    projY = squeeze(sum(tempImage .* yColors, 1));
   case 'standard_Deviation',
    projX = squeeze(std(tempImage .* xColors, 0, 2));
    projY = squeeze(std(tempImage .* yColors, 0, 1));
   case 'Transparency',
    alpha = .02;
    trans = 1 - alpha * tempImage / maxVal;
    
    transX = [ones(projLogical(2),1,3), cumprod(trans(:,1:(end-1),:), 2)];
    transY = [ones(1,projLogical(1),3); cumprod(trans(1:(end-1),:,:), 1)];
    projX = squeeze(sum(transX .* tempImage .* xColors, 2));
    projY = squeeze(sum(transY .* tempImage .* yColors, 1));
   otherwise,
    error('%s is an invalid projection type', projStyle);
  end

  projections.x.image(n,:,:) = projX;
  projections.y.image(n,:,:) = projY;

  zColor = getZColor(n - styleStruct.zRange(1), numZ);

  tempImage(:,:,1) = tempSlice * zColor(1);
  tempImage(:,:,2) = tempSlice * zColor(2);
  tempImage(:,:,3) = tempSlice * zColor(3);
  
  switch projStyle
   case 'max',
    projections.z.image = max(projections.z.image, tempImage);
   case 'sum',
    projections.z.image = projections.z.image + tempImage;
   case 'standard_Deviation',
    projections.z.image = projections.z.image + tempImage;
    tempSquare = tempSquare + tempImage.^2;
   case 'transparency',
    projections.z.image = projections.z.image .* trans + tempImage;
  end
  ProgressBar('Making Projections');
end

switch projStyle
 case 'standard_Deviation',
  projections.z.image = ...
    sqrt((tempSquare - (projections.z.image.^2)./numZ) / (numZ - 1));
 otherwise,
end

% projection complete, copy it into the appropriate metadata field
stack.metadata.projections.(styleStruct.projField) = projections;
stack.save();
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [projections, needProject] = ...
  allocateProjections(stack, styleStruct, useColor)
if nargin < 3
  useColor = false;
end

logical = stack.metadata.logical;
if useColor
  numColors = 3;
else
  numColors = 1;
end
projMins = ...
  [styleStruct.xRange(1), styleStruct.yRange(1), styleStruct.zRange(1)];
projMaxes = ...
  [styleStruct.xRange(2), styleStruct.yRange(2), styleStruct.zRange(2)];

projLogical = 1 + projMaxes - projMins;
physical = stack.metadata.physical;

physicalMins = physical .* ((projMins - 1) ./ logical);
physicalMaxes = physical .* (projMaxes ./ logical);

projections.x.image = [];
projections.x.xPhysical = [physicalMins(2), physicalMaxes(2)];
projections.x.yPhysical = [physicalMins(3), physicalMaxes(3)];
projections.y.image = [];
projections.y.xPhysical = [physicalMins(1), physicalMaxes(1)];
projections.y.yPhysical = [physicalMins(1), physicalMaxes(3)];
projections.z.image = [];
projections.z.xPhysical = [physicalMins(1), physicalMaxes(1)];
projections.z.yPhysical = [physicalMins(2), physicalMaxes(2)];

needProject = ~isfield(stack.metadata.projections, styleStruct.projField);
if ~needProject
  oldProj = stack.metadata.projections.(styleStruct.projField);
  % check to see if the projection ranges have changed
  if any(abs(projections.x.xPhysical - oldProj.x.xPhysical) > 1e-9) || ...
      any(abs(projections.x.yPhysical - oldProj.x.yPhysical) > 1e-9) || ...
      projLogical(3) ~= size(oldProj.x.image, 1) || ...
      projLogical(2) ~= size(oldProj.x.image, 2) || ...
      numColors ~= size(oldProj.x.image, 3) || ...
      any(abs(projections.y.xPhysical - oldProj.y.xPhysical) > 1e-9) || ...
      any(abs(projections.y.yPhysical - oldProj.y.yPhysical) > 1e-9) || ...
      projLogical(3) ~= size(oldProj.y.image, 1) || ...
      projLogical(1) ~= size(oldProj.y.image, 2) || ...
      numColors ~= size(oldProj.y.image, 3) || ...
      any(abs(projections.z.xPhysical - oldProj.z.xPhysical) > 1e-9) || ...
      any(abs(projections.z.yPhysical - oldProj.z.yPhysical) > 1e-9) || ...
      projLogical(2) ~= size(oldProj.z.image, 1) || ...
      projLogical(1) ~= size(oldProj.z.image, 2) || ...
      numColors ~= size(oldProj.z.image, 3)
    needProject = true;
  end
end
if ~needProject
  return
end

if useColor
  projections.x.image = zeros(projLogical(3), projLogical(2), 3, 'double');
  projections.y.image = zeros(projLogical(3), projLogical(1), 3, 'double');
  projections.z.image = zeros(projLogical(2), projLogical(1), 3, 'double');
else
  if strcmp(styleStruct.method, 'max')
    pixType = stack.metadata.intTypeName;
  else
    pixType = 'double';
  end
  projections.x.image = zeros(projLogical(3), projLogical(2), pixType);
  projections.y.image = zeros(projLogical(3), projLogical(1), pixType);
  projections.z.image = zeros(projLogical(2), projLogical(1), pixType);
end

return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [xColors, yColors] = getXYColors(logical)
xSize = logical(1);
ySize = logical(2);
xColors = zeros(xSize, 3);
yColors = zeros(ySize, 3);

halfX = xSize / 2;
for n = 1:xSize
  if n <= halfX   %Transitioning from Red to Green
    angle = (n - 1) / (halfX - 1) * pi / 2;
    color = [1,0,0] * cos(angle)^2 + [0,1,0] * sin(angle)^2;
  else                %Transitioning from Green to Blue
    angle = (n - halfX) / halfX * pi / 2;
    color = [0,1,0] * cos(angle)^2 + [0,0,1] * sin(angle)^2;
  end
  xColors(n,:) = color';
end

halfY = ySize / 2;
for n = 1:ySize
  if n <= halfY   %Transitioning from Red to Green
    angle = (n - 1) / (halfY - 1) * pi / 2;
    color = [1,0,0] * cos(angle)^2 + [0,1,0] * sin(angle)^2;
  else                %Transitioning from Green to Blue
    angle = (n - halfY) / halfY * pi / 2;
    color = [0,1,0] * cos(angle)^2 + [0,0,1] * sin(angle)^2;
  end
  yColors(n,:) = color';
end

xColors = permute(xColors, [3, 1, 2]); 
yColors = permute(yColors, [1, 3, 2]);
					
xColors = single(repmat(xColors, [ySize, 1, 1]));
yColors = single(repmat(yColors, [1, xSize, 1]));
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function color = getZColor(n, numZ)
zFrac = (n-1) / (numZ - 1);
if zFrac <= .5   %Transitioning from Red to Green
  angle = zFrac * pi / 2;
  color = [1,0,0] * cos(angle)^2 + [0,1,0] * sin(angle)^2;
else                %Transitioning from Green to Blue
  angle = (zFrac - .5) * pi / 2;
  color = [0,1,0] * cos(angle)^2 + [0,0,1] * sin(angle)^2;
end
color = single(color);
return
