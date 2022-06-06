
%macro create_enroll_all(cy /*a two-digit integer identifying the current year of analysis (positional)*/,
						client /*an integer indicating the marketscan client (positional)*/,
						months=12 /*The number of months to consider (default is 12)*/, 
						outfile=enroll /*the output sas dataset (default is enroll)*/,
						outlib=outsas /*the output library (default is outsas)*/,
						ver_set=outsas.versions /*the dataset contains marketscan versions(default outsas.versions)*/
);
 /*MACRO DETECT ENROLL YEAR														
 **Description: This helper function determines the enrollment year for an insurance plan
 **				by using enrollment patterns from the current, prior, and proximal year
 **
 **CHANGE LOG:
 ** ----------------------------------------------------------------------------------------------------------- 
 ** date        | action 									 |developer																												|Developer
 ** ------------+----------------------------------------------------------------------------------------------- 
 ** 20161005		Initial Development of program  			TJF
 ** 20170220  		Adjusted to become helper macro			 	TJF
 ** 20170306		Removed any references to plankey			TJF
 ** 20170315		Appended plankey from CCAEPYYV file from	TJF
 **					current year (YY=cy) file
 */


 /*DEBUGGING
   	%let cy = 12;
   	%let client=135;
   	%let months=12;
   	%let outfile=enroll;
	%let outlib=outsas;
 */	

	

	 /*set prior, current, and future year values and versions*/
	 %let py = %sysfunc(sum(%sysfunc(inputn(&cy, comma9.)),-1)); /*prior year*/

	 %if cy = 15 %then %do;
			%let fy = cy; /*current year is last year*/
	   	%end;
	 %else %do;
			%let fy = %sysfunc(sum(%sysfunc(inputn(&cy, comma9.)),+1)); /*prior year*/
		%end;
		
	 %do yr=&py %to &fy;	/*create a "long enrollment file*/


	 /*  UNEEDED 20170301
		data _null_; 
			set &ver_set.(where=(year=&yr.));
			call symput('ver',put(version, 1. -L));
		run;
		*/


	%if &yr.=15 %then %do;
			%let ver = 1;
	%end;
	%else %if &yr.=14 %then %do;
			%let ver = 2;
	%end;
	%else %do;
			%let ver = 3;
	%end;

	%do i=1 %to &months;
			proc freq data=ARCH20&yr..ccaea&yr&ver.(where=(client=&client.))  noprint;
				/*NOTE:   This step "pivots" the enrollment data for each plan (plan1-plan12) variables to long form
						   to create the following dataset structure:  
										hlthplan  client  plan  enrollment yearmonth
						  IT IS PERFORMANCE DRAG DUE TO REPEATED CALLS TO THE CCAEA FILES.
			               Option) replacement by Proc Transpose or data step is an option
								NOTE) the yearmonth variable is needed is later steps and would need to be created
				*/			  
					table hlthplan*client*plan&i/ out=&outlib..tmp;
			run;
			
			%if &i=1 AND &yr=&py %then %do;					
					data &outlib..&outfile (keep = hlthplan client plan count year month yearmonth);
						 set &outlib..tmp;
						 year = &yr;
						 month = &i;
						 yearmonth = 100*year+month;
						 rename plan&i = plan
						 				 ;
					run;
			%end;
			
			%else %do;
					data &outlib..&outfile(keep = hlthplan client plan count year month yearmonth);
						set &outlib..&outfile(in=a)
						    &outlib..tmp(in=b 
						    		   rename=(plan&i=plan)
						    	  );
						if b then do;
						 year = &yr;
						 month = &i;
						 yearmonth = 100*year+month;
 						end;
					run;
			%end;
			
		proc datasets library=&outlib. noprint;
			delete tmp;
		run;
	
	%end;
 %end;

  /*sort and transpose the client data*/
 proc sort data=&outlib..&outfile.(keep=count yearmonth plan client)
 								 out=&outlib..tmp;
	 by client plan;
 run;

 proc transpose data=&outlib..tmp
 				out=&outlib..&outfile
 				name=enrollment
				label=label
				prefix=m;
	by client plan;
	id yearmonth;
	var count;
 run;

 /*add plnkey variable back to dataset: 20170315 edits*/
 	/*note1: this is only for years prior to 2014 (if statement used)*/
 	/*note2: The 1st month (plan1) is used in matching. NO MATCHING TO ACTUAL PLAN START MONTH IS ENFORCED*/
%if &cy<14 %then %do;
	%let ver = 3;
	proc sql;
		create table &outlib..&outfile as
			select 	a.*,
					b.plankey
			from 
				&outlib..&outfile as a
			  LEFT JOIN
				(select 	
					client,
					plan,
					plankey
				 from (
						select 
							client,
							plan,
							plankey,
							seqnum,
							min(seqnum) as min_seqnum		
						from 
				  			ARCH20&cy..ccaep&cy&ver.(where=(client=&client.))
						group by client, plan
						)
				  where seqnum=min_seqnum
				  ) as b
			 	on (a.plan = b.plan)
	;
	quit;
%end;
%else %do;
	data &outlib..&outfile;
		set &outlib..&outfile;
		plankey = .; 
	run;
%end; 

 proc datasets library=&outlib. noprint;
		delete tmp;
 run;

%mend create_enroll_all;


