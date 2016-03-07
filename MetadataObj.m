classdef MetadataObj < handle
  properties (SetAccess = public)
    stackFileName   % name of file containing stack metadata
    stackPath       % path to stackFileName
    stackType       % typically extension of stackFileName
    readOnly        % boolean, can the stack be altered
    stackName       % name of this particular stack, series and channel
    stackSaveName   % simpler stack name, safe for use as a file name
    seriesNum       % number of the series this stack is a part of    
    seriesName      % name of the series this stack is a part of
    numChannels     % number of channels in this series
    channelNum      % index of this particular channel
    channelName     % name of this particular channel    
    intTypeName     % name of data type of voxels (e.g. uint8)
    numBits         % number of bits voxels are stored in on disk
    numVoxelLevels  % number of distinct values voxels may take
    logical         % array of length 3, number of voxels in each dimension
    physical        % array of length 3, physical length in each dimension
    origin          % array of length 3, physical location in each dim.
    time            % scan time
    
    sliceList       % may be used to hold file names and/or numbers to map
                    % desired slice on to slice storage organization
    
    color           % 1x3 array, RGB color values between 0 and 1, used for
                    % displaying the stack
                    
    voxelStats      % structure with statistics on voxel values
    projections     % structure with images of projections of this stack
    handles         % structure with various handles used to interface with
                    % the stack:
                    %   intType(image)
                    %   setSliceZ(sliceNum, sliceImage)
                    %   getSliceX(sliceNum, [optional] rect)
                    %   getSliceY(sliceNum, [optional] rect)
                    %   getSliceZ(sliceNum, [optional] rect)
    miscInfo        % structure with miscellaneous metadata    
  end
  %properties (SetAccess = protected)
  %  %
  %end
  methods
    % constructor
    function metadataObj = MetadataObj(metadataStruct)
      % construct a new MetadataObj
      if nargin < 1
        % it's empty
        return
      end
      
      propertyNames = properties(metadataObj);

      if ~isfield(metadataStruct, 'stackSaveName')
        % make sure there's a stackSaveName in metadataStruct
        metadataStruct.stackSaveName = '';
      end
      if ~isfield(metadataStruct, 'time')
        metadataStruct.time = metadataStruct.seriesNum;
      end

      for m = 1:length(propertyNames);
        % copy properties from metadataStruct
        prop_m = propertyNames{m};
        metadataObj.(prop_m) = metadataStruct.(prop_m);
      end
      if isempty(metadataObj.stackSaveName)
        % if a stackSaveName wasn't supplied, make one
        metadataObj.makeStackSaveName();
      end

      needImageStats = metadataObj.logical(3) > 1 && ...
        (isempty(metadataObj.voxelStats) || ...
         isempty(metadataObj.projections));
      if needImageStats
        % get voxelStats, projections, and saved alterations to origin
        GetImageStats(metadataObj);
        metadataObj.save();
      end
    end
 
    % delete
    function delete(metadataObj)
      % create a handle to delete this kind of metadata.
      % if it isn't necessary, simply don't implement this fuction.
      metadataDeleteFunc = ...
        eval(['@CloseStack_', metadataObj.stackType]);
      
      % call this function
      try
        metadataDeleteFunc(metadataObj);
      catch deleteErr
        if ~strcmp(deleteErr.identifier, 'MATLAB:UndefinedFunction')
          rethrow(deleteErr)
        end
      end
    end
    
    function save(metadataObj)
      if metadataObj.readOnly
        % read only, so save change-able parts in a ImageStats file
        imageStats.origin = metadataObj.origin;
        imageStats.voxelStats = metadataObj.voxelStats;
        imageStats.projections = metadataObj.projections;
        imageStats.color = metadataObj.color;
        imageStats.version = '1.0.3'; %#ok<STRNU>
        
        saveFileName = sprintf('%s%s_ImageStats.mat', ...
          metadataObj.stackPath, metadataObj.stackSaveName);
        save(saveFileName, 'imageStats');
      else
        % not read only, so save the whole thing
        propertyNames = properties(metadataObj);
        propStruct = struct();
        for m = 1:length(propertyNames);
          prop_m = propertyNames{m};
          if strcmp(prop_m, 'handles')
            continue
          end
          propStruct.(prop_m) = metadataObj.(prop_m);
        end
        
        % rename the propStruct structure to be unique to the stack
        matName = metadataObj.makeMatfileName();
        eval(sprintf('%s = propStruct;', matName))
        % save the uniquely named structure
        if FileExists(propStruct.stackFileName)
          save(propStruct.stackFileName, matName, '-append')
        else
          save(propStruct.stackFileName, matName)
        end
      end
    end
    
    function safeName = makeStackSaveName(metadataObj)
      % create a matlab-compatible variable name from the stack name
      safeName = [metadataObj.seriesName, '_', ...
                  sprintf('ch%0.2d', metadataObj.channelNum)];
      badCharInds = regexp(safeName, '\W');
      if ~isempty(badCharInds)
        safeName(badCharInds) = '_';
      end
      metadataObj.stackSaveName = safeName;
    end
    
    function safeName = makeOmeTiffName(metadataObj)
      % create a matlab-compatible ome.tiff name from the stack name
      safeName = metadataObj.seriesName;
      badCharInds = regexp(safeName, '\W');
      if ~isempty(badCharInds)
        safeName(badCharInds) = '_';
      end
      safeName = sprintf('%s%s.ome.tiff', metadataObj.stackPath, safeName);
    end
    
    function matName = makeMatfileName(metadataObj)
      if ~isfield(metadataObj, 'stackSaveName')
        metadataObj.makeStackSaveName();
      end
      matName = ['stack_', metadataObj.stackSaveName];
    end
  end
end
