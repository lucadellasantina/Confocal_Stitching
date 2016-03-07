function DSImage = DownSampleImage(Image, XFact, YFact)
% DSImage = DownSampleImage(Image, XFact, YFact)
% Downsamples an image.  If YFact is not specified, it is assumed
% equal to XFact.  If neither is specified, they are assumed equal
% to 0.5 (reduce each dimension by half).
DefaultFact = 0.5;
switch(nargin)
 case 1,
  XFact = DefaultFact;
  YFact = DefaultFact;
 case 2,
  YFact = XFact;
 case 3,
 otherwise,
  error('Usage:  DSImage = DownSampleImage(Image, XFact, YFact)')
end

[YSize, XSize, NumColors] = size(Image);
DSX = round(XSize * XFact);
DSY = round(YSize * YFact);
if DSX == XSize && DSY == YSize
  DSImage = Image;
  return
end

ClassStr = class(Image);

if NumColors > 1
  DSImage = zeros(DSY, DSX, NumColors, ClassStr);
  
  nHigh = 0;
  for n = 1:DSY
    nLow = nHigh + 1;
    if(n == DSY)
      nHigh = YSize;
    else
      nHigh = round( n / YFact );
    end
    mHigh = 0;
    for m = 1:DSX
      mLow = mHigh + 1;
      if(m == DSX)
	mHigh = XSize;
      else
	mHigh = round( m / XFact );
      end

      NumTot = (nHigh - nLow + 1) * (mHigh - mLow + 1);
      DSImage(n,m,:) = sum(sum(...
	  Image(nLow:nHigh, mLow:mHigh, :), ...
	  1), 2) ...
                      / NumTot;
    end
  end
else  %Black and white
  DSImage = zeros(DSY, DSX, ClassStr);
  
  nHigh = 0;
  for n = 1:DSY
    nLow = nHigh + 1;
    if(n == DSY)
      nHigh = YSize;
    else
      nHigh = round( n / YFact );
    end
    mHigh = 0;
    for m = 1:DSX
      mLow = mHigh + 1;
      if(m == DSX)
	mHigh = XSize;
      else
	mHigh = round( m / XFact );
      end
      NumTot = (nHigh - nLow + 1) * (mHigh - mLow + 1);
      DSImage(n,m) = sum(sum(Image(nLow:nHigh, mLow:mHigh))) ...
                      / NumTot;
    end
  end
end
return