function metadataStructs = OpenStack_lei(stackFileName)
% open a '.lei' stack using LOCI tools.

% first bring up the LOCI reader.  It must be global, because making too
% many fills up the (very small) java heap space
global numLOCI;
global readerLOCI;
if isempty(readerLOCI)
  readerLOCI = OpenWithBioFormats();
  numLOCI = 0;
end

% set some fields that are true for all stacks
metadata.stackFileName = stackFileName;
lastSepInd = find(stackFileName == filesep, 1, 'last');
if isempty(lastSepInd)
  lastSepInd = length(stackFileName);
end
metadata.stackPath = stackFileName(1:lastSepInd);
metadata.stackType = 'lei';
metadata.readOnly = true;

metadataStructs = [];
readerLOCI.setId(stackFileName);
numSeries = readerLOCI.getSeriesCount();
metadataStore = readerLOCI.getMetadataStore();
for seriesNum = 0:(numSeries - 1)
  % loop through each series
  readerLOCI.setSeries(seriesNum);
  % set seriesNum and seriesName
  metadata.seriesNum = seriesNum;
  sName = metadataStore.getImageName(seriesNum);
  metadata.seriesName = char(sName);
  clear sName
  
  % assign numBits, numChannels, logical, physical, origin, miscInfo:
  metadata = getSeriesData_lei(metadata, readerLOCI);
  metadata.intTypeName = sprintf('uint%d', 8 * ceil(metadata.numBits / 8));
  metadata.numVoxelLevels = 2^metadata.numBits;
  metadata.voxelStats = [];
  metadata.projections = [];
  for chanNum = 0:(metadata.numChannels-1)
    chanMetadata = metadata;
    chanMetadata.channelNum = chanNum;
    
    % set the detector to only the one corresponding to this channel
    chanMetadata.miscInfo.detector = ...
      metadata.miscInfo.detector([metadata.miscInfo.detector.number] == ...
      chanNum+1);
    % set channelName, using the stain name in detector if available
    if isempty(chanMetadata.miscInfo.detector) || ...
       isempty(chanMetadata.miscInfo.detector.stain)
      chanMetadata.channelName = ...
        sprintf('ch%0.2d', chanNum);
    else
      chanMetadata.channelName = chanMetadata.miscInfo.detector.stain;
    end
    % set the channel's draw color based on the detector
    chanMetadata.color = GetChannelColor(chanMetadata);
    
    % set stackName
    chanMetadata.stackName = ...
      [chanMetadata.seriesName, '_', chanMetadata.channelName];
    
    % assign sliceList
    chanMetadata = getSliceList_LOCI(chanMetadata, readerLOCI);
    
    % assign intType, setSliceZ, getSliceX, getSliceY, getSliceZ
    chanMetadata = getHandles_LOCI(chanMetadata);
    
    % add this metadata to the list
    metadataStructs = [metadataStructs, chanMetadata]; %#ok<AGROW>
    numLOCI = numLOCI + 1;
  end
end
clear metadataStore
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function metadata = getSeriesData_lei(metadata, readerLOCI)

% get the LOCI tools ready to get this slice
readerLOCI.setId(metadata.stackFileName);
readerLOCI.setSeries(metadata.seriesNum);

% assign numBits, numChannels, logical, physical, origin, miscInfo
% NOTE:  currently miscInfo is really not being used here.  Probably should
% fix that.
seriesID = sprintf('Series %d ', metadata.seriesNum);
metadata.numBits = [];  % this should be discovered
metadata.numChannels = readerLOCI.getSizeC();
metadata.logical = ...
  [readerLOCI.getSizeX(), readerLOCI.getSizeY(), readerLOCI.getSizeZ()];

rawPhysical = [1.0, 1.0, 1.0, 1.0, 1.0];
rawOrigin = [1.0, 1.0, 1.0, 1.0, 1.0];
% we map to which dimension NUMBER corresponds to which dimension NAME
%  (e.g. 'x', 'y', 'z')
dimMap = [-1, -1, -1, -1, -1];

