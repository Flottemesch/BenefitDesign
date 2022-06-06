%Macro util_files (
		cur_client /*The current client for analysis (required)*/,
		cur_plan /*The current plan within that client (required)*/,
		start_year /*The year when the plan's benefit begins (required)*/,
		start_month /*The first month of the plan's benefit year (required)*/,
		end_year /*The year when the plan's benefit year ends (required)*/,
		end_month /*The last month of the plan's benefit year (required)*/,
		id = N /*if output files should have plan-specific ids:Y/N (N is default)*/,
		outlib=outsas /*the output library(default outsas)*/,
		ver_set=outsas.versions /*the dataset contains marketscan versions(default outsas.versions)*/
);
	/*MACRO UTILIZATION FILES:  This macro will identify and create four client-level output files
	**	  	1) enroll_cy: A tracking of enrollment for the entire plan year
	**	  	2) outpt: all outpatient utilization
	**		3) inpt: all inpatient utilization
	**		4) rx: all outpatient pharmacy
	**	
	**	Note: A categorical variable, FAC_NET, is created for the outpt and inpt files that
	**		  identified: "F"acility and "N"etwork charges
	**
	** DEVELOPMENT LOG 
	** date        | action 																			|Developer
	** ------------+----------------------------------------------------------------------------------------------- 
	**20170221		Created Macro to separate from BPD deducatable macro									tjf
	**					NOTE: The output files contain only individuals with countinuous enrollment
	**						  it may exclude deaths and undercount family and ind values
	**20170306		Removed any reference to PlanKey														tjf
	*/
