function isPar = ParallelIsActive()
% return true if the parallel environment is being used
try
  if verLessThan('matlab', '8.2')
    isPar = matlabpool('size') > 0;
  else
    isPar = ~isempty(gcp('nocreate'));
  end
  if ~isPar
    % The above test fails if run by a parallel client, so test for that.
    % The parallel client is created by remoteParallelFunction, so it should
    %   be the first function on the stack:
    funcStack = dbstack();
    isPar = strcmp(funcStack(end).name, 'remoteParallelFunction');
  end
catch exception
  if verLessThan('matlab', '8.2')
    parName = 'matlabpool';
  else
    parName = 'parpool';
  end
  if strcmp(exception.identifier, 'MATLAB:UndefinedFunction') && ...
     ~isempty(strfind(exception.message, parName))
    % parallel toolkit isn't installed, so parallel isn't active
    isPar = false;
  else
    % some other really weird error.  Nothing to do but barf it up again
    rethrow(exception)
  end
end
return