miscInfo = struct();
detectors = struct('number', NaN, 'isActive', false, ...
                   'lowWavelength', NaN, 'highWavelength', NaN, ...
                   'gain', NaN, 'offset', NaN, 'stain', '');
metadataLOCI = readerLOCI.getMetadata();
numKeys = metadataLOCI.size();

% loop through the keys to get metadata
keys = metadataLOCI.keys();
for n = 1:numKeys
  key_n = keys.nextElement();
  if ~isWantedSeries(key_n, seriesID)
    % this key doesn't correspond to the series we want.  Skip it
    continue
  elseif StringCheck(key_n, 'Timestamp')
    % there are lots of time stamps, we don't want them either
    continue
  end

  keyVal = metadataLOCI.get(key_n);
  
  if StringCheck(key_n, 'nBit', true)
    metadata.numBits = sscanf(keyVal, '%d');
  elseif StringCheck(key_n, 'Dim')
    % this key contains dimension size/position information
    ind = strfind(key_n, 'Dim') + length('Dim');
    dimNum = sscanf(key_n(ind:end), '%g', 1) + 1;
    if StringCheck(key_n, 'Unit')
      % this is unit information, so convert values in physical and origin
      % to appropriate units
      switch keyVal
       case 'm', conFact = 1.0;
       case 'cm', conFact = 1.0e-2;
       case 'mm', conFact = 1.0e-3;
       case 'um', conFact = 1.0e-6;
       case 'nm', conFact = 1.0e-9;
       otherwise, error('Unknown unit type:  %s: %s', key_n, keyVal)
      end
      rawPhysical(dimNum) = rawPhysical(dimNum) * conFact;
      rawOrigin(dimNum) = rawOrigin(dimNum) * conFact;
    elseif StringCheck(key_n, 'length')
      % this is the physical information, reported in some unknown units
      rawPhysical(dimNum) = rawPhysical(dimNum) * sscanf(keyVal, '%g');
    elseif StringCheck(key_n, 'origin')
      % this i the origin information, reported in some unknown units
      rawOrigin(dimNum) = rawOrigin(dimNum) * sscanf(keyVal, '%g');
    elseif StringCheck(key_n, 'type')
      % this key-value pair contains information about how the mapping from
      % dimension NAME to dimension NUMBER
      switch keyVal
        case 'x', dimMap(1) = dimNum;
        case 'y', dimMap(2) = dimNum;
        case 'z', dimMap(3) = dimNum;
        case 'channel', dimMap(4) = dimNum;
        otherwise, dimMap(5) = dimNum;
      end
    end
  elseif StringCheck(key_n, 'Turret|Objective|', true)
    % this key contains information about the objective
    miscInfo.objective = keyVal;
  elseif StringCheck(key_n, 'dblPinholeAiry', true)
    % this key contains information about pinhole size in Airy units
    miscInfo.pinholeAiry = sscanf(keyVal, '%g');
  elseif StringCheck(key_n, 'dblPinhole', true)
    % this key contains information about pinhole size in ? units (m?)
    miscInfo.pinhole = sscanf(keyVal, '%g');    
  elseif StringCheck(key_n, 'dblZoom', true)
    % this key contains information about zoom level
    miscInfo.zoom = sscanf(keyVal, '%g');
  elseif StringCheck(key_n, 'nAverageFrame')
    % this key contains information about frame averaging
    miscInfo.frameAverage = sscanf(keyVal, '%d');
  elseif StringCheck(key_n, 'nAverageLine', true)
    % this key contains information about line averaging
    miscInfo.lineAverage = sscanf(keyVal, '%d');
  elseif StringCheck(key_n, '|Beam Expander|', true)
    % this key contains information about beam expander
    miscInfo.beamExpander = keyVal;
  elseif StringCheck(key_n, 'PMT', true)
    % this key contains information about a Petector PMT
    ind = strfind(key_n, 'PMT') + length('PMT') + 1;
    detectorNum = sscanf(key_n(ind:end), '%d', 1);
    if isempty(detectorNum)
      continue
    end
    [oldDetector, ind] = ismember(detectorNum, [detectors.number]);
    if ~oldDetector
     detectors = [detectors, detectors(1)]; %#ok<AGROW>
      ind = length(detectors);
      detectors(ind).number = detectorNum;      
    end
    if StringCheck(key_n, 'State', true)
      detectors(ind).isActive = strcmp(keyVal, 'Active');
    end
  elseif StringCheck(key_n, 'SP Mirror', true)
    % this key contains information about a detector mirror
    ind = strfind(key_n, 'SP Mirror') + length('SP Mirror') + 1;
    detectorNum = sscanf(key_n(ind:end), '%d', 1);
    [oldDetector, ind] = ismember(detectorNum, [detectors.number]);
    if ~oldDetector
     detectors = [detectors, detectors(1)]; %#ok<AGROW>
      ind = length(detectors);
      detectors(ind).number = detectorNum;
    end
    if StringCheck(key_n, 'Wavelength|0', true)
      detectors(ind).lowWavelength = sscanf(keyVal, '%g'); 
    elseif StringCheck(key_n, 'Wavelength|1', true)
      detectors(ind).highWavelength = sscanf(keyVal, '%g'); 
    elseif StringCheck(key_n, '|Stain|', true)
      detectors(ind).stain = keyVal;
    end
  end
