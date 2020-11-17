/*
 * 
 * Written for Tooba Quidwai to measure intensity in 3D around basal body
 * User selects area for the shell to be centered on
 * 																					Written by Laura Murphy
 * 																					IGMM Advanced Imaging Resource
 * 																					May 2019												
 */

//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 0: Preparation steps: get directories from users and setting up arrays 
//--------------------------------//-----------------------------------------------------------------------------------

inputFolder = getDirectory("Parent directory of your image folders");
outputFolder = getDirectory("Choose the folder where you want to save your results");

dirI = outputFolder + File.separator + "Images";
File.makeDirectory(dirI);

dirM = outputFolder + File.separator + "Measurements";
File.makeDirectory(dirM);

dirList = newArray();
dirList = getFileTree(inputFolder, dirList);

// -- Message to users about how many images there are
count = dirList.length
print("There are " + count + " files to be processed:");

//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 1: Opening images, get details from images, filename, scaling, dimensions. Create black stack same dimensions as image
//--------------------------------//-----------------------------------------------------------------------------------

// -- Using Bio-Formats importer to open images
for (a = 0; a < dirList.length; a++) { 
	path = dirList[a];
	run("Bio-Formats Importer", "open=&path autoscale color_mode=Composite rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT series_1");     
	
	fileName =getTitle();
	imgName = File.nameWithoutExtension();
	getDimensions(width, height, channels, slices, frames);

	// Store scaling and remove it for making measurements need
	getVoxelSize(vx,vy,vz,U);
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

	newImage("Mask", "8-bit grayscale-mode", width, height, 1, slices, 1);
	
//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 2:
//--------------------------------//-------------------------------------------------------------------------- ---------

	// Get set channel LUTs including hiding channel than will be measured
	selectWindow(fileName);
	rename("Active");
	Stack.setChannel(1);
	run("Blue"); 
	run("Enhance Contrast", "saturated=0.35");
	Stack.setChannel(3);
	run("Red"); 
	run("Enhance Contrast", "saturated=0.35");
	Stack.setActiveChannels("101");

//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 3: Getting user to select where they want to measure 
//--------------------------------//-----------------------------------------------------------------------------------

	run("Point Tool...", "type=Circle color=Orange size=Medium add label show");
	setTool("Point");

	waitForUser("Select the centroids where you want to measure mean intensity from \n"
	+ "   \n"
	+ "You can move through the slices with the mouse wheel by holding down alt \n"
	+ "You can zoom in and out with with the mouse wheel by holding down ctrl \n"
	+ "   \n"
 	+ "Press 'OK' when you have selected all the areas you want to measure in this image stack");

	roiManager("Deselect");
	run("Set Measurements...", "centroid stack redirect=None decimal=3");
	roiManager("Measure");
	roiManager("Reset");

	selectWindow("Mask");
    
    for (i = 0; i < nResults; i++){
		x = getResult("X", i);
		y = getResult("Y", i);
		slice = getResult("Slice", i);
		Stack.setSlice(slice);
		makeOval(x-0.5, y-0.5, 0.5, 0.5);
		run("Fill", "slice");
		run("Select None");

	}
	
//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 4: Creating kernel and creating spheres on the mask image
//--------------------------------//-----------------------------------------------------------------------------------

	kSize = 33; // change this number to change the shell measured - currently set to 33 to be roughly 2 microns (dependent on image scaling of course!)
	setOption("BlackBackground", true);
	selectWindow("Mask");
	
	kern = makeKernel( kSize );
	
	slc = Table.getColumn("Slice");
	x = Table.getColumn("X");
	y = Table.getColumn("Y");
	setPasteMode("Transparent-zero");
	n = slc.length;
	
	for (j = 0; j < n; j++ ) {
		placeKernel( kSize, floor(x[j]), floor(y[j]), slc[j], "Mask", kern );
	}
	
	setPasteMode("Copy");
	setSlice(1);
	selectWindow("Kernel");
	run("Close");
	selectWindow("Results");
	run("Close");
	
//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 5: 3D Manager, segment mask and measure objects on Channel 2 of image
//--------------------------------//-----------------------------------------------------------------------------------

	run("3D Manager Options", "mean_grey_value centroid_(pix) distance_between_centers=10 distance_max_contact=1.80 drawing=Point");
	run("3D Manager");
	selectWindow("Mask");
	Ext.Manager3D_Segment(1, 255);
	selectWindow("Mask-3Dseg");
	Ext.Manager3D_AddImage();
	selectWindow("Mask");
	run("Close");
	selectWindow("Active");
	Stack.setChannel(2);
	Ext.Manager3D_DeselectAll();
	Ext.Manager3D_Quantif();

//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 6: Closing loop and finishing off
//--------------------------------//-----------------------------------------------------------------------------------

	Ext.Manager3D_SaveResult("Q", dirM + File.separator + imgName + ".csv");
	Ext.Manager3D_CloseResult("Q");

	selectWindow("Active");
	run("Split Channels");
	run("Merge Channels...", "c1=C1-Active c2=C2-Active c3=C3-Active c7=Mask-3Dseg create");
	saveAs("Tiff", dirI + File.separator + imgName + "_MeasuredArea.tif");

//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 7: Closing loop and finishing off
//--------------------------------//-----------------------------------------------------------------------------------
	Ext.Manager3D_Close();
	run("Close All");
}

run("Collect Garbage");

run("Close All");

Dialog.create("Progress");
Dialog.addMessage("Macro Complete!");
Dialog.show;


//--------------------------------//-----------------------------------------------------------------------------------
//-- Epilogue: Functions
//--------------------------------//-----------------------------------------------------------------------------------


function getFileTree(dir , fileTree){
	list = getFileList(dir);
	for(f = 0; f < list.length; f++){
		if(endsWith(list[f], ".ims"))
			fileTree = Array.concat(fileTree, dir + list[f]);
		if(File.isDirectory(dir + File.separator + list[f]))
			fileTree = getFileTree(dir + list[f],fileTree);
	}
	return fileTree;
}

function makeKernel( sz ) {
	sm = (sz-1)*0.5;
	newImage( "Kernel", "8-bit black", sz, sz, sm+1 );
	setForegroundColor(255, 255, 255);
   	i = 0;
   
	do {
		setSlice(i+1);
		makeOval( sm, sm, 2*i+1, 2*i+1);
		run("Fill", "slice");
		sm--;
		i++;
	} while (sm>=0);
	
	run("Select None");
	return getImageID();
}

function placeKernel( sz, xx, yy, sl, imgStack, kernel ) {
	setSlice(1);
	sm = (sz-1)*0.5;
	xx -= sm;
	yy -= sm;
	stop = sl + sm;
	start = sl - sm;
	k = 0;
	
	do {
		selectWindow("Kernel");
		setSlice(k + 1);
		run("Copy");
		selectImage(imgStack);
	
		if (start + k > 0) {	
			setSlice(start + k);
			makeRectangle(xx, yy, sz, sz);
			run("Paste");
		}
	  
		if (stop - k < = nSlices)  {
			setSlice(stop - k);
			makeRectangle(xx, yy, sz, sz);
			run("Paste");
		}
		
		k++;
	} while (k <= sm);
	run("Select None");
}

