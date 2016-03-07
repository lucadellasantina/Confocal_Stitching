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
    function metadataObj = MetadataObj(stackFileName, varargin)
      % create a new MetadataObj associated with stackFileName
      %  if instead of opening existing data it is desired to create new
      %  stacks, pass a second parameter indicating the number of new
      %  stacks
      
      % this is a trick to allow resizing classObj as an array within the
      % constructor.  if the calling function is the constructor itself,
      % just allocate and return.
      callStack = dbstack;      
      if length(callStack) > 1 && ...
          strcmp(callStack(1).name, callStack(2).name)
        return
      end
      
      if nargin < 2
        numNewStacks = 0;
      else
        numNewStacks = varargin{1};
      end
      if ~FileExists(stackFileName) && numNewStacks < 1
        error('File %s not found.', stackFileName)
      end
      
      % get the stackType as the file type
      lastDotInd = find(stackFileName == '.', 1, 'last');
      newStackType = lower(stackFileName((lastDotInd+1):end));
      
      % create a handle to open this kind of metadata.  This function must
      % be defined for each stack type that can be opened.
      % INPUTS:
      %  stackFileName
      % OUTPUT:
      %  array of structs with the same fields a a metadataObj, one struct
      %  for each stack (unique series, channel combo) in the file.
      %  It should set the values of all neccessary metadata (at least
      %  everything but miscInfo)
      %  It must also add function handles to metadata.handles:
      %   intType(sliceImage)
      %   setSliceZ(sliceNum, sliceImage)
      %   getSliceX(sliceNum, [optional] rect)
      %   getSliceY(sliceNum, [optional] rect)
      %   getSliceZ(sliceNum, [optional] rect)
      metadataOpenFunc = ...
        eval(['@OpenStack_', newStackType]);
      
      % call this function:
      try
        metadataStructs = metadataOpenFunc(stackFileName, varargin{:});
      catch metadataOpenErr
        fprintf(2, 'Error opening metadata from file %s\n', stackFileName);
        rethrow(metadataOpenErr)
      end
    
      propertyNames = properties(metadataObj);
      n = length(metadataStructs);
      while n > 0
        struct_n = metadataStructs(n);
        if ~isfield(struct_n, 'stackSaveName')
          % make sure there's a stackSaveName in struct_n
          struct_n.stackSaveName = '';
        end
        
        for m = 1:length(propertyNames);
          % call constructor to make nth metadataObj, then set its
          %  properties, copying them from struct_n
          prop_m = propertyNames{m};
          metadataObj(n).(prop_m) = struct_n.(prop_m); %#ok<AGROW>
        end
        if isempty(metadataObj(n).stackSaveName)
          metadataObj(n).makeStackSaveName();
        end
        
        needImageStats = metadataObj(n).logical(3) > 1 && ...
          (metadataObj(n).readOnly || ...
           isempty(metadataObj(n).voxelStats) || ...
           isempty(metadataObj(n).projections));
        if needImageStats
          % get voxelStats, projections, and saved alterations to origin
          try
            GetImageStats(metadataObj(n));
            metadataObj(n).save();
            java.lang.System.gc()
          catch memErr
            if any(strfind(memErr.message, 'java.lang.OutOfMemoryError'))
              % too many java objects started cluttering java heap
              % try to clear that stuff out and continue
              tempFile = [tempdir, 'metadataTempFile.mat'];
              save(tempFile, 'metadataStructs', ...
                             'propertyNames', ...
                             'stackFileName')

              progHandles = findobj('-regexp', 'Name', ...
                                    'Calculating image statistics .*');
              for m = 1:length(progHandles)
                close(progHandles(m))
              end
              clear java
              tempFile = [tempdir, 'metadataTempFile.mat'];
              load(tempFile)
              delete(tempFile)
              n = length(metadataStructs);
              continue
            else
              throw memErr
            end
          end
          n = n - 1;
        end
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
        eval(sprintf('stack_%s = propStruct;', matName))
        % save the uniquely named structure
        if FileExists(propStruct.stackFileName)
          save(propStruct.stackFileName, matName, '-append')
        else
          save(propStruct.stackFileName, matName)
        end
      end
    end
  end
  methods (Access = protected)
    function fillFields(metadataObj)
      
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
    function matName = makeMatfileName(metadataObj)
      if ~isfield(metadataObj, 'stackSaveName')
        metadataObj.makeStackSaveName();
      end
      matName = ['stack_', metadataObj.stackSaveName];
    end
  end
end
