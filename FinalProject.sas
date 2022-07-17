/* My Nguyen
Final project
Date: May 9, 2022

Please change the folder path on the right-hand side of the statement
below to the path where this SAS file and the Current Police Districts
locate.
*/
%let workPath= M:\STA 402\Project; 

/*

This SAS program has 2 macros:
- %incident_map(Month=, Year=, Category=, SubCategoryByPercentages=, output=):
	This macro accepts a month and incident type specified by the user,
	then produce a map of San Francisco with all locations of that type of 
	incident in that given month.

	Month: month(numeric) when the incidents happen
	Year: year when the incident happen
	Category: type of incidents
	SubCategoryByPercentages: 1(=true)/ 0(false), an optional pie chart displaying 
	subcategories in percentage of the genral category specified above
	output: file path for rtf output of the map and/or pie chart

- % generalAnalysis(output=)
	This macro will generate a line plot showing number of incidents
	in SF by police district and a color-coded table with annual percentage change
	of total number of incidents in SF by category (blue for decrease, red for increase)

	output: file path for rtf output of the table and plots

The program is implemented as a SAS macro program so please change
the statement

    %let folder=

as indicated above. Next run this SAS file to define the macro. 
Maps, tables, and graphs in final report are generated using following macros:

    %incident_map(Month=2, Year=2020, Category=Larceny Theft, SubCategoryByPercentages=1, output=M:\STA 402\Project\Map.rtf);
	%incident_map(Month=2, Year=2020, Category=Burglary, SubCategoryByPercentages=1, output=M:\STA 402\Project\Map.rtf);
	%generalAnalysis(output=M:\STA 402\Project\Plots.rtf)

This program requires current SAS file to be in the same location as 
the Current Police District folder.
*/


options work="&workPath";

*Importing in the incident data set;
proc import file="&workPath\Police_Department_Incident_Reports__2018_to_Present.csv"
    out=work.incidents
    dbms=csv;
run;

%macro incident_map(Month=, Year=, Category=, SubCategoryByPercentages=, output=);

data work.cleanedIncidents;
	set work.incidents;
	Incident_Month = month(Incident_Date); *Extracting incident month from reported date;
	* Stripping repetitive incident categrory from subcategories for better map legend;
	if find(Incident_SubCategory, '-') then SubCategory = scan(Incident_SubCategory, -1, '-'); 
	else SubCategory = Incident_SubCategory;

	*Selecting data given user input;
	if Incident_Month = &Month and 
		Incident_Year = &Year and 
		Incident_Category = "&Category" and
		Police_District ^= 'Out of SF'; *Select incidents from inside SF only;
	keep Incident_Month Incident_Year Incident_Category SubCategory Latitude Longitude;
run;

*Importing in the district boundaries for SF;
proc mapimport datafile="&workPath\Current Police Districts\geo_export_79d7b3ff-17c4-483e-bf69-766079da4e5f.shp" out=boundaries;
run;

ods rtf bodytitle file = "&output";
ods graphics on / width=1000px height=1200px;
proc sgmap mapdata=boundaries      /* Map boundaries */
           plotdata=work.cleanedIncidents
           des='San Francisco';
  openstreetmap;
  *Drawing boundary lines for all police districts;
  choromap / mapid=district lineattrs=(color=red) legendlabel='Districts';
  *Drawing locations of selected indicents;
  scatter x=Longitude y=Latitude / group=SubCategory markerattrs=(size=7 symbol=circlefilled);
run;
ods graphics off;

*Creating a pie chart template;
%if &SubCategoryByPercentages = 1 %then %do;
	proc template;
	 	dynamic title1; 
		define statgraph pie;
			begingraph;
			entrytitle title1;
			     layout region;
			        piechart category = SubCategory /
			        datalabellocation = outside
			        datalabelcontent = all
			        categorydirection = clockwise
			        start = 180 name = 'pie';
			        discretelegend 'pie' /
			        title = 'Subcategories';
			     endlayout;
			  endgraph;
			end;
		run;
	
	*drawing the pie chart;
	proc sgrender data = work.cleanedIncidents 
		tempplate = pie;
		dynamic title1 = "Percentage breakdown of incident by subcategory";
	run;
%end;
ods rtf close;
%mend incident_map;

%macro generalAnalysis(output=);
*========================================== Set up for Line Graph;
*Sorting incidents by district for later counting;
proc sort data=work.incidents 
    out=work.sortedByDistrict;
    by Incident_Year Police_District;
run;

*Counting incidents by different districts;
data casesByPoliceDistrict;
	set work.sortedByDistrict;
	by Incident_Year Police_District;

	retain Count;
	if first.Police_District then Count = 1;
    else Count = Count + 1;
 
    if last.Police_District then output;
 	
    keep Incident_Year Police_District Count;

run;


*========================================== Set up for Percent table;
*Sorting incidents by subcategories for later counting;
proc sort data=work.incidents 
    out=work.sortedBySubCategory;
    by Incident_Year Incident_SubCategory;
run;

*Counting incidents by different subcategories;
data casesBySubCategory;
	set work.sortedBySubCategory;
	by Incident_Year Incident_SubCategory;

	retain Count;
	if first.Incident_SubCategory then Count = 1;
    else Count = Count + 1;
 
    if last.Incident_SubCategory then output;
 
    keep Incident_Year Incident_SubCategory Count;

run;

*Sorting to calculate percentage change by rows(years) for each category;
proc sort data=casesBySubCategory 
    out=sorted;
    by Incident_SubCategory;
run;

*Calculating the percentage change;
data percentChanges;
	set sorted;
	by Incident_SubCategory notsorted;
	Percent_Change = round((Count - lag(Count)) / Count * 100, .01); 
	if first.Incident_SubCategory then Percent_Change = 0;
	drop Count;
run;

*Transposing table;
proc transpose data=percentChanges out=Tr_percentChanges;
	id Incident_Year;
	by Incident_SubCategory; * transpose the original dataset;
run;

*Creating a color coded format for the data;
proc format;
value changes 	-1000 -< 0 = light blue
				0 <- 1000 = light red
				other = white ;
run;

*========================================== Graph and Table output;
ods rtf bodytitle file = "&output";
* Number of incidents analyzed by district;
title 'Number of incidents in San Francisco by police district';
proc sgplot data=casesByPoliceDistrict;
	title 'Number of incidents in San Francisco by police district';
	vline Incident_Year / response=Count group=Police_District 
		lineattrs=(pattern=solid thickness=2pt);
	xaxis label="Police District";
	yaxis label="Number of incidents";
run;

* Number of incidents analyzed by categories (percentage change over years);
title "Annual percentage change (%) in number of incidents in SF by category";
proc print data=Tr_percentChanges label;
	var Incident_Subcategory _2019 _2020 _2021 / style(data)=[backgroundcolor=changes.];
   	label 	Incident_SubCategory = "Category"
         	_2019 = "2018-2019"
         	_2020 = "2019-2020"
			_2021 = "2019-2020";
   	*title "Annual percentage change (%) in number of incidents in SF by category";
run;
ods rtf close;
%mend generalAnalysis;
