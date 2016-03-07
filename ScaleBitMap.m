function Scaled = ScaleBitMap(BitMap, NewX, NewY)
X = (0:(size(BitMap,2)-1))/(size(BitMap,2)-1);
Y = (0:(size(BitMap,1)-1))/(size(BitMap,1)-1);
XI = repmat( (0:(NewX-1))/(NewX-1), NewY, 1);
YI = repmat( (0:(NewY-1))'/(NewY-1), 1, NewX);
%Scaled = interp2(X,Y, BitMap, XI, YI, 'nearest');
Scaled = interp2(X,Y, double(BitMap), XI, YI, 'nearest');
return
