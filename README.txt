Copyright (C) March 5, 2010 Ted Brookings
ted.brookings@gmail.com

OVERVIEW:
This is a package of matlab files to view, align, and stitch together multiple confocal stacks, and then 
make projection views of them.  The package can work with stacks that have different resolutions in X, 
Y, and Z, as well as different numbers of slices.  It requires a lot of memory to maintain whole stacks 
in memory, although it can work with virtual stacks if there is insufficient memory.

Many buttons and fields have helpful mouse-over text that explains their function.  Eventually they should all have this, but for now this document serves as a function summary.

INSTRUCTIONS:
(Getting started)
To get things started, at the matlab prompt, type:
confocal

####### ADDING STACKS ##########
Next click on "Load Leica Dir" to load a confocal stack.
   -confocal.m can work with Leica files, provided that the text summary still exists in the directory.
    It looks for files with a .lei or .lif extension.
   -confocal.m can also work with saved stitched together stacks, with a .lei_mat extension

After choosing a file, a list of channels will be displayed in the upper-right hand list box.  Choose a 
channel and press "Add Channel".  Projections will be displayed in the main confocal.m GUI, and the 
channel name will be added to the channel list box.  You can add additional channels from this leica 
file, and/or load new leica files and add channels from them.  You can also remove channels by clicking 
on "Remove".  By default, all image stacks are treated the same, regardless of the channel they 
originate from.  To group stacks by channel, click "Group Channels".

######## ALIGNING STACKS #######
By default, the stack projections are displayed in order, with the bottom channel (in the list box) 
drawn last.  Clicking on a channel name moves it to the bottom.  By clicking on different channel names, 
you can see how well they line up.

Checking the box labeled "Transparency" will make the fainter parts 
of the projections transparent, which may aid in aligning.  The currently selected channel has its 
origin listed in the position boxes.  You can edit them to move it around.  Once you have the stacks 
mostly lined up, click on "Auto Position" to line them up perfectly.  You can then click on "Save 
Position", and next time you load them they will be positioned correctly.

####### STITCHING AND VIEWING #########
Click on "Stitch/View Stack(s)".  If there are multiple stacks, they will be stitched together, and you 
will have the option to save the stitched stack.  Then a new GUI will open, allowing you to view slices.  
The "Projection Dimension" control will allow you to view slices taken from the selected dimension.  
Moving the slider bar or entering in a number in the text box allows you to select the desired slice.  
"Zoom In" and "Zoom Out" zoom by a factor of two.  You can pan the zoomed slice by clicking and dragging 
the slice image.  Clicking on "Save slice image" will allow you to save the image as an uncompressed 
tiff.

###### VIEWING INTENSITY HISTOGRAM ########
Click on "View Histogram" to display a histogram of voxel intensities for each channel.  Will create a separate function window for the histogram display.

###### CROPPING AND SCALING ###########
Clicking on Crop/Scale will bring up a popup dialog allowing you to trim the image to remove unwanted regions, or to increase the size of voxels, lowering resolution (i.e. downsampling) and thus decreasing memory/disk requirements.

############ PROJECTING ############
Select the desired projection options, then click "Make Projections".  The program will form the 
projections (for all dimensions) and save them into a directory of your choice.  The projection options 
are pre-set to the recommended settings, but you can change them as you like.

Projection Method:  recommended setting is "Max"
   -Standard Deviation:  Intensity equals the STD of intensities along the projection dimension.
    Typically produces low-noise images emphasizing bright features regardless of their depth.
   -Sum:  Intensity equals to the sum of intensities along the projection dimension.
   -Max:  Intensity equals the maximum intensity along the projection dimension.
   -Transparency:  Intensity is the result of a simple ray trace, with dim voxels being mostly transparent.

Projection Options:
   -Use Color:  The projection is color-coded by depth, with red being closer, and blue further away.
   -Brighten Dark:  The intensities are distorted slightly, so as to emphasize differences in dim or
    medium brightness parts of the stack.  If Brighten Dark is selected, a UI will pop up for each
    projection, allowing the user to select the intensity level that should be considered black
    (it should usually be okay to accept the default).
