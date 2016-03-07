function image = FormatProjection(stackList, styleStruct, dimName, ...
                                  useStackColor)

if nargin < 4
  useStackColor = true;
end
set(gcbf,'Pointer','watch');

projField = styleStruct.projField;
projection = stackList(1).metadata.projections.(projField).(dimName);
xRange = projection.xPhysical * 1.0e6;  %convert from m to um
yRange = projection.yPhysical * 1.0e6;

deltaX = xRange(2) - xRange(1);
deltaY = yRange(2) - yRange(1);

ySize = size(projection.image, 1);
xSize = size(projection.image, 2);
numChannels = length(stackList);
numProjColors = size(projection.image, 3);
if numProjColors > 3
  set(gcbf,'Pointer','arrow');
  error('Too many colors in projection')
end
if nargin < 4
  useStackColor = (numProjColors == 1);
end
if ~useStackColor && numChannels > 1
  set(gcbf,'Pointer','arrow');
  error('Colored projections of more than one channel.')
end

densityX = xSize / deltaX;
densityY = ySize / deltaY;

neededX = round(densityY * deltaX);
neededY = round(densityX * deltaY);
imageXSize = max(xSize, neededX);
imageYSize = max(ySize, neededY);

if useStackColor
  numColors = 3;
  % convert all the different channel's projections into an RGB image
  image = zeros(imageYSize, imageXSize, numColors);
  for n = 1:numChannels
    metadata = stackList(n).metadata;
    projImage = ...
      rescaleImage(metadata.projections.(projField).(dimName).image, ...
                   neededY, neededX);
    for m = 1:numColors
      image(:,:,m) = image(:,:,m) + metadata.color(m) * projImage;
    end
  end
else
  % use the number of projection colors, unless it's 2, then bump up to 3
  if numProjColors == 2
    numColors = 3;
  else
    numColors = numProjColors;
  end
  image = zeros(imageYSize, imageXSize, numColors);
  for n = 1:numProjColors
    image(:,:,n) = rescaleImage(projection.image(:,:,n), neededY, neededX);
  end
  
  if numProjColors == 2
    % use magenta-green
    image(:,:,3) = image(:,:,1);
  end
end

%Boost color differences
if numColors == 3
  if styleStruct.toneMap
    %Convert Image to greyscale + color info, and boost color differences
    [intensity, image] = boostColorDiffs(image, styleStruct);
  
    %Boost contrast with histogram equalization
    intensity = doToneMap(intensity);
  
    %Convert back to RGB format
    image(:,:,1) = intensity .* image(:,:,1);
    image(:,:,2) = intensity .* image(:,:,2);
    image(:,:,3) = intensity .* image(:,:,3);
    
    %Blue tends to look too dark, so add some white to it.
    if styleStruct.enhanceBlue == 1
      image = image + repmat(image(:,:,3) * 0.3, [1 1 3]);
    end
    scaleFact = 1.0;
  else
    scaleFact = 1.0 / max(max(max(image)));
  end
elseif styleStruct.toneMap
  image = doToneMap(image);
  scaleFact = 1.0;
else
  scaleFact = 1.0 / max(max(image));
end

switch styleStruct.numBits
 case 8,
   scaleVal = 255;
   intType = @uint8;
 case 16,
   scaleVal = 65535;
   intType = @uint16;
 otherwise,
   set(gcbf,'Pointer','arrow');
   error('Invalid NumBits requested');
end
image = intType(image * (scaleVal * scaleFact));

image = addScaleBar(image, styleStruct.numBits, xRange, yRange);
set(gcbf,'Pointer','arrow');
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function rescaled = rescaleImage(image, neededY, neededX)
% Scale image dimensions to have the correct aspect ratio
xSize = size(image, 2);
ySize = size(image, 1);
if neededX > xSize
  xWanted = (1:neededX) * xSize / neededX;
  yWanted = (1:ySize)';
  rescaled = interp2(single(image), xWanted, yWanted, '*linear', 0);
elseif neededY > ySize
  xWanted = 1:xSize;
  yWanted = (1:neededY)' * ySize / neededY;
  rescaled = interp2(single(image), xWanted, yWanted, '*linear', 0);
else
  rescaled = single(image);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [intensity, image] = boostColorDiffs(image, styleStruct)