/*FOR DEBUGGING: STEP BY STEP EXECUTION
	%LET 	cur_client=135;
	%LET 	cur_plan=1059 ;
	%LET 	start_year=12 ;
	%LET 	start_month=1 ;
	%LET 	end_year=12 ;
	%LET 	end_month=12 ;
	%LET 	outlib=outsas ;
	%LET 	ver_set=versions ;

run;
*/
	/*
	data _null_;  
		set &ver_set.(where=(year=&start_year.));
		call symput('st_year_ver',put(version, 1. -L));
	run;
	data _null_;	
		set &ver_set.(where=(year=&end_year.));
		call symput('end_year_ver',put(version, 1. -L));
	run;
	*/
	
	%if &start_year.=15 %then %do;
			%let st_year_ver = 1;
	%end;
	%else %if &start_year.=14 %then %do;
			%let st_year_ver = 2;
	%end;
	%else %do;
			%let st_year_ver = 3;
	%end;
	
	%if &end_year.=15 %then %do;
			%let end_year_ver = 1;
	%end;
	%else %if &end_year.=14 %then %do;
			%let end_year_ver = 2;
	%end;
	%else %do;
			%let end_year_ver = 3;
	%end;
	
	%if &start_year = &end_year %then %do;  /*identify continuously enrollment persons*/
			data &outlib..enroll_cy (where=(client=&cur_client 
 										    AND enrolid is not missing
											)
									 keep=  client enrolid efamid hlthplan rx
											plan&start_month. - plan&end_month.
									 );
				set ARCH20&start_year..ccaea&start_year&st_year_ver;
				array plan{12} PLAN1-PLAN12;
				do a = &start_month to &end_month;
						if plan{a} ne &cur_plan then delete;
					end;
			run;

			data &outlib..outpt;  /*Identify the outpatient claims for the client.  
								  Create a variable, FAC_NET, to parse inpatient facility and provider amounts as tdifferent coin and copays apply
															*/
				set ARCH20&start_year..ccaeo&start_year&st_year_ver (where=(client=&cur_client 
																			  AND PLAN=&cur_plan
																			  AND enrolid is not missing
																			  AND month(svcdate) ge &start_month		  
																			  AND month(svcdate) le &end_month
																						));
				if FACPROF = 'P' & PAIDNTWK = 'Y' then
					 	 FAC_NET = 'P_Y';
				else if FACPROF = 'F' & PAIDNTWK = 'Y' then
					 	 FAC_NET = 'F_Y';
				else if FACPROF = 'P' & PAIDNTWK = 'N' then
					 	 FAC_NET = 'F_N';
				else FAC_NET = 'P_N';
			run;


			data &outlib..inpt;  /*Identify the inpatient claims for the client.  
								 Create a variable, FAC_NET, to parse inpatient facility and provider amounts as tdifferent coin and copays apply
															*/
				set ARCH20&start_year..ccaes&start_year&st_year_ver (where=(client=&cur_client 
																  AND PLAN=&cur_plan
																  AND enrolid is not missing
																  AND month(svcdate) ge &start_month		  
																  AND month(svcdate) le &end_month
				 													));
				if FACPROF = 'P' & PAIDNTWK = 'Y' then
						 	 FAC_NET = 'P_Y';
				else if FACPROF = 'F' & PAIDNTWK = 'Y' then
						 	 FAC_NET = 'F_Y';
				else if FACPROF = 'P' & PAIDNTWK = 'N' then
						 	 FAC_NET = 'F_N';
				else FAC_NET = 'P_N';
			run;

			data &outlib..rx;  /*Identify the rx claims for the client
			  				 	NOTE: FAC_NET is not needed and not created
							*/
				set ARCH20&start_year..ccaed&start_year&st_year_ver  (where=(client=&cur_client 
															  		 	AND PLAN=&cur_plan
															  			AND enrolid is not missing
																  		AND month(svcdate) ge &start_month		  
																  		AND month(svcdate) le &end_month
				 														));
					
			run;

		%end;
	%else %do;/*Enrollment accross multiple years*/

			data &outlib..enroll_st_yr (where=(client=&cur_client 
 										    AND enrolid is not missing
											)
									 	keep= client 
											enrolid efamid hlthplan rx
											plan&start_month. - plan12
								);
				set ARCH20&start_year..ccaea&start_year&st_year_ver;
 				array plan{12} PLAN1-PLAN12;
				do a = &start_month to 12;
					  	if plan{a} ne &cur_plan then delete;
				  end;
		 	run;

			data &outlib..enroll_end_yr(where=(client=&cur_client 
 										    AND enrolid is not missing
											)
									 	keep = CLIENT 
										 	 PLAN1-PLAN&end_month
											 ENROLID EFAMID HLTHPLAN RX 
															 );
				set ARCH20&end_year..ccaea&end_year&end_year_ver;
				array plan{12} PLAN1-PLAN12;						
				do a = 1 to &end_month;
					   if PLAN{a} ne &cur_plan then delete;
					end;
			run;
					
			data &outlib..enroll_cy;  /*create continuous enrollment file*/
				merge outsas.enroll_st_yr (in=styr)
					  outsas.enroll_end_yr(in=edyr);
				by client enrolid efamid hlthplan rx;
				if (styr AND edyr) then output;
			run;

			proc datasets library=&outlib noprint;
				delete enroll_st_yr;
				delete enroll_end_yr;
			run;

			data &outlib..outpt;  /*Identify the outpatient claims for the client.  
								  Create a variable, FAC_NET, to parse inpatient facility and provider amounts as tdifferent coin and copays apply
															*/
				set ARCH20&start_year..ccaeo&start_year&st_year_ver. (where=(client=&cur_client 
																			  AND PLAN=&cur_plan
																			  AND enrolid is not missing
																			  AND month(svcdate) ge &start_month		  
																						))
				   ARCH20&end_year..ccaeo&end_year&end_year_ver     (where=(client=&cur_client 
																			  AND PLAN=&cur_plan
																			  AND enrolid is not missing
																			  AND month(svcdate) le &end_month		  
																						))
				;

				if FACPROF = 'P' & PAIDNTWK = 'Y' then
					 	 FAC_NET = 'P_Y';
				else if FACPROF = 'F' & PAIDNTWK = 'Y' then
					 	 FAC_NET = 'F_Y';
				else if FACPROF = 'P' & PAIDNTWK = 'N' then
					 	 FAC_NET = 'F_N';
				else FAC_NET = 'P_N';
			run;

			data &outlib..inpt;  /*Identify the inpatient claims for the client.  
								 Create a variable, FAC_NET, to parse inpatient facility and provider amounts as tdifferent coin and copays apply
															*/
				set ARCH20&start_year..ccaes&start_year&st_year_ver (where=(client=&cur_client 
																  AND PLAN=&cur_plan
																  AND enrolid is not missing
																  AND month(svcdate) ge &start_month		  
				 													))
				    ARCH20&end_year..ccaes&end_year&end_year_ver (where=(client=&cur_client 
																  AND PLAN=&cur_plan
																  AND enrolid is not missing		  
																  AND month(svcdate) le &end_month
				 													))
				;
				if FACPROF = 'P' & PAIDNTWK = 'Y' then
						 	 FAC_NET = 'P_Y';
				else if FACPROF = 'F' & PAIDNTWK = 'Y' then
						 	 FAC_NET = 'F_Y';
				else if FACPROF = 'P' & PAIDNTWK = 'N' then
						 	 FAC_NET = 'F_N';
				else FAC_NET = 'P_N';
			run;

			data &outlib..rx;  /*Identify the rx claims for the client
			  				 	NOTE: FAC_NET is not needed and not created
							*/
				set ARCH20&start_year..ccaed&start_year&st_year_ver  (where=(client=&cur_client 
															  		 	AND PLAN=&cur_plan
															  			AND enrolid is not missing
																  		AND month(svcdate) ge &start_month
				 														))
				    ARCH20&end_year..ccaed&end_year&end_year_ver  (where=(client=&cur_client 
															  		 	AND PLAN=&cur_plan
															  			AND enrolid is not missing	  
																  		AND month(svcdate) le &end_month
				 														))
				;
					
			run;
		%end;

		proc sql;
			create table &outlib..outpt as /*filter with the enrollment file*/
				select  b.*
				from 	&outlib..enroll_cy as a
					INNER JOIN
				  		&outlib..outpt as b
					on (a.enrolid = b.enrolid)
				order by b.enrolid, b.efamid, b.svcdate, b.pddate;

			create table &outlib..inpt as /*filter with the enrollment file*/
				select  b.*
				from 	&outlib..enroll_cy as a
					INNER JOIN
				  		&outlib..inpt as b
					on (a.enrolid = b.enrolid)
				order by b.enrolid, b.efamid, b.svcdate, b.pddate;

			create table &outlib..rx as /*filter with the enrollment file*/
				select  b.*
				from 	&outlib..enroll_cy as a
					INNER JOIN
				  		&outlib..rx as b
					on (a.enrolid = b.enrolid)
				order by b.enrolid, b.efamid, b.svcdate, b.pddate;
		quit;

		%if &id=Y %then %do;
			proc datasets library=&outlib. noprint;
				change 
					enroll_cy	=enroll_cy_&cur_client._&cur_plan  
					outpt		=outpt_&cur_client._&cur_plan  
					inpt		=inpt_&cur_client._&cur_plan  
					rx			=rx_&cur_client._&cur_plan
				; 
			run;
		%end;
%mend util_files;

