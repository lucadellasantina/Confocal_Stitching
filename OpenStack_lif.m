function metadataStructs = OpenStack_lif(stackFileName)
% open a '.lei' stack using LOCI tools.

% first bring up the LOCI reader.  It must be global, because making too
% many fills up the (very small) java heap space
global readerLOCI;
global numLOCI;
if isempty(readerLOCI)
  % if it doesn't exist, create it
  readerLOCI = OpenWithBioFormats();
  numLOCI = 0;
end

seriesMetadata = getMetadata_lif(stackFileName, readerLOCI);

% loop through the series, adding fields and creating one metadata object
% for each channel
metadataStructs = [];
numScans = length(seriesMetadata);
readerLOCI.setId(stackFileName);
ProgressBar('Populating metadata', numScans)
for scanNum = 1:numScans
  metadata = seriesMetadata(scanNum);
  metadata.numBits = readerLOCI.getBitsPerPixel();
  metadata.intTypeName = sprintf('uint%d', 8 * ceil(metadata.numBits / 8));
  metadata.numVoxelLevels = 2^metadata.numBits;
  metadata.voxelStats = [];
  metadata.projections = [];
  
  readerLOCI.setSeries(metadata.seriesNum);
  for chanNum = 0:(metadata.numChannels-1)
    chanMetadata = metadata;
    chanMetadata.channelNum = chanNum;

    if length(metadata.miscInfo.detector) < metadata.numChannels
      chanMetadata.channelName = ...
        sprintf('ch%0.2d', chanNum);
    else
      % set the detector to only the one corresponding to this channel
      chanMetadata.miscInfo.detector = ...
        metadata.miscInfo.detector(chanNum+1);
      % set channelName, using the stain name in detector if available
      if isempty(chanMetadata.miscInfo.detector.stain)
        chanMetadata.channelName = sprintf('ch%0.2d', chanNum);
      else
        chanMetadata.channelName = chanMetadata.miscInfo.detector.stain;
      end
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
  ProgressBar('Populating metadata')
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dispKey(keyName, keyVal) %#ok<DEFNU>
if ischar(keyVal)
  fprintf('%s :: %s\n', keyName, keyVal)
else
  fprintf('%s :: %g\n', keyName, keyVal)
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function metadata = getMetadata_lif(stackFileName, readerLOCI)

% get the path to the stackFile
lastSepInd = find(stackFileName == filesep, 1, 'last');
if isempty(lastSepInd)
  lastSepInd = length(stackFileName);
end
stackPath = stackFileName(1:lastSepInd);
stackFile = stackFileName((lastSepInd+1):end);

% open the stack file using the LOCI reader
readerLOCI.setId(stackFileName);

numSeries = readerLOCI.getSeriesCount();
metadataStore = readerLOCI.getMetadataStore();

seriesNames = cell(1, numSeries);
% create the structure for each series
for seriesNum = 0:(numSeries - 1)
  sName = metadataStore.getImageName(seriesNum);
  seriesName = char(sName);
  sName = 0; %#ok<NASGU>
  clear sName
  
  metadata_n = struct();
  % set values that are true for all stacks in this file
  metadata_n.stackFileName = stackFileName;
  metadata_n.stackPath = stackPath;
  metadata_n.stackType = 'lif';
  metadata_n.readOnly = true;
  % series-identifying values
  metadata_n.seriesName = seriesName;
  metadata_n.seriesNum = seriesNum;
  
  % set some fields to fill in
  readerLOCI.setSeries(seriesNum);
  metadata_n.numChannels = readerLOCI.getSizeC();
  metadata_n.numT = readerLOCI.getSizeT(); 
  metadata_n.time = NaN; % preliminary, will be overwritten later
  metadata_n.logical = ...
    [readerLOCI.getSizeX(), readerLOCI.getSizeY(), readerLOCI.getSizeZ()];
  metadata_n.physical = [1.0, 1.0, 1.0];
  metadata_n.origin = [1.0, 1.0, 1.0];
  metadata_n.numBits = [];
  metadata_n.miscInfo = [];
  
  % these are helper structs to keep track of detectors, sequential
  % settings, and lasers
  % detectors lists all detector information for a given series
  scan_n.detectors = repmat( ...
    struct('number', [], 'sequenceNum', [], 'isActive', [], ...
          'lowWavelength', [], 'highWavelength', [], ...
          'gain', [], 'offset', [], 'highVoltage', [], 'stain', []), 0);
  % sequential settings keeps track of which detectors are active, as well
  % as detector settings (gain, etc) for each sequential scan. They need
  % to be processed after a first pass through the metadata
  scan_n.sequential = repmat(scan_n.detectors, [0,0]);
  scan_n.sequentialKeys = [];
  scan_n.sequentialVals = [];
  % lasers is mostly useless, has some info about wavelengths
  scan_n.lasers = [];
  
  % these are helper structs to do get the units right on physical stack
  % info (Origin and Physical)
  want_n.Unit = [true, true, true, false, false];
  want_n.Length = [true, true, true, false, false];
  want_n.Origin = [true, true, true, false, false];
  
  % add this to the list
  seriesNames{seriesNum + 1} = seriesName;
  if seriesNum == 0
    metadata = repmat(metadata_n, 1, numSeries);
    want = repmat(want_n, 1, numSeries);
    scan = repmat(scan_n, 1, numSeries);
  else
    metadata(seriesNum + 1) = metadata_n;
    want(seriesNum + 1) = want_n;
    scan(seriesNum + 1) = scan_n;
  end