if styleStruct.numChan > 1
  %This saturates the top 1% of each color, putting them on equal
  %  footing before the tone mapping.
  im = image(:,:,1);
  imVals = sort(im(:));
  maxVal = imVals(round(0.99 * length(imVals)));
  if maxVal > 0
    image(:,:,1) = im / maxVal;
  end
  
  im = image(:,:,2);
  imVals = sort(im(:));
  maxVal = imVals(round(0.99 * length(imVals)));
  if maxVal > 0
    image(:,:,2) = im / maxVal;
  end
  
  im = image(:,:,3);
  imVals = sort(im(:));
  maxVal = imVals(round(0.99 * length(imVals)));
  if maxVal > 0
    image(:,:,3) = im / maxVal;
  end
  
  intensity = sum(image, 3);
  return
end

% Convert image to (intensity, redAngle, gbAngle) form
redGoal = 1.0 / 3.0;
blueGoal = 1.0 / 3.0;
colTol = 0.02;
halfPi = 0.5 * pi;

intensity = sum(image, 3);
nonzero = find(intensity > 0);
[row, col] = ind2sub(size(intensity), nonzero);
zInd = ones(size(row));
redInd = sub2ind(size(image), row, col, zInd);
greenInd = sub2ind(size(image), row, col, 2 * zInd);
blueInd = sub2ind(size(image), row, col, 3 * zInd);

image(redInd) = image(redInd) ./ intensity(nonzero);
image(greenInd) = image(greenInd) ./ intensity(nonzero);
image(blueInd) = image(blueInd) ./ intensity(nonzero);

startRedAngle = acos(sqrt(image(redInd))) / halfPi;
startGBAngle = atan2(sqrt(image(greenInd)), sqrt(image(blueInd))) / halfPi;

% Balance red
meanRed = mean(image(redInd));
pow = 1.0;
lastPow = 1.0;
lastMean = redGoal;
while abs(meanRed - redGoal) > colTol && ...
      abs(meanRed - lastMean) > 0.01 * colTol
  if meanRed > redGoal
    % Decrease pow
    if pow == 1.0 || lastMean > redGoal
      lastPow = pow;
      pow = pow * 0.5;
    else
      temp = lastPow;
      lastPow = pow;
      pow = 0.5 * (pow + temp);
    end
  else
    % Increase pow
    if pow == 1 || lastMean < redGoal
      lastPow = pow;
      pow = pow * 2.0;
    else
      temp = lastPow;
      lastPow = pow;
      pow = 0.5 * (pow + temp);
    end
  end
  redAngle = startRedAngle.^pow;
  
  image(redInd) = cos(halfPi * redAngle).^2;
  lastMean = meanRed;
  meanRed = mean(image(redInd));
end

image(greenInd) = 1 - image(redInd);

