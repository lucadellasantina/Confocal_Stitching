%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [ResLateral, ResAxial] = ComputeResolution(Data)
%[ResLateral, ResAxial] = ComputeResolution(Data)
%  INPUTS:
%  -Data: structure that contains the following fields:
%     -NumericalAperture
%     -EmitWavelength:   emission wavelength in nanometers
%     -ExciteWavelength: excitation wavelength in nanometers
%     -RefractionIndex:  refraction index of mounting medium
%     -Pinhole_meters:   pinhole diameter in meters
%  OUPUTS:
%  -ResLateral, ResAxial:  lateral and axial resolutions according
%                          to Rayleigh criterion
%Based on Bo Zhang et al, Applied Optics (2007)

if(~isfield(Data, 'RefractionIndex'))
  Data.RefractionIndex = 1.5180;
end
if(~isfield(Data, 'Pinhole_meters'))
  Data.Pinhole_meters = 0;
end

%Often denoted alpha:
HalfAngle = asin(Data.NumericalAperture / Data.RefractionIndex);
CosAlpha = cos(HalfAngle);

SigmaNonParaxial = sqrt(7*(1 - CosAlpha^1.5) / ...
			(4 - 7*CosAlpha^1.5 + 3*CosAlpha^3.5)) / ...
    (Data.RefractionIndex * 2*pi);

%Get pinhole radius (factor of 0.5) in nanometers
Pinhole = 0.5 * Data.Pinhole_meters * 1.0e9;
%Compute ratio Pinhole^2 / 2 SigmaEmit^2
%SigmaEmit = SigmaNonParaxial * EmitWavelength
Pinhole = 0.5 * (Pinhole / (SigmaNonParaxial * Data.EmitWavelength))^2;

WaveRatio = Data.ExciteWavelength / Data.EmitWavelength;

SigmaLateral = SigmaNonParaxial*Data.ExciteWavelength / ...
    sqrt(1 + WaveRatio^2 * Pinhole / (exp(Pinhole) - 1));

%This is the wide-field calculation:
SigmaAxial = Data.ExciteWavelength / (2*pi) * ...
    5 * sqrt(7) * (1 - CosAlpha^1.5) / Data.RefractionIndex ...
    / sqrt(6 * (4*CosAlpha^5 - 25*CosAlpha^3.5 + 42*CosAlpha^2.5 - ...
	   25*CosAlpha^1.5 + 4));
%Corrected for nonparaxial laser scanning confocal:
SigmaAxial = SigmaAxial / sqrt(1 + WaveRatio^2);

%Finally, compute resolution from gaussian parameters:
ResLateral = SigmaLateral * 1.22 / 0.42;
ResAxial = SigmaAxial * 1.22 / 0.42;
return