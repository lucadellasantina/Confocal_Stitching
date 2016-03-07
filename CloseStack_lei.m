function CloseStack_lei(~)
global numLOCI;
if isempty(numLOCI)
  return
elseif numLOCI <= 1
  
  clear global numLOCI
  clear global readerLOCI
else
  numLOCI = numLOCI - 1;
end
return