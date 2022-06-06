%macro bpd_driver(cy /*Current year*/,
			cpy_file=cpy_enroll /*name of current plan year file(default=cpy_enroll)*/,
			bpd=N /*Y=the first num bpd plans are examined, N=all plans(default)*/,
			outlib=outsas /*name of the output library for working and final files*/,
			n_plans=999999 /*the number of plans to be examings (default 999999 or all)*/,
			ver_set=outsas.versions /*the dataset contains marketscan versions(default outsas.versions)*/,
      /*Setting for identifying plan year: NOT USED*/	
			months=12 /*PlanYear Setting: the number of months to consider (default is 12)*/,
			pct_chg=.1 /*PlanYear Setting: the minimum percentage change to signal a new enrollment year(default is 10%)*/,
            min_pln=100 /*PlanYear Setting: the minimum allowable plan enrollment (default is 100)*/,
            client_rule=0	/*PlanYear Setting: the client-level rule when no plan signal exists: 0=enrollment(default), 1=plans */,
				/*setting for utilization files*/
			id = N /*Utilization files should have plan-specific ids:Y/N (N is default)*/,
   				/*settings for final output*/
			quant=N /*Output quantiles files should have plan-specific ids:Y/N (N is default)*/

);
	/*PHASE 1: IDENTIFY CLIENTS*/
	/*Set the correct version number for the current year*/

	/*set MarketScan versions*/
	/*data _null_;  
		set &ver_set.(where=(year=&cy));
		call symput('ver',put(version, 1. -L));
	run;
	*/

	%if &cy.=15 %then %do;
			%let ver = 1;
	%end;
	%else %if &cy.=14 %then %do;
			%let ver = 2;
	%end;
	%else %do;
			%let ver = 3;
	%end;

	%if &bpd = Y %then
		%do;
			proc sql noprint;
				select distinct client
					into :client1  - :client9999
						from ARCH20&cy..ccaep&cy&ver(where=(plankey is not null));
			quit;
		%end;
	%else
		%do;
			proc sql noprint;
				select distinct client
					into :client1  - :client9999
						from ARCH20&cy..ccaep&cy&ver;
			quit;
		%end;

	%let tot_clients = &sqlobs;	 /*Identifies number of client and avoids rewriting of %sqlobs during loop*/
	%let pln_cnt = 0; /*counter for plans*/

	%do clnts=1 %to &tot_clients %by 1;  /*BEGIN LOOPING THROUGH CLIENTS IDENTIFIED IN PHASE 1 SQL STATEMENT*/
		%if &pln_cnt<=&n_plans %then %do;
			%let cur_client = &&client&clnts;  /*set client parameter for the loop*/

			/*identify all plans for the current client*/
			%plan_year(&cy., &cur_client., 
						outfile=&cpy_file., outlib=&outlib., months=&months.,   
						pct_chg=&pct_chg., min_pln=&min_pln., client_rule=&client_rule., ver_set=&ver_set.
						);

			/*remove any plans for this client without a plankey(if indicated)*/
			%if &cy.=15 %then %do;
					%let ver = 1;
			%end;
			%else %if &cy.=14 %then %do;
					%let ver = 2;
			%end;
			%else %do;
					%let ver = 3;
			%end;

			%if &bpd = Y %then
				%do;
					proc sql noprint;
						select distinct plan, plankey
							into	:plan1	- :plan9999,
									:plankey1 - :plankey9999
							from ARCH20&cy..ccaep&cy&ver(where=(client = &cur_client. AND
																plankey is not null));
					quit;
				%end;
			%else
				%do;
					proc sql noprint;
						select distinct plan, plankey
							into	:plan1	- :plan9999,
									:plankey1 - :plankey9999
							from ARCH20&cy..ccaep&cy&ver(where=(client = &cur_client.));
					quit;
				%end;

			%let tot_plans = &sqlobs;	 /*to avoid rewriting of %sqlobs during loop*/

			%do plns= 1 %to &tot_plans; /*BEGIN LOOPING THROUGH ALL OF THE PLANS FOR THIS CLIENT*/
				%let pln_cnt = %sysfunc(sum(%sysfunc(inputn(&pln_cnt, comma9.)),1)); /*prior year*/
				%if &pln_cnt<=&n_plans %then %do;
					%let cur_plan   = &&plan&plns;
					%let plnkey 	= &&plankey&plns;
					
					data _null_;  				/*set needed parameters for plan from the client output file*/
						set &outlib..&cpy_file.(where=(plan=&cur_plan.));
		  				  call symput('st_year',put(st_year, 2. -L));		
						  call symput('st_month',put(st_month, 2. -L));
						  call symput('ed_year',put(end_year, 2. -L));		
						  call symput('ed_month',put(end_month, 2. -L));
					run;

					%put;	
					%put;
					%put "**************************************************************************************************************";
					%put "*";
					%put "*Client &cur_client is &clnts of &tot_clients";
					%put "*  Current Plan &cur_plan is plan &plns of &tot_plans plans for client &cur_client";
					%put "   Start Year: &st_year.  Start Month: &st_month  End Year: &ed_year  End Month: &ed_month                    ";
					%put "*PLAN COUNT CHECK: &pln_cnt of &n_plans";
					%put "**************************************************************************************************************";
					%put;
					%put;

					/*create plan-level enrollment and utilization files  */
					%util_files (&cur_client., &cur_plan.,        
								 start_year=&st_year., start_month=&st_month., end_year=&ed_year., end_month=&ed_month.,
								 outlib=&outlib., ver_set=&ver_set.);

					/*identify the plan's information		*/
					%deduct_oop(cur_client=&cur_client., cur_plan=&cur_plan., plankey=&plnkey., st_year=&st_year., st_month=&st_month., 
								end_year=&ed_year., end_month=&ed_month., 
							    quant=&quant.,outlib=&outlib.);	

					%if (&clnts=1 AND &plns=1) %then %do;  /*create the final output dataset*/
						data  &outlib..ben_summary_&cy;
							set &outlib..plan_ben_summary;
						run;

						proc datasets lib=&outlib. noprint;
							delete 	plan_ben_summary;
							run;

						%if &quant=Y %then %do;
							data  &outlib..quant_summary_&cy;
								set &outlib..plan_quant_summary;
							run;

							proc datasets lib=&outlib. noprint;
								delete plan_quant_summary;
							run;
						%end;
					%end;
					%else %do;
						proc append
							base = &outlib..ben_summary_&cy
							data = &outlib..plan_ben_summary;
						run;
						
						proc datasets lib=&outlib. noprint;
							delete 	plan_ben_summary;
						run;

						%if &quant=Y %then %do;
							proc append
								base = &outlib..quant_summary_&cy
								data = &outlib..plan_quant_summary;
							run;

							proc datasets lib=&outlib. noprint;
								delete plan_quant_summary;
							run;
						%end;
					%end;
				%end; /*plan count check*/
			%end;  /*plan loop*/

			proc datasets lib=&outlib. noprint;  /*clean up the client-level temp output file*/
				delete &cpy_file.
								;
			run;
		%end; /*plan count check*/
	%end;	/*client loop*/
	

%mend bpd_driver;