end
metadataStore = 0; %#ok<NASGU>
clear metadataStore

% loop through the keys to get the metadata
metadataLOCI = readerLOCI.getMetadata();
numKeys = metadataLOCI.size();
keys = metadataLOCI.keys();
progStr = sprintf('Scanning %s for metadata', stackFile);
ProgressBar(progStr, numKeys)
for n = 1:numKeys
  ProgressBar(progStr)
  key_n = keys.nextElement();
  
  if StringCheck(key_n, 'VariantType') || StringCheck(key_n, 'TimeStamp')
    %We never want this type of field
    continue
  end

  % find index of the series it points to, by seriesName
  ind = strfind(key_n, ' ') - 1;
  if isempty(ind)
    % no series name at all
    continue
  end
  [isSeries, sNum] = ismember(key_n(1:ind(1)), seriesNames);
  if ~isSeries
    % doesn't correspond to a series
    continue
  end

  % We're probably intersted in this key, get the key value
  keyVal = metadataLOCI.get(key_n);
  
  dispKey(key_n, keyVal)

  if StringCheck(key_n, 'nBit', true)
    metadata(sNum).numBits = sscanf(keyVal, '%d');
  elseif StringCheck(key_n, 'Dimension', true)
    % this key contains dimension size/position information
    ind = strfind(key_n, 'Dimension') + length('Dimension');
    dimNum = sscanf(key_n(end-1:end), '%d', 1) + 1;
    if isempty(dimNum)
      dimNum = sscanf(key_n(ind:end), '%g', 1) + 1;
      if isempty(dimNum)
        continue
      end
    end
    if StringCheck(key_n, 'Unit', true) && want(sNum).Unit(dimNum)
      % this is unit information, so convert values in physical and origin
      % to appropriate units
      switch keyVal
       case 'm', conFact = 1.0;
       case 'cm', conFact = 1.0e-2;
       case 'mm', conFact = 1.0e-3;
       case 'um', conFact = 1.0e-6;
       case 'nm', conFact = 1.0e-9;
       case '', warning('CONFOCAL:OpenStack_lif', ...
                        'Empty value for unit %s', key_n)
         continue
       case 'Pixel',
         if StringCheck(key_n, 'Snapshot', true)
           continue
         else
           error('Unknown unit type: %s = %s\n', key_n, keyVal)
         end
       otherwise, error('Unknown unit type:  %s = %s', key_n, keyVal)
      end
      % do the conversion
      metadata(sNum).physical(dimNum) = ...
        metadata(sNum).physical(dimNum) * conFact;
      metadata(sNum).origin(dimNum) = ...
        metadata(sNum).origin(dimNum) * conFact;
      % don't convert again accidentally
      want(sNum).Unit(dimNum) = false;
    elseif StringCheck(key_n, 'Length', true) && want(sNum).Length(dimNum)
      % this is the physical information, reported in some unknown units
      metadata(sNum).physical(dimNum) = ...
        metadata(sNum).physical(dimNum) * sscanf(keyVal, '%g');
      want(sNum).Length(dimNum) = false;
    elseif StringCheck(key_n, 'Origin', true) && want(sNum).Origin(dimNum)
      % this i the origin information, reported in some unknown units
      metadata(sNum).origin(dimNum) = ...
        metadata(sNum).origin(dimNum) * sscanf(keyVal, '%g');
      want(sNum).Origin(dimNum) = false;
    end
  elseif StringCheck(key_n, 'dblPinholeAiry', true)
    % this key contains information about pinhole size in Airy units
    metadata(sNum).miscInfo.pinholeAiry = sscanf(keyVal, '%g');
  elseif StringCheck(key_n, 'dblPinhole', true)
    % this key contains information about pinhole size in ? units (m?)
    metadata(sNum).miscInfo.pinhole = sscanf(keyVal, '%g');    
  elseif StringCheck(key_n, 'dblZoom', true)
    % this key contains information about zoom level
    metadata(sNum).miscInfo.zoom = sscanf(keyVal, '%g');
  elseif StringCheck(key_n, 'nAverageFrame')
    % this key contains information about frame averaging
    metadata(sNum).miscInfo.frameAverage = sscanf(keyVal, '%d');
  elseif StringCheck(key_n, 'nAverageLine', true)
    % this key contains information about line averaging
    metadata(sNum).miscInfo.lineAverage = sscanf(keyVal, '%d');
  elseif StringCheck(key_n, 'Objective - Variant', true) || ...
         StringCheck(key_n, '|Objective', true)
    % this key contains a description of the objective lens
    metadata(sNum).miscInfo.objective = keyVal;
  elseif StringCheck(key_n, 'NumericalAperture - Variant', true) || ...
         StringCheck(key_n, 'Numerical aperture', true)
    % this key contains numerical aperture value
    metadata(sNum).miscInfo.numericalAperture = str2double(keyVal);
  elseif StringCheck(key_n, 'RefractionIndex - Variant', true) || ...
         StringCheck(key_n, 'Refraction index', true)
    % this key contains refraction index (of what?)
    metadata(sNum).miscInfo.refractionIndex = str2double(keyVal);
  elseif StringCheck(key_n, 'System Type', true) || ...
         StringCheck(key_n, 'SystemType', true)
    % this key contains system type
    metadata(sNum).miscInfo.SystemType = keyVal;    
  elseif StringCheck(key_n, 'LaserLine', true) && ...
      StringCheck(key_n, 'LineIndex', true)
    % this key contains information about a laser wavelength
    ind = strfind(key_n, 'LaserLine') + ...
      length('LaserLine') + 1;
    wavelength = sscanf(key_n(ind:end), '%d', 1);
    if ~ismember(wavelength, scan(sNum).lasers)
      scan(sNum).lasers = [scan(sNum).lasers, wavelength]; 
    end
  elseif StringCheck(key_n, 'Laser wavelength', true)
    % this key contains information about a laser wavelength
    wavelength = sscanf(keyVal, '%g', 1);
    if ~ismember(wavelength, scan(sNum).lasers)
      scan(sNum).lasers = [scan(sNum).lasers, wavelength]; 
    end
  elseif StringCheck(key_n, 'SP Mirror Channel', true)
    % this key contains information about a detector mirror
    ind = strfind(key_n, 'SP Mirror Channel') + ...
      length('SP Mirror Channel') + 1;
    % get the detector number
    detectorNum = sscanf(key_n(ind(1):end), '%d', 1);
    if isempty(detectorNum)
      continue
    end
    % add the available information to the detector struct
    if StringCheck(key_n, '(left)', true)
      scan(sNum).detectors(detectorNum).lowWavelength = sscanf(keyVal, '%g'); 
    elseif StringCheck(key_n, '(right)', true)
      scan(sNum).detectors(detectorNum).highWavelength = sscanf(keyVal, '%g'); 
    elseif StringCheck(key_n, '(stain)', true)
      scan(sNum).detectors(detectorNum).stain = keyVal;
    end
  elseif StringCheck(key_n, 'Sequential Setting', true) && ...
      StringCheck(key_n, 'Channel', true)
    % this key contains information about detector use in a sequential
    % setting
    
    % get the index of the sequential setting
    ind = strfind(key_n, 'Sequential Setting') + ...
      length('Sequential Setting') + 1;
    sequenceNum = sscanf(key_n(ind(1):end), '%d', 1);
    while sequenceNum > length(scan(sNum).sequential)
      % if it's a new sequence, add room for it
      nextSetting = length(scan(sNum).sequential) + 1;
      scan(sNum).sequential(nextSetting).detectors = scan(sNum).detectors;
    end
    % get the index of the relevant detector
    ind = strfind(key_n, 'Channel') + length('Channel') + 1;
    detectorNum = sscanf(key_n(ind(1):end), '%d', 1);
    if isempty(detectorNum)
      continue
    end
    if scan(sNum).detectors(detectorNum).isActive && ...
       scan(sNum).detectors(detectorNum).sequenceNum ~= sequenceNum
      continue
    end

    % fill in the information in they key (gain, etc)
    if strcmp(key_n((end+1-length('Gain')):end), 'Gain')
      scan(sNum).detectors(detectorNum).gain = str2double(keyVal);
    elseif strcmp(key_n((end+1-length('Offset')):end), 'Offset')
      scan(sNum).detectors(detectorNum).offset = str2double(keyVal);
    elseif strcmp(key_n((end+1-length('DyeName')):end), 'DyeName')
      scan(sNum).detectors(detectorNum).stain = keyVal;
    elseif strcmp(key_n((end+1-length('IsActive')):end), 'IsActive')
      isActive = strcmp(keyVal, '1');
      if isActive
        scan(sNum).detectors(detectorNum).isActive = true;
        scan(sNum).detectors(detectorNum).number = detectorNum;
        scan(sNum).detectors(detectorNum).sequenceNum = sequenceNum;
      end
    end
  elseif StringCheck(key_n, '|PMT ', true)
    % describes information about a PMT
    
    % get the detector number
    searchInd = strfind(key_n, '|PMT ') + length('|PMT ');
    searchKey = key_n(searchInd(1):end);
    detectorNum = sscanf(searchKey, '%d', 1);
    if isempty(detectorNum)
      continue
    end

    if StringCheck(searchKey, '(HV)', true)
      scan(sNum).detectors(detectorNum).highVoltage = str2double(keyVal);
    elseif StringCheck(searchKey, '(Offs.)', true)
      scan(sNum).detectors(detectorNum).offset = str2double(keyVal);
    elseif strcmp(searchKey, sprintf('%d 0', detectorNum))
      scan(sNum).detectors(detectorNum).isActive = ...
        strcmp(keyVal, 'Active');
      scan(sNum).detectors(detectorNum).number = detectorNum;
      %scan(sNum).detectors(detectorNum).sequenceNum = detectorNum;
    end
  end