end

% do some post-processing after looping through the metadata
if isfield(miscInfo, 'objective') && ~isempty(miscInfo.objective)
  matches = regexp(miscInfo.objective, '(\d.*\d)x(\d.*\d)', 'match');
  if ~isempty(matches)
    matches = matches{end};
    xInd = find(matches == 'x', 1);
    miscInfo.lensMagnification = str2double(matches(1:(xInd-1)));
    miscInfo.numericalAperture = str2double(matches((xInd+1):end));
  end
end

miscInfo.detector = detectors([detectors.isActive]);

% remap dimension so that x = 1, y = 2, z = 3

if any(dimMap(1:3) < 0)
  % just a snapshot
  physical = zeros(1,3);
  origin = zeros(1,3);
  validInd = dimMap > 0;
  physical(validInd) = rawPhysical(dimMap(validInd));
  origin(validInd) = rawOrigin(dimMap(validInd));
  miscInfo.flipZ = false;
else  
  physical = rawPhysical(dimMap(1:3));
  origin = rawOrigin(dimMap(1:3));
  
  % evidently third dimension is typically flipped(?)
  origin(3) = -origin(3);
  physical(3) = -physical(3);
  if physical(3) < 0
    origin(3) = origin(3) + physical(3);
    physical(3) = -physical(3);
    miscInfo.flipZ = true;
  else
    miscInfo.flipZ = false;
  end
end

metadata.physical = physical;
metadata.origin = origin;
metadata.time = 0;
metadata.miscInfo = miscInfo;
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function isWanted = isWantedSeries(keyName, seriesID)
isWanted = length(keyName) > length(seriesID) && ...
  strcmp(keyName(1:length(seriesID)), seriesID);
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function metadata = getSliceList_LOCI(metadata, readerLOCI)

% get the LOCI tools ready to get this slice
readerLOCI.setId(metadata.stackFileName);
readerLOCI.setSeries(metadata.seriesNum);

sliceList = zeros(metadata.logical(3), 1);
for sliceNum = 0:(metadata.numChannels * metadata.logical(3) - 1)
  zctCoords = readerLOCI.getZCTCoords(sliceNum);
  chanNum = zctCoords(2);
  if chanNum == metadata.channelNum
    sliceList(zctCoords(1) + 1) = sliceNum;
  end
end
if metadata.miscInfo.flipZ
  metadata.sliceList = flipud(sliceList);
