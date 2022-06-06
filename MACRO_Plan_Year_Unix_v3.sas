%macro plan_year(cy /*a two-digit integer identifying the current year of analysis (positional)*/,
				 client /*an integer indicating the marketscan client (positional)*/,
				 months=12 /*the number of months to consider (default is 12)*/,
				 pct_chg=.1 /*the minimum percentage change to signal a new enrollment year(default is 10%)*/,
                 min_pln=100 /*the minimum allowable plan enrollment (default is 100)*/,
                 client_rule=0	/*the client-level rule when no plan signal exists (0=enrollment-default, 1=plans)*/,
				 outfile=client_plan_year /*the output file(default is outsas.client_plan_year) (also used by helper macro and overwritten)*/,
				 outlib=outsas /*the output library (default is outsas)*/,
				 ver_set=outsas.versions /*the dataset contains marketscan versions(default outsas.versions)*/
	); 
 /*MACRO PLAN YEAR														
 **Description: This macro determines the start month and end month for all plans for the identified client
 **
 **ALGORITHM:
 **	Plan year is identified using enrollment files.  The default is to identify each plan separately.  When no 
 ** clear signal for the plan can be identified, the client level signal is used.
 **   The steps are:
 **			Step 1: Create a 36 month (prior, current, and future year) enrollment file 
 **					NOTE: Calls create_enroll_all() macro to create file
 **			Step 2: Identify the start of the cy plan-year for each plan looking at:
 **				a) Jan (cy) start
 **				b) backward for plan start  
 **				c) forward for plan start
 **				d) percentage enrollment change
 **			Step 3: Identify the client-level start of cy plan-year using
 **				a) largest enrollment from plan year
 **				b) greatest number of plans
 **			Step 4: Create plan level start and end file
 **
 **DEPENDENCIES:
 **		MACRO: create_enroll_all()
 **		
 **CHANGE LOG:
 ** ----------------------------------------------------------------------------------------------------------- 
 ** date        | action 									 |developer																												|Developer
 ** ------------+----------------------------------------------------------------------------------------------- 
 ** 20161005		Initial Development of program  			TJF
 ** 20170220  		Adjusted to call helper macro			 	TJF
 ** 20170221		Created dynamic references for outlib		tjf
 **					and outfile
 **					Passed references for helper functions
 **20170306			Removed reference to plankey				tjf
 **20170315			Added Plankey as created in Enroll_All 		tjf
 */	

 /*Step 1: create file and define all years*/
	 %let py = %sysfunc(sum(%sysfunc(inputn(&cy, comma9.)),-1)); /*prior year*/
	 %let fy = %sysfunc(sum(%sysfunc(inputn(&cy, comma9.)), 1)); /*future year*/

	 /*create 36 month enrollment file*/
	 %create_enroll_all(&cy.,&client.,outfile=&outfile.,outlib=&outlib.,ver_set=&ver_set.); /*create transposed enrollment file*/

