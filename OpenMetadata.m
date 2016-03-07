function metadataList = OpenMetadata(stackFileName, varargin)

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

global numParallelBlocks %#ok<NUSED>
global needStopPool %#ok<NUSED>
n = length(metadataStructs);
metadataList = repmat(MetadataObj(), 1, n);
numRestarts = 0;
ProgressBar('Loading image stacks', n);
while n > 0
  try
    metadataList(n) = MetadataObj(metadataStructs(n));
    %java.lang.System.gc()
  catch metadataLoadErr
    if any(strfind(metadataLoadErr.message, 'java.lang.OutOfMemoryError'))
      % java heap is filled up with crap, try to clear stuff
      if n + numRestarts >= length(metadataStructs)
        % this isn't going to work, we're not getting anywhere
        throw(metadataLoadErr)
      end
      
      % warn the user to expect a brief delay
      warnHandle = msgbox({'Whoops! Java went and filled up memory.', ...
                           'It''ll take a moment to clean stuff out.'}, ...
                           'Doh!', 'warn');
                         
      % save needed variables to a temporary file
      tempFile = [tempdir, 'metadataTempFile.mat'];
      save(tempFile, 'metadataList', 'metadataStructs', 'n', ...
           'warnHandle', 'numRestarts', ...
           'numParallelBlocks', 'needStopPool');
      
      % stop any image stats progress bars
      timerHandles = timerfind('Tag', 'ProgressTimer');
      for m = 1:length(timerHandles)
        timerName = get(timerHandles(m), 'name');
        if any(strfind(timerName, 'Calculating image statistics'))
          % stop the timer
          stop(timerHandles(m))
        end
      end
      % clear memory, restart any parallel environments
      clear all
      if ParallelIsActive()
        matlabpool close force
        clear all
        while matlabpool('size') > 0
          pause(0.1)
        end
        matlabpool open
      end
      
      % restore the needed variables and continue
      tempFile = [tempdir, 'metadataTempFile.mat'];
      
      load(tempFile)
      delete(tempFile)
      close(warnHandle)
      numRestarts = numRestarts + 1;
      continue
    else
      % some other error, give up
      rethrow(metadataLoadErr)
    end
  end
  n = n - 1;
  ProgressBar('Loading image stacks');
end

if numRestarts > 0
  % If there were any restarts, it's probably worth cleaning things out a
  %  bit right now
  
  % warn the user to expect a brief delay
  warnHandle = msgbox({'Since Java filled up memory earlier,', ...
                    'it''ll take a moment to clean up one more time.'}, ...
                    'Doh!', 'warn');

  % save needed variables to a temporary file
  tempFile = [tempdir, 'metadataTempFile.mat'];
  save(tempFile, 'metadataList', 'metadataStructs', 'n', ...
       'warnHandle', 'numRestarts', 'numParallelBlocks', 'needStopPool');
  
  % clear memory, restart any parallel environments
  clear all
  if ParallelIsActive()
    matlabpool close force
    clear all
    while matlabpool('size') > 0
      pause(0.1)
    end
    matlabpool open
  end

  % restore the needed variables and continue
  tempFile = [tempdir, 'metadataTempFile.mat'];
  load(tempFile)
  delete(tempFile)
  close(warnHandle)
end

return
