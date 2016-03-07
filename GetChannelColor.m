%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function color = GetChannelColor(metadata)
if isempty(metadata.miscInfo.detector)
  color = zeros(1,3);
  color(metadata.channelNum + 1) = 1.0;
  return
end
    
try
  lowWave = metadata.miscInfo.detector.lowWavelength;
  highWave = metadata.miscInfo.detector.highWavelength;
  midWavelength = 0.5 * (lowWave + highWave);
  color = CIE_To_RGB(WavelengthToCIE(midWavelength));
catch colorErr
  if ~strcmp(colorErr.identifier, 'MATLAB:nonExistentField') && ...
      ~strcmp(colorErr.identifier, 'MATLAB:nonStrucReference')
    rethrow(colorErr)
  end
  color = zeros(1,3);
  color(metadata.channelNum + 1) = 1.0;
end
return