end

clear metadataLOCI
clear keys

% do some post-processing
for sNum = 1:numSeries
  if isfield(metadata(sNum).miscInfo, 'objective')
    matches = regexp(metadata(sNum).miscInfo.objective, ...
                     '(\d.*\d)x(\d.*\d)', 'match');
    if ~isempty(matches)
      matches = matches{end};
      xInd = find(matches == 'x', 1);
      metadata(sNum).miscInfo.lensMagnification = ...
        str2double(matches(1:(xInd-1)));
    end
  end

  % add the information in scan to miscInfo
  metadata(sNum).miscInfo.detector = ...
    getActiveDetectors(scan(sNum).detectors);
  metadata(sNum).miscInfo.lasers = sort(scan(sNum).lasers);

  % evidently third dimension is typically flipped(?)
  metadata(sNum).origin(3) = -metadata(sNum).origin(3);
  metadata(sNum).physical(3) = -metadata(sNum).physical(3);
  if metadata(sNum).physical(3) < 0
    metadata(sNum).origin(3) = ...
      metadata(sNum).origin(3) + metadata(sNum).physical(3);
    metadata(sNum).physical(3) = -metadata(sNum).physical(3);
    metadata(sNum).miscInfo.flipZ = true;
  else
    metadata(sNum).miscInfo.flipZ = false;
  end