else
  metadata.sliceList = sliceList;
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function metadata = getHandles_LOCI(metadata)
metadata.handles.intType = eval(['@', metadata.intTypeName]);
metadata.handles.setSliceZ = @(metadataObj, sliceNum, sliceImage) ...
  error('Leica stack files are read only');

metadata.handles.getSliceX = @getSliceX_LOCI;
metadata.handles.getSliceY = @getSliceY_LOCI;
metadata.handles.getSliceZ = @getSliceZ_LOCI;
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice = getSliceX_LOCI(metadata, sliceNum, rect)
if nargin < 4
  size1 = metadata.logical(2);
  size2 = metadata.logical(3);
  rect = [[0, size1]; [0, size2]];
else
  rect(:,1) = rect(:,1) - 1;  
  size1 = rect(1,2) - rect(1,1);
  size2 = rect(2,2) - rect(2,2);
end

global readerLOCI;
global numLOCI;
if isempty(readerLOCI)
  % if it doesn't exist, create it
  readerLOCI = OpenWithBioFormats();
  numLOCI = 0;
end

% get the LOCI tools ready to get this slice
readerLOCI.setId(metadata.stackFileName);
readerLOCI.setSeries(metadata.seriesNum);

% allocate slice
slice = zeros(size2, size1, metadata.intTypeName);

% extract pieces of slice, one z-value at a time
for n = 1:size2
  zSliceNum = metadata.sliceList(rect(2,1) + n);
  imageObj = readerLOCI.openImage(zSliceNum);
  pixelsLOCI = imageObj.getData.getPixels(sliceNum, rect(1,1), ...
                                          1, size1, []);
  slice(n,:) = pixelsLOCI;
  clear imageObj
  clear pixelsLOCI
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice = getSliceY_LOCI(metadata, sliceNum, rect)
if nargin < 4
  size1 = metadata.logical(1);
  size2 = metadata.logical(3);
  rect = [[0, size1]; [0, size2]];
else
  rect(:,1) = rect(:,1) - 1;
  size1 = rect(1,2) - rect(1,1);
  size2 = rect(2,2) - rect(2,1);
end

global readerLOCI;
global numLOCI;
if isempty(readerLOCI)
  % if it doesn't exist, create it
  readerLOCI = OpenWithBioFormats();
  numLOCI = 0;
end

% get the LOCI tools ready to get this slice
readerLOCI.setId(metadata.stackFileName);
readerLOCI.setSeries(metadata.seriesNum);

% allocate slice
slice = zeros(size2, size1, metadata.intTypeName);

% extract pieces of slice, one z-value at a time
for n = 1:size2
  zSliceNum = metadata.sliceList(rect(2,1) + n);
  imageObj = readerLOCI.openImage(zSliceNum);
  pixelsLOCI = imageObj.getData.getPixels(rect(1,1), sliceNum, ...
                                          size1, 1, []);
  slice(n,:) = pixelsLOCI;
  clear imageObj
  clear pixelsLOCI
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice = getSliceZ_LOCI(metadata, sliceNum, rect)
if nargin < 4
  size1 = metadata.logical(1);
  size2 = metadata.logical(2);
  rect = [[0, size1]; [0, size2]];
else
  rect(:,1) = rect(:,1) - 1;  
  size1 = rect(1,2) - rect(1,1);
  size2 = rect(2,2) - rect(2,2);
end

global readerLOCI;
global numLOCI;
if isempty(readerLOCI)
  % if it doesn't exist, create it
  readerLOCI = OpenWithBioFormats();
  numLOCI = 0;
end

readerLOCI.setId(metadata.stackFileName);
readerLOCI.setSeries(metadata.seriesNum);
imageObj = readerLOCI.openImage(metadata.sliceList(sliceNum));

% extract and reshape the slice info we want
pixelsLOCI = imageObj.getData.getPixels(rect(1,1), rect(2,1), ...
                             size1, size2, []);
slice = reshape(metadata.handles.intType(pixelsLOCI), [size1, size2])';
clear imageObj
clear pixelsLOCI
return
