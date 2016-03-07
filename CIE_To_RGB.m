function rgb = CIE_To_RGB(cie)
mat = (1.0 / 0.17697) * ...
  [[0.49, 0.31, 0.20]; [0.17697, 0.81240, 0.01063]; [0.00, 0.01, 0.99]];
rgb = (mat \ (cie'))';

minRGB = min(rgb);
if minRGB < 0
  rgb = rgb - minRGB;
end
rgb = rgb / max(rgb);
return