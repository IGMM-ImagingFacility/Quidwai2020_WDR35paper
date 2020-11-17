/*
 * Macro for segmenting centrosomes and measuring intensity spreading out from them
 * Currently done with discrete bands enlarged from segmented centrosomes by 1 and 5 pixels
 * Works on Dragonfly .ims files
 * Written for Emma Hall			
 * 																					Written by Laura Murphy
 * 																					IGMM Advanced Imaging Resource
 * 																					August 2018												
 */

//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 0: Preparation steps: get directories from users and setting up arrays 
//--------------------------------//-----------------------------------------------------------------------------------

// -- Getting input and output folders from user input 
inputFolder = getDirectory("Choose the folder containing your images");
outputFolder = getDirectory("Choose the folder where you want to save your results")

setBatchMode(true);

// -- Produce list to only be .ims files due to .txt metadata files in same folder
list = getFileList(inputFolder);
imsList = newArray(0);  
for (a = 0; a<list.length; a++) {
  if (endsWith(list[a], ".ims")){
      imsList = append(imsList, list[a]);
  }
}

// -- Message to users about how many images
count = imsList.length
print("There are " + count + " files to be processed:");

// -- Set up arrays for storing results later
Filename = imsList;
Signal_Mean = newArray(count);
Centrosome_Mean = newArray(count);
Band_One_Mean = newArray(count);
Band_Two_Mean = newArray(count);
Band_Three_Mean = newArray(count);
Band_Four_Mean = newArray(count);
Band_Five_Mean = newArray(count);


//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 1: Opening images and creating results directories
//--------------------------------//-----------------------------------------------------------------------------------

