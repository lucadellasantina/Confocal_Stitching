function Save_OME_TIFF(stackList)
% eventually integrate directly into StitchStacks (probably makes more sense)


% Save a 5D matrix into an OME-TIFF using Bio-Formats library
%
% SYNOPSIS bfsave(I, outputPath)
%          bfsave(I, outputPath, dimensionsOrder)
%
% INPUT:
%       I - a 5D matrix containing the pixels data
%
%       outputPath - a string containing the location of the path where to
%       save the resulting OME-TIFF
%
%       dimensionOrder - optional. A string representing the dimension
%       order, Default: XYZCT.
%
% OUTPUT
%

% OME Bio-Formats package for reading and converting biological file formats.
%
% Copyright (C) 2012 - 2013 Open Microscopy Environment:
%   - Board of Regents of the University of Wisconsin-Madison
%   - Glencoe Software, Inc.
%   - University of Dundee
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as
% published by the Free Software Foundation, either version 2 of the
% License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, write to the Free Software Foundation, Inc.,
% 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

% Check loci-tools jar is in the Java path
%bfCheckJavaPath();

% Not using the inputParser for first argument as it copies data
%assert(isnumeric(I), 'First argument must be numeric');


%{
% List all values of DimensionOrder
dimensionOrderValues = ome.xml.model.enums.DimensionOrder.values();
dimensionsOrders = cell(numel(dimensionOrderValues), 1);
for i = 1 :numel(dimensionOrderValues),
    dimensionsOrders{i} = char(dimensionOrderValues(i).toString());
end

% Input check
ip = inputParser;
ip.addRequired('outputPath', @ischar);
ip.addOptional('dimensionOrder', 'XYZCT', @(x) ismember(x, dimensionsOrders));
ip.parse(outputPath, varargin{:});

dimensionOrderEnumHandler = ome.xml.model.enums.handlers.DimensionOrderEnumHandler();
dimensionOrder = dimensionOrderEnumHandler.getEnumeration(ip.Results.dimensionOrder);
%}
dimensionOrder = ome.xml.model.enums.DimensionOrder.XYZCT;

% sort stackList so that channels are in order
stackList = sortStacks(stackList);

% get first stack and its associated metadata
stackObj = stackList(1);
metaObj = stackObj.metadata;

% Create metadata for ome.tiff output
toInt = @(x) ome.xml.model.primitives.PositiveInteger(java.lang.Integer(x));
metadata = loci.formats.MetadataTools.createOMEXMLMetadata();
metadata.createRoot();
metaObj.seriesNum = 0
metadata.setImageID(metaObj.seriesName, metaObj.seriesNum);
metadata.setPixelsID(sprintf('Pixels:%02d', metaObj.seriesNum), ...
                     metaObj.seriesNum);
metadata.setPixelsBinDataBigEndian(java.lang.Boolean.TRUE, ...
                                   metaObj.seriesNum, metaObj.seriesNum);

% Set dimension order
metadata.setPixelsDimensionOrder(dimensionOrder, metaObj.seriesNum);

% Set pixels type
pixelTypeEnumHandler = ome.xml.model.enums.handlers.PixelTypeEnumHandler();
if strcmp(metaObj.intTypeName, 'single')
  pixelsType = pixelTypeEnumHandler.getEnumeration('float');
else
  pixelsType = pixelTypeEnumHandler.getEnumeration(metaObj.intTypeName);
end
metadata.setPixelsType(pixelsType, metaObj.seriesNum);

% Read pixels size from image and set it to the metadat
logical = metaObj.logical;
sizeX = logical(1);
sizeY = logical(2);
sizeZ = logical(3);
sizeC = metaObj.numChannels;
assert(sizeC == length(stackList), ...
       'Number of stacks doesn''t match number of channels')
sizeT = 1;  % assumption for now, was: size(I, find(ip.Results.dimensionOrder == 'T'));
metadata.setPixelsSizeX(toInt(sizeX), metaObj.seriesNum);
metadata.setPixelsSizeY(toInt(sizeY), metaObj.seriesNum);
metadata.setPixelsSizeZ(toInt(sizeZ), metaObj.seriesNum);
metadata.setPixelsSizeC(toInt(sizeC), metaObj.seriesNum);
metadata.setPixelsSizeT(toInt(sizeT), metaObj.seriesNum);

