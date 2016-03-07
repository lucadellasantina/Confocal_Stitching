function reader = OpenWithBioFormats(fileName)
% turn off debug logging warning
InitBioFormats();
reader = loci.formats.ChannelFiller();
reader = loci.formats.ChannelSeparator(reader);
% this is new, not sure if it's a good idea:
%reader = loci.formats.gui.BufferedImageReader(reader);
meta = loci.formats.MetadataTools.createOMEXMLMetadata();
reader.setMetadataStore(meta);
if nargin > 0
  reader.setId(fileName);
end
return