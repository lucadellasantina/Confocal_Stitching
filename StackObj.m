classdef StackObj < handle
  properties (SetAccess = public)
    image      % used to store full 3D image for non-virtual stacks
    metadata   % object containing detailed information about the stack
    isVirtual  % boolean
    needsSave  % boolean, true if non-virtual stack has been altered from
               % disk
  end
  %properties (SetAccess = protected)
  %  %
  %end
  methods
    % constructor
    function stackObj = StackObj(input, forceVirtual, varargin)
      % stackObj = StackObj(stackFileName, forceVirtual, numNewStacks)
      %    or
      % stackObj = StackObj(metadataObj, forceVirtual)
      % create a new StackObj
      %  INPUT
      %   -stackFileName: file name associated with stack information
      %   -forceVirtual:  boolean, don't try to load stack into memory
      %   OPTIONAL:
      %   -numNewStacks: if > 0, create a number of new stacks and
      %                  associate them with stackFileName.  Don't try to
      %                  load in existing data
      
      % this is a trick to allow resizing classObj as an array within the
      % constructor.  if the calling function is the constructor itself,
      % just allocate and return.
      callStack = dbstack;      
      if length(callStack) > 1 && ...
          strcmp(callStack(1).name, callStack(2).name)
        return
      end      

      if nargin < 2
        % by default, the stack will open non-virtual if there is enough
        % memory
        forceVirtual = false;
      end
      
      % create and initialize a new StackObj
      if ischar(input)
        % input is a file that contains stack information
        metadataList = OpenMetadata(input, varargin{:});
      elseif isa(input, 'MetadataObj')
        % input is a MetadataObj so just copy it in
        metadataList = input;
      else
        error('Invalid input of type %s', class(input))
      end
      
      % some metadata corresponds to snapshots.  We only want true stacks,
      % corresponding to images with logical(3) > 1
      goodMetadata = [];
      for n = 1:length(metadataList)
        if metadataList(n).logical(3) > 1 || ~isempty(varargin)
          goodMetadata = [goodMetadata, metadataList(n)]; %#ok<AGROW>
        end
      end
      clear metadataList;

      for n = length(goodMetadata):-1:1
        % create list of stack objects
        stackObj(n).metadata = goodMetadata(n);
        stackObj(n).isVirtual = forceVirtual;
      end
      
      for n = 1:length(stackObj)
        % initialize stackObj.image and getSlice functions
        stackObj(n).open();
      end
    end
 
    % other class-specific functions
    % callable methods:
    %   open()
    %   loadStackImage()
    %   save()
    % protected methods:  (well, SHOULD be protected)
    %   setSliceZNonVirtual(sliceNum, sliceImage)
    %   getSlizeXNonVirtual(sliceNum, rect)
    %   getSlizeYNonVirtual(sliceNum, rect)
    %   getSlizeZNonVirtual(sliceNum, rect)    
    
    function open(stackObj)
      % initialize stackObj.image     
      if ~stackObj.isVirtual
        % try to load this stack into memory
        stackObj.loadStackImage();
      else
        stackObj.image = [];
      end
      % just opened stack, so stackObj agrees with disk
      stackObj.needsSave = false;
    end
    
    function success = loadStackImage(stackObj)
      % try to load this stack into memory.
      %  on success, set isVirtual = false and return true
      %  of failure, set isVirtual = true and return false
      logical = stackObj.metadata.logical;
      try
        fullImage = zeros(logical(2), logical(1), logical(3), ...
                          stackObj.metadata.intTypeName);
      catch loadErr
        % didn't work, so keep using the stack virtually
        fprintf('Stack %s will be opened virtually.\n', ...
          stackObj.metadata.stackName);
        fprintf(loadErr.message);
        stackObj.image = [];
        stackObj.isVirtual = true;
        success = false;
        return
      end
      
      % load each slice
      getZ = @stackObj.getSliceZ;
      parBlock = ParallelBlock();
      ProgressBar('Loading stack into memory', logical(3));
      parfor sliceNum = 1:logical(3)
        fullImage(:,:,sliceNum) = feval(getZ, sliceNum);
        ProgressBar('Loading stack into memory');
      end
      parBlock.endBlock();
      stackObj.image = fullImage;
      
      stackObj.isVirtual = false;
      stackObj.needsSave = false;
      success = true;
    end
    
    function save(stackObj)
      stackObj.metadata.save();
      if ~stackObj.needsSave
        return
      end
      % this can only happen if stack is non-virtual, so use the virtual
      % stack interface stored in metadata to save the slices.
      
      % save each slice
      metadataObj = stackObj.metadata;
      for sliceNum = 1:metadataObj.logical(3);
        metadataObj.handles.setSliceZ(metadataObj, sliceNum, ...
                                      stackObj.image(:,:,sliceNum));
      end
    end
    
    % setting/getting slice functions
    function setSliceZ(stackObj, sliceNum, sliceImage)
      if stackObj.isVirtual
        metadataObj = stackObj.metadata;
        metadataObj.handles.setSliceZ(metadataObj, sliceNum, sliceImage);
      else
        stackObj.image(:,:,sliceNum) = sliceImage;
        stackObj.needsSave = true;
      end
    end
    
    function slice = getSliceX(stackObj, sliceNum, rect)
      if stackObj.isVirtual
        metadataObj = stackObj.metadata;
        if nargin < 3
          slice = metadataObj.handles.getSliceX(metadataObj, sliceNum);
        else
          slice = ...
            metadataObj.handles.getSliceX(metadataObj, sliceNum, rect);
        end
      else
        if nargin < 3
          slice = squeeze(stackObj.image(:,sliceNum,:))';
        else
          slice = squeeze(stackObj.image(rect(1,1):rect(1,2), sliceNum, ...
            rect(2,1):rect(2,2)))';
        end
      end
    end
    function slice = getSliceY(stackObj, sliceNum, rect)
      if stackObj.isVirtual
        metadataObj = stackObj.metadata;
        if nargin < 3
          slice = metadataObj.handles.getSliceY(metadataObj, sliceNum);
        else
          slice = ...
            metadataObj.handles.getSliceY(metadataObj, sliceNum, rect);
        end
      else
        if nargin < 3
          slice = squeeze(stackObj.image(sliceNum,:,:))';
        else
          slice = squeeze(stackObj.image(sliceNum,rect(1,1):rect(1,2), ...
            rect(2,1):rect(2,2)))';
        end
      end
    end
    function slice = getSliceZ(stackObj, sliceNum, rect)
      if stackObj.isVirtual
        metadataObj = stackObj.metadata;
        if nargin < 3
          slice = metadataObj.handles.getSliceZ(metadataObj, sliceNum);
        else
          slice = ...
            metadataObj.handles.getSliceZ(metadataObj, sliceNum, rect);
        end
      else
        if nargin < 3
          slice = stackObj.image(:,:,sliceNum);
        else
          slice = stackObj.image(rect(2,1):rect(2,2), ...
            rect(1,1):rect(1,2), sliceNum);
        end
      end
    end    
  end
end