% Set channels ID and samples per pixel
for c = 1: sizeC
  stackObj = stackList(c);
  metaObj = stackObj.metadata;
  metaObj.seriesNum = 0
  assert(metaObj.channelNum == c - 1, 'stackList channels not in order')
  metadata.setChannelID(metaObj.channelName, metaObj.seriesNum, ...
                        metaObj.channelNum);
  metadata.setChannelSamplesPerPixel(toInt(1), metaObj.seriesNum, ...
                                     metaObj.channelNum);
end

% Here you can edit the function and pass metadata using the adequate set methods, e.g.
physical = metaObj.physical;
voxelSize = 1.0e6 * physical ./ logical;
metadata.setPixelsPhysicalSizeX(...
  ome.xml.model.primitives.PositiveFloat(java.lang.Double(voxelSize(1))), ...
  metaObj.seriesNum);
metadata.setPixelsPhysicalSizeY(...
  ome.xml.model.primitives.PositiveFloat(java.lang.Double(voxelSize(2))), ...
  metaObj.seriesNum);
metadata.setPixelsPhysicalSizeZ(...
  ome.xml.model.primitives.PositiveFloat(java.lang.Double(voxelSize(3))), ...
  metaObj.seriesNum);
%
% For more information, see http://trac.openmicroscopy.org.uk/ome/wiki/BioFormats-Matlab
%
% For future versions of this function, we plan to support passing metadata as
% parameter/key value pairs

% Create ImageWriter
%writer = loci.formats.ImageWriter();
writer = loci.formats.out.OMETiffWriter();

% think about enabling this if I know for sure planes will be written in
% sequential order (z1 -zN for chan1, then chan2 -> chanN for time1, time2, ...
writer.setWriteSequentially(true);
writer.setMetadataRetrieve(metadata);
outputPath = metaObj.makeOmeTiffName();
if exist(outputPath, 'file')
  % delete this file if it already exists
  delete(outputPath)
end
% without this, attempting to save bigger stacks (> 4 GB?) will crash:
%  unfortunately, *WITH* this, imagej cannot open stacks:
writer.setBigTiff(true);
writer.setCompression('LZW')
%writer.setCompression('JPEG-2000')
writer.setId(outputPath);


% Load conversion tools for saving planes
switch metaObj.intTypeName
  case {'int8', 'uint8'}
      getBytes = @(x) x(:);
  case {'uint16','int16'}
      getBytes = @(x) loci.common.DataTools.shortsToBytes(x(:), 0);
  case {'uint32','int32'}
      getBytes = @(x) loci.common.DataTools.intsToBytes(x(:), 0);
  case {'single'}
      getBytes = @(x) loci.common.DataTools.floatsToBytes(x(:), 0);
  case 'double'
      getBytes = @(x) loci.common.DataTools.doublesToBytes(x(:), 0);
end


% Save planes to the writer
saveMessage = 'Saving ome.tiff';
numSteps = sizeC * sizeZ * sizeT;
ProgressBar(saveMessage, numSteps);
for c = 1 : sizeC
  stackObj = stackList(c);
  metaObj = stackObj.metadata;
  metaObj.time = 0
  indexOffset = sizeZ * (metaObj.channelNum + metaObj.time * sizeC);
  for z = 1 : sizeZ
    index = z + indexOffset;

    writer.saveBytes(index - 1, getBytes(stackObj.getSliceZ(z)'));
    ProgressBar(saveMessage)
  end
end
writer.close();

return



function sortedStackList = sortStacks(stackList)
% sort the stackList so that the channels are in order
sortedStackList = stackList;
for c = 1:length(stackList)
  stackObj = stackList(c);
  metaObj = stackObj.metadata;
  sortedStackList(metaObj.channelNum + 1) = stackObj;
end
return