% Balance blue (don't care as much about green)
pow = 1.0;
lastPow = 1.0;
image(blueInd) = image(greenInd) .* (cos(halfPi * startGBAngle).^2);
meanBlue = mean(image(blueInd));
lastMean = blueGoal;
while abs(meanBlue - blueGoal) > colTol && ...
      abs(meanBlue - lastMean) > 0.01 * colTol
  if meanBlue > blueGoal
    % Decrease pow
    if pow == 1.0 || lastMean > blueGoal
      lastPow = pow;
      pow = pow * 0.5;
    else
      temp = lastPow;
      lastPow = pow;
      pow = 0.5 * (pow + temp);
    end
  else
    % Increase pow
    if pow == 1 || lastMean < blueGoal
      lastPow = pow;
      pow = pow * 2.0;
    else
      temp = lastPow;
      lastPow = pow;
      pow = 0.5 * (pow + temp);
    end
  end
  gbAngle = startGBAngle.^pow;
  
  image(blueInd) = image(greenInd) .* (cos(halfPi * gbAngle).^2);
  lastMean = meanBlue;
  meanBlue = mean(image(blueInd));
end

image(greenInd) = image(greenInd) - image(blueInd);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function image = doToneMap(image)
% Note:  this image is gray-scale intensities even if the projection is
%        color
dsi = DownSampleImage(image, 1.0 / 3);

numBins = max([256, round(0.01 * size(dsi, 1) * size(dsi, 2))]);
minVal = min(min(dsi));
maxVal = max(max(dsi));

vals = linspace(minVal, maxVal, numBins);

num = hist(dsi(:), vals);

lowRange = round(0.2 * numBins);
[~, cutInd] = max(num(1:lowRange));
cutInd = cutInd + 1;  %Go just past the max
cutVal = vals(cutInd);

%Allow user to interactively refine CutVal based on histogram.
cutVal = getCutValUI(num, vals, numBins, cutVal);
[~, cutInd] = min(abs(vals - cutVal));

%image(image(:) <= cutVal) = cutVal;

mapStyle = 'HistEqual';
switch mapStyle
 case 'Log',
  if cutVal > 0
    eps = cutVal * 1e-3;
  else
    eps = 1e-3;
  end
  image = log(image - cutVal + eps);
 case 'HistEqual',
  num(1:cutInd) = 0;
  cumNum = cumsum(num);
  cumNum = cumNum / cumNum(end);
  
  ind = find(dsi > 0);
  dsi(ind) = interp1(vals, cumNum, dsi(ind)) ./ dsi(ind);
  interpCols = linspace(1, size(dsi,2), size(image, 2));
  interpRows = linspace(1, size(dsi,1), size(image, 1))';

  image = image .* interp2(dsi, interpCols, interpRows);
  
 otherwise,
  image = sqrt(image - cutVal);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cutVal = getCutValUI(num, vals, tailStart, cutVal)
plotStop = min([2 * tailStart, length(num)]);
h = ToneMap(num(1:plotStop), vals(1:plotStop), cutVal);
uiwait(h);
cutVal = get(h, 'UserData');
close(h, 'force')
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function image = addScaleBar(image, numBits, xRange, yRange)
%Load scale bar bitmap
deltaX = abs(xRange(2) - xRange(1));
deltaY = abs(yRange(2) - yRange(1));

%Require Scale bar to take up less than 1/5 of one dimension
% less than 1/6 of the other dimension
smallRatio = 1/6;
bigRatio = 1/5;

barLengths = [1, 2, 5, 10, 20, 50, 100, 200, 500];
barHeights = barLengths * 300/1000;

n = find((barLengths < bigRatio * deltaX & ...
	  barHeights < smallRatio * deltaY) | ...
	 (barLengths < smallRatio * deltaX & ...
	  barHeights < bigRatio * deltaY), 1, 'last');
if isempty(n)
  n = 1;
end
barLength = barLengths(n);

mName = mfilename('fullpath');
slashes = find(mName == filesep);
mPath = mName(1:slashes(end));
scaleBarFile = sprintf('%sScaleBar%g.png', mPath, barLength);
  
switch numBits
 case 8,
  scaleVal = 255;
  scaleBarMap = uint8(imread(scaleBarFile));
 case 16,
  scaleVal = 65535;
  scaleBarMap = uint16(imread(scaleBarFile));
 otherwise,
  error('Invalid NumBits requested');
end
scaleBarMap = scaleVal * scaleBarMap;

%scale it to the correct size;
xImage = size(image, 2);
yImage = size(image, 1);
xSize = xImage / deltaX * barLength;
scaleFact = xSize / size(scaleBarMap, 2);
ySize = size(scaleBarMap, 1) * scaleFact;
xSize = round(xSize);
ySize = round(ySize);
scaleBarMap = ScaleBitMap(scaleBarMap, xSize, ySize);

%First find a part of the image that's relatively empty
sums = squeeze(sum(image, 3));
sums2 = zeros(size(sums));
sums2(1,:) = cumsum(sums(1,:));
for m = 2:yImage
  sums2(m,:) = sums2(m-1,:) + cumsum(sums(m,:));
end

patchX = round(xSize * 1.1);
patchY = round(ySize * 1.1);
sumY = yImage - patchY;
sumX = xImage - patchX;
minVal = Inf;
for m = 1:sumY
  for n = 1:sumX
    patchSum = sums2(m,n) + sums2(m+patchY-1,n+patchX-1) ...
      - sums2(m+patchY-1,n) - sums2(m,n+patchX-1);
    if patchSum < minVal
      minVal = patchSum;
      min_m = m;
      min_n = n;
    end
  end
end

%Next draw the scale bar on top of image
start_m = round(min_m + .05 * ySize);
stop_m = start_m + ySize - 1;
start_n = round(min_n + .05 * xSize);
stop_n = start_n + xSize - 1;
for m = start_m:stop_m
  for n = start_n:stop_n
    scaleBarVal = scaleBarMap(m-start_m+1, n-start_n+1);
    if scaleBarVal > 0
      image(m, n, :) = scaleBarVal;
    end
  end
end

return
