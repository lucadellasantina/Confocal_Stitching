function InitBioFormats()
classPath = javaclasspath;
for n=1:length(classPath)
  if strfind(classPath{n}, 'loci_tools.jar')
    return
  end
end

thisScriptName = mfilename('fullpath');
ind = strfind(thisScriptName, filesep);
if isempty(ind)
  bioFormatsPath = '';
else
  bioFormatsPath = thisScriptName(1:ind(end));
end
lociPath = [bioFormatsPath, 'loci_tools.jar'];
javaaddpath(lociPath);
%loci.common.DebugTools.enableLogging('INFO');
loci.common.DebugTools.enableLogging('OFF');
return