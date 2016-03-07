function existVal = FileExists(fileName)
fid = fopen(fileName, 'r');
if fid > 0
  existVal = true;
  fclose(fid);
else
  existVal = false;
end
return