// -- Using Bio-Formats to open images
for (i=0; i<imsList.length; i++){ 
	path = inputFolder + File.separator + imsList[i];
	run("Bio-Formats Macro Extensions");
	run("Bio-Formats Importer", "open=&path color_mode=Composite rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT series_1");           

	fileName = getTitle();
	imgName = File.nameWithoutExtension();
	getDimensions(width, height, channels, slices, frames);

//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 2: File processing
//--------------------------------//-----------------------------------------------------------------------------------

	// Get intensity projection, set channel LUTs
	Stack.setChannel(1);
	run("Blue"); 
	Stack.setChannel(3);
	run("Red"); 
	run("Z Project...", "projection=[Average Intensity]");
	rename("Projection");
	selectWindow(fileName);
	run("Close");
	selectWindow("Projection");
	run("Duplicate...", "duplicate");	
	rename(imgName);
	selectWindow("Projection");
	run("Duplicate...", "duplicate");	
	rename("Active");

	// Split channels and rename based on signal
	run("Split Channels");	
	selectWindow("C1-Active");
	rename("Nuclei");
	selectWindow("C2-Active");
	rename("Signal");
	selectWindow("C3-Active");
	rename("Centrosomes");
	
//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 3: Segmenting centrosomes
//--------------------------------//-----------------------------------------------------------------------------------

	// -- Segmentation of centrosomes, may need changed
	selectWindow("Centrosomes");
	setAutoThreshold("RenyiEntropy dark");
	run("Convert to Mask");
	run("Watershed");
	makeRectangle(15,15,getWidth-30, getHeight-30);
	run("Analyze Particles...", "size=0.1-Infinity exclude add");
	run("Set Measurements...", "area centroid display redirect=None decimal=4");

	// -- Save image with centrosome ROIs
	selectWindow("Projection");
	run("RGB Color");
	roiManager("Show All without labels");
	run("Flatten");
	saveAs("Tiff", outputFolder + File.separator + imgName + "_Centrosomes.tif");

	// -- Print message to tell user how many centrosomes have been detected
	centrosomes = roiManager("Count");
	print(imsList[i] + " has " + centrosomes + " centrosomes"); 

//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 4: Create bands from centre of segmented centrosomes and measure them on the signal channel
//--------------------------------//-----------------------------------------------------------------------------------

	selectWindow("Signal");
	rename(imgName);
	getStatistics(area, Signal_Mean[i], min, max, std, histogram);
	
	// -- Create arrays to store results
	Label = newArray(centrosomes);
	Centrosome = newArray(centrosomes);
	Band_One = newArray(centrosomes);
	Band_Two = newArray(centrosomes);
	Band_Three = newArray(centrosomes);
	Band_Four = newArray(centrosomes);
	Band_Five = newArray(centrosomes);

	radius = 1 //change this number to change band size

	for(j = 0; j < centrosomes; j++){
		roiManager("Select", j);
		roiManager("Rename", "Centrosome_"+(j+1));
		Label[j] = "Centrosome_"+(j+1);
		roiManager("Set Color", "red");
		getStatistics(area, Centrosome[j], min, max, std, histogram);
		roiManager("Select", j);
		run("Make Band...", "band=" + radius);
		getStatistics(area, Band_One[j], min, max, std, histogram);
		Roi.setName("Centrosome_" + (j+1) + ": Band_1");
		roiManager("Set Color", "orange");
		roiManager("Add");	
		roiManager("Select", (roiManager("count")-1));
			run("Make Band...", "band=" + radius);
		getStatistics(area, Band_Two[j], min, max, std, histogram);
		Roi.setName("Centrosome_" + (j+1) + ": Band_2");
		roiManager("Set Color", "yellow");
		roiManager("Add");
		roiManager("Select", (roiManager("count")-1));
			run("Make Band...", "band=" + radius);
		getStatistics(area, Band_Three[j], min, max, std, histogram);
		Roi.setName("Centrosome_" + (j+1) + ": Band_3");
		roiManager("Set Color", "yellow");
		roiManager("Add");
		roiManager("Select", (roiManager("count")-1));
			run("Make Band...", "band=" + radius);
		getStatistics(area, Band_Four[j], min, max, std, histogram);
		Roi.setName("Centrosome_" + (j+1) + ": Band_4");
		roiManager("Set Color", "yellow");
		roiManager("Add");
		roiManager("Select", (roiManager("count")-1));
		run("Make Band...", "band=1");
		getStatistics(area, Band_Five[j], min, max, std, histogram);
		Roi.setName("Centrosome_" + (j+1) + ": Band_5");
		roiManager("Set Color", "yellow");
		roiManager("Add");
	}

	// -- Save image with all ROIs
	selectWindow("Projection");
	Stack.setChannel(1);
	run("Enhance Contrast...", "saturated=0.3 normalize");
	Stack.setChannel(2);
	run("Enhance Contrast...", "saturated=0.3 normalize");
	Stack.setChannel(3);
	run("Enhance Contrast...", "saturated=0.3 normalize");
	run("RGB Color");
	roiManager("Show All without labels");
	run("Flatten");
	saveAs("Tiff", outputFolder + File.separator + imgName + "_Outlines.tif");

	run("Close All");
	roiManager("Reset");

	// -- Save the results per image
	Array.show("Mean Intensity", Label, Centrosome, Band_One, Band_Two, Band_Three, Band_Four, Band_Five);
	saveAs("Results", outputFolder + File.separator + imgName + "_Results.csv");
	run("Close");

	// -- Take means per image to save for overall mean results
	Array.getStatistics(Centrosome, min, max, Centrosome_Mean[i], stdDev);
	Array.getStatistics(Band_One, min, max, Band_One_Mean[i], stdDev);
	Array.getStatistics(Band_Two, min, max, Band_Two_Mean[i], stdDev);
	Array.getStatistics(Band_Three, min, max, Band_Three_Mean[i], stdDev);
	Array.getStatistics(Band_Four, min, max, Band_Four_Mean[i], stdDev);
	Array.getStatistics(Band_Five, min, max, Band_Five_Mean[i], stdDev);	
	
}

//--------------------------------//-----------------------------------------------------------------------------------
//-- Part 5: Closing loop and finishing off
//--------------------------------//-----------------------------------------------------------------------------------

// -- Save the average results for each image
Array.show("Mean Intensity", Filename , Signal_Mean, Centrosome_Mean, Band_One_Mean, Band_Two_Mean, Band_Three_Mean, Band_Four_Mean, Band_Five_Mean );
saveAs("Results", outputFolder + File.separator + "Mean intensity for centrosomes bands per image.csv");
run("Close");

run("Collect Garbage");

Dialog.create("Progress");
Dialog.addMessage("Macro Complete!");
Dialog.show;

//--------------------------------//-----------------------------------------------------------------------------------
//-- Epilogue: Functions
//--------------------------------//-----------------------------------------------------------------------------------

function append(arr, value) {
 arr2 = newArray(arr.length+1);
 for (i=0; i<arr.length; i++)
    arr2[i] = arr[i];
 arr2[arr.length] = value;
 return arr2;
}