/*Step 2: Identify Plan-level plan year*/
	data &outlib..plan_st_end /*(keep= plankey client plan stp cy_max st_mth end_mth max_enr_chg rule)*/;
		set &outlib..&outfile.; /*NOTE: This needs to be connected to create_enroll_all output file: default=enroll*/
			/*Identify the plan enrollment using the following hierarchical rules
				1) Test for Jan start (no enrollment in Dec_PY AND enrollement Jan_CY
				2) Scan PY: PY_Month with enrollment with no enrollment prior
				3) Scan CY: CY_Month enrollment with non in next month
				4) Percentage Enrollment Change: Look for a percentage change in order of:
					-Jan start
					-forward and back start
			NOTE: stp variable indicates how plan year was detected using hierarchical look:
				101 : Enrollment in Jan with no enrollment in Dec of prior year
				2xx : Enrollment in PY Month xx with no enrollment in PY month xx-1
				3xx : Enrollment in FY Month xx with no enrollment in FY month xx+1
				4xx : Pct change from PY Dec to CY Jan >= Required Pct_Chg parameter
				5xx : Pct change from PY month xx-1 to PY month xx >= Required Pct_Chg parameter
				6xx : Pct change from FY month xx to FY month xx+1 >= Required Pct_Chg parameter 
			*/

		array py_m {12} m&py.01-m&py.12;
		array cy_m {12} m&cy.01-m&cy.12;
		array fy_m {12} m&fy.01-m&fy.12;
		stp=.;
		rule = &client_rule.;

		cy_max=.;
		cy_n = dim(cy_m);
		do a=1 to dim(cy_m);
			cy_max = max(cy_max, cy_m{a});
			cy_n = cy_n - missing(cy_m{a}); 
		end;

		if (cy_max<&min_pln OR cy_n=0 OR plan=.) then delete;  

		/*Use enrollment patterns to identify plan year*/	
		if (m&cy.01>0 AND missing(m&py.12))  then do;  /*test for Jan start*/
				st_mth 	= &cy.01;
				end_mth	= &cy.12;
				stp=1*100+1;
			end;
		else do i=12 to 2 by -1 until(stp>0);         /*search backward for clear start month*/
				if (py_m{i}>0 & missing(py_m{i-1})) then do;
						st_mth = &py*100 + i;
						end_mth = &cy*100 + (i-1);
						stp = 2*100+i;
					end;  
			end;

		if stp=. then do j=1 to 11 by 1 until(stp>0); /*if no Jan start AND no  prior year start, look forward*/
				if (fy_m{j}>0 AND missing(fy_m{j+1})) then do;
						st_mth  = &cy*100 + j+1;
						end_mth = &fy*100 + j;
						stp=3*100+j;
					end;
			end;

		/*if no clear enrollment pattern, look at pct changes in enrollment*/
		max_enr_chg = .;
		if (abs(m&cy.01 - m&py.12)/m&py.12 ge &pct_chg.)  then do;  /*search for Jan pct start*/
				max_enr_chg = max(max_enr_chg, abs(m&cy.01 - m&py.12)/m&py.12); 
				st_mth 	= &cy.01;
				end_mth	= &cy.12;
				stp=4*100+1;
			end;

		if stp=. then do k=12 to 2 by -1 until(stp>0);/*backward pct search*/
				max_enr_chg = max(max_enr_chg, abs(py_m{k}-py_m{k-1})/py_m{k});
				if((abs(py_m{k}-py_m{k-1})/py_m{k}) ge &pct_chg.) then do;
						st_mth = &py*100 + k;
						end_mth = &cy*100 + (k-1);
						stp=5*100+k;
					end;
			end;
			
		if stp=. then do l=1 to 11 by 1 until(stp>0);/*forward pct search*/
				max_enr_chg = max(max_enr_chg, abs(fy_m{l}-fy_m{l+1})/py_m{l});
				if((abs(fy_m{l}-fy_m{l+1})/py_m{l}) ge &pct_chg.) then do;
						st_mth  = &cy*100 + l+1;
						end_mth = &fy*100 + l;
						stp=6*100+l;
					end;
	end;
	run;

 	proc datasets library=&outlib. noprint;
		delete &outfile.;
 	run;

	/*Identify the Client-level plan year*/
	proc means data=&outlib..plan_st_end(where=(stp ne .)) noprint;
		class st_mth end_mth;
		var cy_max plan;
		output out=&outlib..client_level
			sum(cy_max)=total_max
			n(plan)=plans;
	run;

	proc sort data=&outlib..client_level(where=(st_mth ne . AND end_mth ne .));
		by descending plans total_max;
	run;

	proc sql; /*identify the client-level maxes*/
		create table &outlib..client_max as
			select	a.*
			from &outlib..client_level as a
			having (a.total_max = max(a.total_max)
					OR	
	 			   a.plans = max(a.plans)
			   	  )
		;
		create table &outlib..&outfile. as
			select	a.client,
					a.plan,
					a.plankey,

					case  
						when (a.stp=. and a.rule=0) then b.st_mth
						when (a.stp=. and a.rule=1) then c.st_mth
						else a.st_mth
					end as st_mth,

					case  
						when (a.stp=. and a.rule=0) then b.end_mth
						when (a.stp=. and a.rule=1) then c.end_mth
						else a.end_mth
					end as end_mth,

					case 
						when (a.stp=.) then 700
						else a.stp
					end as stp,

					a.cy_max as max_enroll,

					a.st_mth as pl_st_mth,
					a.end_mth as pl_end_mth,

					b.total_max as client_total_max,
					c.plans   as client_plans_max,	

					b.st_mth  as enroll_st_mth,
					b.end_mth as enroll_end_mth,

					c.st_mth  as plan_st_mth,
					c.end_mth as plan_end_mth

			from &outlib..plan_st_end as a,
				 (select 
				 	bb.*
					from &outlib..client_max as bb
					having (bb.total_max =max(bb.total_max))
				  ) as b,
				  (select
				  	cc.*
					from &outlib..client_max as cc
					having (cc.plans=max(cc.plans))
				  ) as c
		;
	quit;

	data &outlib..&outfile. /*(drop=st_mth end_mth) identify the year and month as separate variables*/;
		set &outlib..&outfile.;
		st_year = round(st_mth,100)/100;
		st_month = st_mth-round(st_mth,100);
		end_year = round(end_mth,100)/100;
		end_month = end_mth-round(end_mth,100);
	run;

	proc datasets library=&outlib. noprint;
		delete plan_st_end;
		delete client_level
		delete client_max
 	run;

%mend plan_year;