end


% finally check the number of image times (the metadata will be identical,
% (except that it will have a different time)

% finally, if any images have multiple times, separate them and turn into
% distinct image stacks
if any([metadata.numT] > 1)
  % store old multiple-time version of metadata
  multiTime = metadata;
  % compute the number of time-separated stacks
  numFinalStacks = sum([metadata.numT]);
  % create structure that will hold them
  metadata = repmat(multiTime(1), [1, numFinalStacks]);
  
  newInd = 1;
  for oldInd = 1:length(multiTime)
    numT = multiTime(oldInd).numT;
    if numT <= 1
      % this image has only one time
      metadata(newInd) = multiTime(oldInd);
      metadata(newInd).time = 0;
      newInd = newInd + 1;
    else
      % this image has multiple times
      for t = 1:numT
        metadata(newInd) = multiTime(oldInd);
        metadata(newInd).time = t - 1;
        metadata(newInd).seriesName = ...
          sprintf('%s_scan%d', metadata(newInd).seriesName, t);
        newInd = newInd + 1;
      end
    end
  end
else
  for n = 1:length(metadata)
    metadata(n).time = 0;
  end
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function activeDetectors = getActiveDetectors(detectors)

if isempty(detectors)
  activeDetectors = [];
  return
end
activeDetectors = repmat(detectors(1), 0);
m = 1;
for n = 1:length(detectors)
  if detectors(n).isActive
    activeDetectors(m) = detectors(n);
    m = m + 1;
  end
end

sequenceNums = [activeDetectors.sequenceNum];
if ~any(isnan(sequenceNums))
  [~, sortInds] = sort(sequenceNums);
  activeDetectors = activeDetectors(sortInds);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function metadata = getSliceList_LOCI(metadata, readerLOCI)

% get the LOCI tools ready to get this slice
readerLOCI.setId(metadata.stackFileName);
readerLOCI.setSeries(metadata.seriesNum);

sliceList = zeros(metadata.logical(3), 1);

c = metadata.channelNum;
t = metadata.time;
numSlices = metadata.logical(3);
for sliceNum = 1:numSlices
  z = sliceNum - 1;
  sliceList(sliceNum) = readerLOCI.getIndex(z, c, t);
end

if metadata.miscInfo.flipZ
  metadata.sliceList = flipud(sliceList);
else
  metadata.sliceList = sliceList;
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function metadata = getHandles_LOCI(metadata)
metadata.handles.intType = @(arr) typecast(arr, metadata.intTypeName);
metadata.handles.setSliceZ = @(metadataObj, sliceNum, sliceImage) ...
  error('Leica stack files are read only');

metadata.handles.getSliceX = @getSliceX_LOCI;
metadata.handles.getSliceY = @getSliceY_LOCI;
metadata.handles.getSliceZ = @getSliceZ_LOCI;
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice = getSliceX_LOCI(metadata, sliceNum, rect)
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

if nargin < 3
  size1 = metadata.logical(2);
  size2 = metadata.logical(3);
  rect = [[0, size1]; [0, size2]];
else
  rect(:,1) = rect(:,1) - 1;  
  size1 = rect(1,2) - rect(1,1);
  size2 = rect(2,2) - rect(2,2);
end

% allocate slice
slice = zeros(size2, size1, metadata.intTypeName);

% extract pieces of slice, one z-value at a time
for n = 1:size2
  zSliceNum = metadata.sliceList(rect(2,1) + n);
  sliceArray = readerLOCI.openBytes(zSliceNum, ...
                                    sliceNum, rect(1,1), 1, size1, []);
  slice(n,:) = metadata.handles.intType(sliceArray);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice = getSliceY_LOCI(metadata, sliceNum, rect)

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

if nargin < 3
  size1 = metadata.logical(1);
  size2 = metadata.logical(3);
  rect = [[0, size1]; [0, size2]];
else
  rect(:,1) = rect(:,1) - 1;
  size1 = rect(1,2) - rect(1,1);
  size2 = rect(2,2) - rect(2,1);
end

% allocate slice
slice = zeros(size2, size1, metadata.intTypeName);

% extract pieces of slice, one z-value at a time
for n = 1:size2
  zSliceNum = metadata.sliceList(rect(2,1) + n);
  sliceArray = readerLOCI.openBytes(zSliceNum, ...
                                   rect(1,1), sliceNum, size1, 1, []);
  slice(n,:) = metadata.handles.intType(sliceArray);
end
return



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice = getSliceZ_LOCI(metadata, sliceNum, rect)

global readerLOCI;
global numLOCI;
if isempty(readerLOCI)
  % if it doesn't exist, create it
  readerLOCI = OpenWithBioFormats();
  numLOCI = 0;
end

readerLOCI.setId(metadata.stackFileName);
readerLOCI.setSeries(metadata.seriesNum);

if nargin < 3
  size1 = metadata.logical(1);
  size2 = metadata.logical(2);
  %sliceArray = readerLOCI.openBytes(metadata.sliceList(sliceNum));
  %slice = reshape(metadata.handles.intType(sliceArray), [size1, size2])';
  slice = reshape(metadata.handles.intType(...
                     readerLOCI.openBytes(metadata.sliceList(sliceNum)) ...
                                           ), ...
                  [size1, size2])';
else
  rect(:,1) = rect(:,1) - 1;  
  size1 = rect(1,2) - rect(1,1);
  size2 = rect(2,2) - rect(2,2);
  %sliceArray = readerLOCI.openBytes(metadata.sliceList(sliceNum), ...
  %                                 rect(1,1), rect(2,1), size1, size2, []);
  %slice = reshape(metadata.handles.intType(sliceArray), [size1, size2])';
  slice = reshape(metadata.handles.intType(...
                    readerLOCI.openBytes(metadata.sliceList(sliceNum), ...
                                rect(1,1), rect(2,1), size1, size2, []) ...
                                          ), ...
                              [size1, size2])';
end
return
