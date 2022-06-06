%Macro deduct_oop (
		cur_client /*The current client for analysis (required)*/,
		cur_plan /*The current plan within that client (required)*/,
		plankey /*The bpd plankey or null (required)*/,
		st_year /*The plan's start year*/,
		st_month /*The plan's start month*/,
		end_year /*The plan's end year*/,
		end_month /*The plan's end month*/,
		enroll_cy=enroll_cy /*The plan's current year enrollment file*/,
		outpt=outpt /*The plan's outpatient servies file*/,
		inpt=inpt /*the plan's inpatient services file*/,
		del_input = Y /*delete the input files N/Y(default)*/,
		rx=rx /*the plan's rx services file*/,
		id = N /*if input/output files should have plan-specific ids:Y/N (N is default)*/,
		quant=N /*output quantiles of deduct and oop (0 is default)*/,
		outlib=outsas /*the output library(default outsas)*/
);
	/*MACRO DEDUCT_OOP:  This macro will identify the plan's deductable, oop max and type.
	**					 it creates two output datasets:
	**	  	1) plan_ben_summary: a one item files with the plans deducatable and oop values
	**	  	2) plan_quant_summary;: a multi-line files with quantiles for deductable and oop amounts
	**	
	**
	**	NOTE: INTERPRETATION OF PLAN_BEN_SUMMARY VARIABLES
	**		The plan_ben_summary output dataset summarizes the outpatient and inpatient claims 
	**		and the outpatient pharmacy tables.
	**	
	**		The following ABCDE naming convention is used in the plan_ben_summary dataset first assigned here:
	**			A: Permitted Values: (F)amily or (I)ndividual
	**			B: Permitted Values: (D)eductible, (O)ut of pocket, (C)oinsurance {Coinsurance amount (COIN) are calculated and available but currently not reported}
	**			C: Permitted Values: (N)etwork, (O)ut of Network, (B)oth
	**			D: Permitted Values: Outpatient Presc(R)iptions, (S)ervices including facility charges, (B)oth
	**			E: Permitted Values:  (V)alue, (C)ategory, (N)umber or count
	**
	**DEPENDENCIES:
	**   The four output files created by the util_files Macro are required.  NOTE: The macro assumes only a single plans data are provided
	**
	** DEVELOPMENT LOG 
	** date        | action 																			|Developer
	** ------------+----------------------------------------------------------------------------------------------- 
	**20170222		Created Macro to separate from BPD deducatable macro									tjf
	**					NOTE: The output files contain only individuals with countinuous enrollment
	**						  it may exclude deaths and undercount family and ind values
	**
	**20170228		Changed the n_test algorithm to include plans without Rx coverage						tjf
	**
	**20170301		Added plnkey macro variable and added to plan_ben_summary output file					tjf
	**				Add initial null values for the tot_enroll, tot_fam, and plnkey local macro variables  
    **				re-ordered operations
	**				Added del_input macro parameter
	**20170302		Change plnkey and hlthplan to be associated with a datastep in STEP 4					tjf
	**20170302		removed reference to plankey															tjf
	**20170308		Reincorporated plankey as an input parameter											tjf
	**					NOTE: this is populated directly from the Driver macro
	*/
/*FOR DEBUGGING: STEP BY STEP EXECUTION
	%LET 	cur_client=135;
	%LET 	cur_plan=512 ;
	%LET	enroll_cy = enroll_cy;
	%let	outpt = outpt;
	%let	inpt = inpt;
	%let 	rx=rx;
	%LET 	outlib=outsas ;
	%LET 	ver_set=versions ;
	%LET	id = 0
	%Let	quant=0
run;
*/


/*initial output values to avoid errors*/
%let tot_enroll = .;
%let tot_fam = .;

/*setup internal parameters according to id parameter*/
%if &id. = Y %then %do;	
	%let enroll_cy_in = &enroll_cy._&cur_client._&cur_plan.;
	%let outpt_in = &outpt._&cur_client._&cur_plan.;
	%let inpt_in = &inpt._&cur_client._&cur_plan.;
	%let rx_in = &rx._&cur_client._&cur_plan.;
%end;
%else %do;
	%let enroll_cy_in = &enroll_cy;
	%let outpt_in = &outpt;
	%let inpt_in = &inpt;
	%let rx_in = &rx;
%end;

/*Initialize output datasets*/
data plan_ben_summary;
	attrib
			CLIENT format=8.
			PLAN format=8.
			PLANKEY format=8.
			N_deduct format=8.
			N_fam format=8.
			rx format=8.
			BDBBC format=8.
			BOBBC format=8.
			IDNSV format=8.
			IDNSN format=8.
			IDNSC format=8.
			FDNSV format=8.
			FDNSN format=8.
			FDNSC format=8.
			IDOSV format=8.
			IDOSN format=8.
			IDOSC format=8.
			FDOSV format=8.
			FDOSN format=8.
			FDOSC format=8.
			IDNRV format=8.
			IDNRN format=8.
			IDNRC format=8.
			FDNRV format=8.
			FDNRN format=8.
			FDNRC format=8.
			IDORV format=8.
			IDORN format=8.
			IDORC format=8.
			FDORV format=8.
			FDORN format=8.
			FDORC format=8.
			IDBRV format=8.
			IDBRN format=8.
			IDBRC format=8.
			FDBRV format=8.
			FDBRN format=8.
			FDBRC format=8.
			IDBSV format=8.
			IDBSN format=8.
			IDBSC format=8.
			FDBSV format=8.
			FDBSN format=8.
			FDBSC format=8.
			IDNBV format=8.
			IDNBN format=8.
			IDNBC format=8.
			FDNBV format=8.
			FDNBN format=8.
			FDNBC format=8.
			IDOBV format=8.
			IDOBN format=8.
			IDOBC format=8.
			FDOBV format=8.
			FDOBN format=8.
			FDOBC format=8.
			IDBBV format=8.
			IDBBN format=8.
			IDBBC format=8.
			FDBBV format=8.
			FDBBN format=8.
			FDBBC format=8.
			IONSV format=8.
			IONSN format=8.
			IONSC format=8.
			FONSV format=8.
			FONSN format=8.
			FONSC format=8.
			IOOSV format=8.
			IOOSN format=8.
			IOOSC format=8.
			FOOSV format=8.
			FOOSN format=8.
			FOOSC format=8.
			IONRV format=8.
			IONRN format=8.
			IONRC format=8.
			FONRV format=8.
			FONRN format=8.
			FONRC format=8.
			IOORV format=8.
			IOORN format=8.
			IOORC format=8.
			FOORV format=8.
			FOORN format=8.
			FOORC format=8.
			IOBRV format=8.
			IOBRN format=8.
			IOBRC format=8.
			FOBRV format=8.
			FOBRN format=8.
			FOBRC format=8.
			IOBSV format=8.
			IOBSN format=8.
			IOBSC format=8.
			FOBSV format=8.
			FOBSN format=8.
			FOBSC format=8.
			IONBV format=8.
			IONBN format=8.
			IONBC format=8.
			FONBV format=8.
			FONBN format=8.
			FONBC format=8.
			IOOBV format=8.
			IOOBN format=8.
			IOOBC format=8.
			FOOBV format=8.
			FOOBN format=8.
			FOOBC format=8.
			IOBBV format=8.
			IOBBN format=8.
			IOBBC format=8.
			FOBBV format=8.
			FOBBN format=8.
			FOBBC format=8.
			;
	stop;
run;

%if &quant=Y %then %do;
	data plan_quant_summary;
		attrib
				VarName  length=$20
				Quantile length=$10
				Estimate format=8.
				client  format=8.
				plan  format=8.;
		stop;
	run;
%end;

/*check for any enrollment in the output files created by the util_files macro*/
	/*NOTE: non-zero enrollment, outpatient utilization, inpatient utilization, and pharmacy is examined*/
	/*Test for utilization and set plnkey variable*/
%let n_test=0;
data _null_;
	set &outlib..&enroll_cy_in.;	
    call symput('n_test',put(_n_, 8. -L));
run;

/*check for utilization within each category for plan*/
%if (&n_test. >0) %then %do;
	data _null_;
		set &outlib..&outpt_in.;	
	    call symput('n_test',put(_n_, 8. -L));
	run;
%end;

%if (&n_test. >0) %then %do;
	data _null_;
		set &outlib..&inpt_in.;	
	    call symput('n_test',put(_n_, 8. -L));
	run;
%end;

%if (&n_test. >0) %then %do;  /*NOTE: a check of rx=1 in a higher plan-level file could be used*/
	data _null_;
		set &outlib..&rx_in.;	
	    call symput('n_test',put(_n_, 8. -L));
	run;
%end;

%if (&n_test.=0) %then %do;	/*create two null output datasets*/
	%put "**********************************************************";
	%put ;
	%put "No Utilization for Client &cur_client AND Plan &cur_plan";
	%put "in one or more utilization categories";
	%put;
	%put "**********************************************************";
 /*	%goto noutildata;    Dropped 20170228  */
%end;

/*Create tot_enroll and tot_fam macro variables for final output plan_ben_summary output file*/
proc sql; 
	select /*unique enrollees*/
		count(enrolid) into :tot_enroll
	from &outlib..&enroll_cy_in.
	group by client;

	select  /*unique families*/
		count(a.efamid) into :tot_fam
	from 
		(select 	
				min(efamid) as efamid,
				min(client) as client
		 from &outlib..&enroll_cy_in.
		 group by efamid) as a
	group by client;
quit;

/*BEGIN ALGORITHM FOR DEDUCTABLE AND OOP DETECTION*/
	/*NOTE: This macro assumes plan-level date.  So, the plan variables is dropped in this step*/
proc sql;  
/*STEP 1: categorize the claims
	/*Outpatient Claims */
	create table &outlib..outpt1 as
		select 	a.enrolid, 
				a.efamid, 
				a.client,
				a.svcdate format MMDDYY10. as ser_date,
				a.PDDATE format MMDDYY10. as paid_date,
					case PAIDNTWK
						when "P_Y" then a.pay
						else 0
					end 
				as pay_ntwk_prov_out,
					case PAIDNTWK
						when "P_Y" then a.deduct
						else 0
					end 
				as deduct_ntwk_prov_out,					 			
					case PAIDNTWK
						when "P_Y" then a.copay
						else 0
					end 
				as copay_ntwk_prov_out,					 			
					case PAIDNTWK
						when "P_Y" then a.coins
						else 0
					end 
				as coins_ntwk_prov_out,					 			
					case PAIDNTWK
						when "P_Y" then a.cob
						else 0
					end 
				as cob_ntwk_prov_out,						 			
					case PAIDNTWK
						when "P_Y" then a.netpay
						else 0
					end 
				as netpay_ntwk_prov_out,					 							 			
					case PAIDNTWK
						when "F_Y" then a.pay
						else 0
					end 
				as pay_ntwk_fac_out,
					case PAIDNTWK
						when "F_Y" then a.deduct
						else 0
					end 
				as deduct_ntwk_fac_out,					 			
					case PAIDNTWK
						when "F_Y" then a.copay
						else 0
					end 
				as copay_ntwk_fac_out,					 			
					case PAIDNTWK
						when "F_Y" then a.coins
						else 0
					end 
				as coins_ntwk_fac_out,					 			
					case PAIDNTWK
						when "F_Y" then a.cob
						else 0
					end 
				as cob_ntwk_fac_out,						 			
					case PAIDNTWK
						when "F_Y" then a.netpay
						else 0
					end 
				as netpay_ntwk_fac_out,		
					case PAIDNTWK
						when "P_N" then a.pay
						else 0
					end 
				as pay_nonntwk_prov_out,
					case PAIDNTWK
						when "P_N" then a.deduct
						else 0
					end 
				as deduct_nonntwk_prov_out,					 			
					case PAIDNTWK
						when "P_N" then a.copay
						else 0
					end 
				as copay_nonntwk_prov_out,					 			
					case PAIDNTWK
						when "P_N" then a.coins
						else 0
					end 
				as coins_nonntwk_prov_out,					 			
					case PAIDNTWK
						when "P_N" then a.cob
						else 0
					end 
				as cob_nonntwk_prov_out,						 			
					case PAIDNTWK
						when "P_N" then a.netpay
						else 0
					end 
				as netpay_nonntwk_prov_out,					 							 			
					case PAIDNTWK
						when "F_N" then a.pay
						else 0
					end 
				as pay_nonntwk_fac_out,
					case PAIDNTWK
						when "F_N" then a.deduct
						else 0
					end 
				as deduct_nonntwk_fac_out,					 			
					case PAIDNTWK
						when "F_N" then a.copay
						else 0
					end 
				as copay_nonntwk_fac_out,					 			
					case PAIDNTWK
						when "F_N" then a.coins
						else 0
					end 
				as coins_nonntwk_fac_out,					 			
					case PAIDNTWK
						when "F_N" then a.cob
						else 0
					end 
				as cob_nonntwk_fac_out,						 			
					case PAIDNTWK
						when "F_N" then a.netpay
						else 0
					end 
				as netpay_nonntwk_fac_out,				 			
				a.pay as pay_out,
				a.deduct as deduct_out,
				a.copay as copay_out,
				a.coins as coins_out,
				a.cob as cob_out,		 
				a.netpay as netpay_out
	from &outlib..&outpt_in as a;

	/*Inpatient Care*/
	create table &outlib..inpt1 as  /*Summarize the inpatient billing data*/
	select 	 	a.enrolid, 
				a.efamid, 
				a.client,
				a.svcdate format MMDDYY10. as ser_date,
				a.PDDATE format MMDDYY10. as paid_date,
					case FAC_NET
						when "P_Y" then a.pay
						else 0
					end 
				as pay_ntwk_prov_in,
					case FAC_NET
						when "P_Y" then a.deduct
						else 0
					end 
				as deduct_ntwk_prov_in,					 			
					case FAC_NET
						when "P_Y" then a.copay
						else 0
					end 
				as copay_ntwk_prov_in,					 			
					case FAC_NET
						when "P_Y" then a.coins
						else 0
					end 
				as coins_ntwk_prov_in,					 			
					case FAC_NET
						when "P_Y" then a.cob
						else 0
					end 
				as cob_ntwk_prov_in,						 			
					case FAC_NET
						when "P_Y" then a.netpay
						else 0
					end 
				as netpay_ntwk_prov_in,					 							 			
					case FAC_NET
						when "F_Y" then a.pay
						else 0
					end 
				as pay_ntwk_fac_in,
					case FAC_NET
						when "F_Y" then a.deduct
						else 0
					end 
				as deduct_ntwk_fac_in,					 			
					case FAC_NET
						when "F_Y" then a.copay
						else 0
					end 
				as copay_ntwk_fac_in,					 			
					case FAC_NET
						when "F_Y" then a.coins
						else 0
					end 
				as coins_ntwk_fac_in,					 			
					case FAC_NET
						when "F_Y" then a.cob
						else 0
					end 
				as cob_ntwk_fac_in,						 			
					case FAC_NET
						when "F_Y" then a.netpay
						else 0
					end 
				as netpay_ntwk_fac_in,					 	
					case FAC_NET
						when "P_N" then a.pay
						else 0
					end 
				as pay_nonntwk_prov_in,
					case FAC_NET
						when "P_N" then a.deduct
						else 0
					end 
				as deduct_nonntwk_prov_in,					 			
					case FAC_NET
						when "P_N" then a.copay
						else 0
					end 
				as copay_nonntwk_prov_in,					 			
					case FAC_NET
						when "P_N" then a.coins
						else 0
					end 
				as coins_nonntwk_prov_in,					 			
					case FAC_NET
						when "P_N" then a.cob
						else 0
					end 
				as cob_nonntwk_prov_in,						 			
					case FAC_NET
						when "P_N" then a.netpay
						else 0
					end 
				as netpay_nonntwk_prov_in,					 							 			
					case FAC_NET
						when "F_N" then a.pay
						else 0
					end 
				as pay_nonntwk_fac_in,
					case FAC_NET
						when "F_N" then a.deduct
						else 0
					end 
				as deduct_nonntwk_fac_in,					 			
					case FAC_NET
						when "F_N" then a.copay
						else 0
					end 
				as copay_nonntwk_fac_in,					 			
					case FAC_NET
						when "F_N" then a.coins
						else 0
					end 
				as coins_nonntwk_fac_in,					 			
					case FAC_NET
						when "F_N" then a.cob
						else 0
					end 
				as cob_nonntwk_fac_in,						 			
					case FAC_NET
						when "F_N" then a.netpay
						else 0
					end 
				as netpay_nonntwk_fac_in,				 			
				a.pay as pay_in,
				a.deduct as deduct_in,
				a.copay as copay_in,
				a.coins as coins_in,
				a.cob as cob_in,		 
				a.netpay as netpay_in
	from &outlib..&inpt_in as a;

	/*Prescriptions */
	create table &outlib..rx1 as 
		select  a.enrolid, 
				a.efamid, 
				a.client,
				a.svcdate format MMDDYY10. as ser_date,
				a.PDDATE format MMDDYY10. as paid_date,
					case PAIDNTWK
						when "Y" then a.AWP
						else 0
					end 
				as pay_ntwk_rx,
					case PAIDNTWK
						when "Y" then a.DEDUCT
						else 0
					end 
				as deduct_ntwk_rx,					 			
					case PAIDNTWK
						when "Y" then a.COPAY
						else 0
					end 
				as copay_ntwk_rx,					 			
					case PAIDNTWK
						when "Y" then a.COINS
						else 0
					end 
				as coins_ntwk_rx,					 			
					case PAIDNTWK
						when "Y" then  a.COB
						else 0
					end 
				as cob_ntwk_rx,						 			
					case PAIDNTWK
						when "Y" then a.NETPAY
						else 0
					end 
				as netpay_ntwk_rx,					 							 			
					case PAIDNTWK
						when "N" then a.AWP
						else 0
					end 
				as pay_nonntwk_rx,
					case PAIDNTWK
						when "N" then a.DEDUCT
						else 0
					end 
				as deduct_nonntwk_rx,					 			
					case PAIDNTWK
						when "N" then a.COPAY
						else 0
					end 
				as copay_nonntwk_rx,					 			
					case PAIDNTWK
						when "N" then a.COINS
						else 0
					end 
				as coins_nonntwk_rx,					 			
					case PAIDNTWK
						when "N" then  a.COB
						else 0
					end 
				as cob_nonntwk_rx,						 			
					case PAIDNTWK
						when "N" then a.NETPAY
						else 0
					end 
				as netpay_nonntwk_rx,		
					a.AWP as pay_rx,
					a.DEDUCT as deduct_rx,
					a.COPAY as copay_rx,
					a.COINS as coins_rx,
					a.COB as cob_rx,
					a.NETPAY as netpay_rx
	from &outlib..&rx_in as a;
quit;

proc sql;
/*STEP 2: aggregate to plan year*/
	create table &outlib..outpt_dt as  
	select 	
		min(enrolid) as enrolid,
		min(efamid) as efamid,
		min(client) as client,		 

		sum(pay_ntwk_prov_out) as pay_ntwk_prov_out,
		sum(deduct_ntwk_prov_out) as deduct_ntwk_prov_out,
		sum(copay_ntwk_prov_out) as copay_ntwk_prov_out,
		sum(coins_ntwk_prov_out) as coins_ntwk_prov_out,
		sum(cob_ntwk_prov_out) as cob_ntwk_prov_out,
		sum(netpay_ntwk_prov_out) as netpay_ntwk_prov_out,	  			 

		sum(pay_ntwk_fac_out) as pay_ntwk_fac_out,
		sum(deduct_ntwk_fac_out) as deduct_ntwk_fac_out,
		sum(copay_ntwk_fac_out) as copay_ntwk_fac_out,
		sum(coins_ntwk_fac_out) as coins_ntwk_fac_out,
		sum(cob_ntwk_fac_out) as cob_ntwk_fac_out,
		sum(netpay_ntwk_fac_out) as netpay_ntwk_fac_out,	  			 

		sum(pay_nonntwk_prov_out) as pay_nonntwk_prov_out,
		sum(deduct_nonntwk_prov_out) as deduct_nonntwk_prov_out,
		sum(copay_nonntwk_prov_out) as copay_nonntwk_prov_out,
		sum(coins_nonntwk_prov_out) as coins_nonntwk_prov_out,
		sum(cob_nonntwk_prov_out) as cob_nonntwk_prov_out,
		sum(netpay_nonntwk_prov_out) as netpay_nonntwk_prov_out,	  			 

		sum(pay_nonntwk_fac_out) as pay_nonntwk_fac_out,
		sum(deduct_nonntwk_fac_out) as deduct_nonntwk_fac_out,
		sum(copay_nonntwk_fac_out) as copay_nonntwk_fac_out,
		sum(coins_nonntwk_fac_out) as coins_nonntwk_fac_out,
		sum(cob_nonntwk_fac_out) as cob_nonntwk_fac_out,
		sum(netpay_nonntwk_fac_out) as netpay_nonntwk_fac_out,

		sum(pay_out) as pay_out,
		sum(deduct_out) as deduct_out,
		sum(copay_out) as copay_out,
		sum(coins_out) as coins_out,
		sum(cob_out) as cob_out,
		sum(netpay_out) as netpay_out

	from &outlib..outpt1
		group by enrolid, efamid, client;

	create table &outlib..inpt_dt as  
	select 	min(enrolid) as enrolid,
		min(efamid) as efamid,
		min(client) as client,		 

		sum(pay_ntwk_prov_in) as pay_ntwk_prov_in,
		sum(deduct_ntwk_prov_in) as deduct_ntwk_prov_in,
		sum(copay_ntwk_prov_in) as copay_ntwk_prov_in,
		sum(coins_ntwk_prov_in) as coins_ntwk_prov_in,
		sum(cob_ntwk_prov_in) as cob_ntwk_prov_in,
		sum(netpay_ntwk_prov_in) as netpay_ntwk_prov_in,	  			 

		sum(pay_ntwk_fac_in) as pay_ntwk_fac_in,
		sum(deduct_ntwk_fac_in) as deduct_ntwk_fac_in,
		sum(copay_ntwk_fac_in) as copay_ntwk_fac_in,
		sum(coins_ntwk_fac_in) as coins_ntwk_fac_in,
		sum(cob_ntwk_fac_in) as cob_ntwk_fac_in,
		sum(netpay_ntwk_fac_in) as netpay_ntwk_fac_in,	  			 

		sum(pay_nonntwk_prov_in) as pay_nonntwk_prov_in,
		sum(deduct_nonntwk_prov_in) as deduct_nonntwk_prov_in,
		sum(copay_nonntwk_prov_in) as copay_nonntwk_prov_in,
		sum(coins_nonntwk_prov_in) as coins_nonntwk_prov_in,
		sum(cob_nonntwk_prov_in) as cob_nonntwk_prov_in,
		sum(netpay_nonntwk_prov_in) as netpay_nonntwk_prov_in,	  			 

		sum(pay_nonntwk_fac_in) as pay_nonntwk_fac_in,
		sum(deduct_nonntwk_fac_in) as deduct_nonntwk_fac_in,
		sum(copay_nonntwk_fac_in) as copay_nonntwk_fac_in,
		sum(coins_nonntwk_fac_in) as coins_nonntwk_fac_in,
		sum(cob_nonntwk_fac_in) as cob_nonntwk_fac_in,
		sum(netpay_nonntwk_fac_in) as netpay_nonntwk_fac_in,

		sum(pay_in) as pay_in,
		sum(deduct_in) as deduct_in,
		sum(copay_in) as copay_in,
		sum(coins_in) as coins_in,
		sum(cob_in) as cob_in,
		sum(netpay_in) as netpay_in	  		

	from &outlib..inpt1
		group by enrolid, efamid, client;

	create table &outlib..rx_dt as  
	select 	min(enrolid) as enrolid,
		min(efamid) as efamid,
		min(client) as client,		 

		sum(pay_ntwk_rx) as pay_ntwk_rx,
		sum(deduct_ntwk_rx) as deduct_ntwk_rx,
		sum(copay_ntwk_rx) as copay_ntwk_rx,
		sum(coins_ntwk_rx) as coins_ntwk_rx,
		sum(cob_ntwk_rx) as cob_ntwk_rx,
		sum(netpay_ntwk_rx) as netpay_ntwk_rx,

		sum(pay_nonntwk_rx) as pay_nonntwk_rx,
		sum(deduct_nonntwk_rx) as deduct_nonntwk_rx,
		sum(copay_nonntwk_rx) as copay_nonntwk_rx,
		sum(coins_nonntwk_rx) as coins_nonntwk_rx,
		sum(cob_nonntwk_rx) as cob_nonntwk_rx,
		sum(netpay_nonntwk_rx) as netpay_nonntwk_rx,		  			 

		sum(pay_rx) as pay_rx,
		sum(deduct_rx) as deduct_rx,
		sum(copay_rx) as copay_rx,
		sum(coins_rx) as coins_rx,
		sum(cob_rx) as cob_rx,
		sum(netpay_rx) as netpay_rx	  		

	from &outlib..rx1
		group by enrolid, efamid, client;
quit;

proc sql;
/*STEP 3: merge the files together for total combined utilization file*/
	create table &outlib..merge1 as /*merge inpatient and outpatient*/
	select 
		coalesce(a.enrolid, b.enrolid) as enrolid,
		coalesce(a.efamid,b.efamid) as efamid,  
		coalesce(a.client,b.client) as client,

		a.pay_ntwk_prov_in as pay_ntwk_prov_in,
		a.deduct_ntwk_prov_in  as deduct_ntwk_prov_in,
		a.copay_ntwk_prov_in  as copay_ntwk_prov_in,
		a.coins_ntwk_prov_in  as coins_ntwk_prov_in,
		a.cob_ntwk_prov_in  as cob_ntwk_prov_in,
		a.netpay_ntwk_prov_in  as netpay_ntwk_prov_in,	  			 

		a.pay_ntwk_fac_in  as pay_ntwk_fac_in,
		a.deduct_ntwk_fac_in  as deduct_ntwk_fac_in,
		a.copay_ntwk_fac_in  as copay_ntwk_fac_in,
		a.coins_ntwk_fac_in  as coins_ntwk_fac_in,
		a.cob_ntwk_fac_in  as cob_ntwk_fac_in,
		a.netpay_ntwk_fac_in  as netpay_ntwk_fac_in,	  			 

		a.pay_nonntwk_prov_in  as pay_nonntwk_prov_in,
		a.deduct_nonntwk_prov_in  as deduct_nonntwk_prov_in,
		a.copay_nonntwk_prov_in  as copay_nonntwk_prov_in,
		a.coins_nonntwk_prov_in  as coins_nonntwk_prov_in,
		a.cob_nonntwk_prov_in  as cob_nonntwk_prov_in,
		a.netpay_nonntwk_prov_in  as netpay_nonntwk_prov_in,	  			 

		a.pay_nonntwk_fac_in  as pay_nonntwk_fac_in,
		a.deduct_nonntwk_fac_in  as deduct_nonntwk_fac_in,
		a.copay_nonntwk_fac_in  as copay_nonntwk_fac_in,
		a.coins_nonntwk_fac_in  as coins_nonntwk_fac_in,
		a.cob_nonntwk_fac_in  as cob_nonntwk_fac_in,
		a.netpay_nonntwk_fac_in  as netpay_nonntwk_fac_in,

		a.pay_in  as pay_in,
		a.deduct_in  as deduct_in,
		a.copay_in  as copay_in,
		a.coins_in  as coins_in,
		a.cob_in  as cob_in,
		a.netpay_in  as netpay_in,

		b.pay_ntwk_prov_out as pay_ntwk_prov_out,
		b.deduct_ntwk_prov_out  as deduct_ntwk_prov_out,
		b.copay_ntwk_prov_out  as copay_ntwk_prov_out,
		b.coins_ntwk_prov_out  as coins_ntwk_prov_out,
		b.cob_ntwk_prov_out  as cob_ntwk_prov_out,
		b.netpay_ntwk_prov_out  as netpay_ntwk_prov_out,	  			 

		b.pay_ntwk_fac_out  as pay_ntwk_fac_out,
		b.deduct_ntwk_fac_out  as deduct_ntwk_fac_out,
		b.copay_ntwk_fac_out  as copay_ntwk_fac_out,
		b.coins_ntwk_fac_out  as coins_ntwk_fac_out,
		b.cob_ntwk_fac_out  as cob_ntwk_fac_out,
		b.netpay_ntwk_fac_out  as netpay_ntwk_fac_out,	  			 

		b.pay_nonntwk_prov_out  as pay_nonntwk_prov_out,
		b.deduct_nonntwk_prov_out  as deduct_nonntwk_prov_out,
		b.copay_nonntwk_prov_out  as copay_nonntwk_prov_out,
		b.coins_nonntwk_prov_out  as coins_nonntwk_prov_out,
		b.cob_nonntwk_prov_out  as cob_nonntwk_prov_out,
		b.netpay_nonntwk_prov_out  as netpay_nonntwk_prov_out,	  			 

		b.pay_nonntwk_fac_out  as pay_nonntwk_fac_out,
		b.deduct_nonntwk_fac_out  as deduct_nonntwk_fac_out,
		b.copay_nonntwk_fac_out  as copay_nonntwk_fac_out,
		b.coins_nonntwk_fac_out  as coins_nonntwk_fac_out,
		b.cob_nonntwk_fac_out  as cob_nonntwk_fac_out,
		b.netpay_nonntwk_fac_out  as netpay_nonntwk_fac_out,

		b.pay_out  as pay_out,
		b.deduct_out  as deduct_out,
		b.copay_out  as copay_out,
		b.coins_out  as coins_out,
		b.cob_out  as cob_out,
		b.netpay_out  as netpay_out

	from &outlib..inpt_dt as a FULL JOIN &outlib..outpt_dt as b
		on (a.efamid = b.efamid AND
			a.enrolid = b.enrolid AND
			a.client = b.client);

	create table &outlib..final_util_data as /*add pharmacy data, set missing values to 0, round to even dollars*/
	select  
		coalesce(a.enrolid, b.enrolid) as enrolid,
		coalesce(a.efamid,b.efamid) as efamid,  
		coalesce(a.client,b.client) as client,
	  
		 round(ifn (a.pay_ntwk_prov_in is missing, 0, 		a.pay_ntwk_prov_in), 1) as pay_ntwk_prov_in,
		 round(ifn (a.deduct_ntwk_prov_in is missing, 0, 	a.deduct_ntwk_prov_in), 1) as deduct_ntwk_prov_in,
		 round(ifn (a.copay_ntwk_prov_in is missing, 0, 	a.copay_ntwk_prov_in), 1) as copay_ntwk_prov_in,		  	
		 round(ifn (a.coins_ntwk_prov_in is missing, 0, 	a.coins_ntwk_prov_in), 1) as coins_ntwk_prov_in,
		 round(ifn (a.cob_ntwk_prov_in is missing, 0, 		a.deduct_ntwk_prov_in), 1) as cob_ntwk_prov_in,
		 round(ifn (a.netpay_ntwk_prov_in is missing, 0, 	a.netpay_ntwk_prov_in), 1) as netpay_ntwk_prov_in,

		 round(ifn (a.pay_ntwk_fac_in is missing, 0, 		a.pay_ntwk_fac_in), 1) as pay_ntwk_fac_in,
		 round(ifn (a.deduct_ntwk_fac_in is missing, 0, 	a.deduct_ntwk_fac_in), 1) as deduct_ntwk_fac_in,
		 round(ifn (a.copay_ntwk_fac_in is missing, 0, 		a.copay_ntwk_fac_in), 1) as copay_ntwk_fac_in,		  	
		 round(ifn (a.coins_ntwk_fac_in is missing, 0, 		a.coins_ntwk_fac_in), 1) as coins_ntwk_fac_in,
		 round(ifn (a.cob_ntwk_fac_in is missing, 0, 		a.deduct_ntwk_fac_in), 1) as cob_ntwk_fac_in,
		 round(ifn (a.netpay_ntwk_fac_in is missing, 0, 	a.netpay_ntwk_fac_in), 1) as netpay_ntwk_fac_in,

		 round(ifn (a.pay_nonntwk_prov_in is missing, 0, 	a.pay_nonntwk_prov_in), 1) as pay_nonntwk_prov_in,
		 round(ifn (a.deduct_nonntwk_prov_in is missing, 0,	a.deduct_nonntwk_prov_in), 1) as deduct_nonntwk_prov_in,
		 round(ifn (a.copay_nonntwk_prov_in is missing, 0, 	a.copay_nonntwk_prov_in), 1) as copay_nonntwk_prov_in,		  	
		 round(ifn (a.coins_nonntwk_prov_in is missing, 0, 	a.coins_nonntwk_prov_in), 1) as coins_nonntwk_prov_in,
		 round(ifn (a.cob_nonntwk_prov_in is missing, 0, 	a.deduct_nonntwk_prov_in), 1) as cob_nonntwk_prov_in,
		 round(ifn (a.netpay_nonntwk_prov_in is missing, 0, a.netpay_nonntwk_prov_in), 1) as netpay_nonntwk_prov_in,

		 round(ifn (a.pay_nonntwk_fac_in is missing, 0, 	a.pay_nonntwk_fac_in), 1) as pay_nonntwk_fac_in,
		 round(ifn (a.deduct_nonntwk_fac_in is missing, 0, 	a.deduct_nonntwk_fac_in), 1) as deduct_nonntwk_fac_in,
		 round(ifn (a.copay_nonntwk_fac_in is missing, 0, 	a.copay_nonntwk_fac_in), 1) as copay_nonntwk_fac_in,		  	
		 round(ifn (a.coins_nonntwk_fac_in is missing, 0, 	a.coins_nonntwk_fac_in), 1) as coins_nonntwk_fac_in,
		 round(ifn (a.cob_nonntwk_fac_in is missing, 0, 	a.deduct_nonntwk_fac_in), 1) as cob_nonntwk_fac_in,
		 round(ifn (a.netpay_nonntwk_fac_in is missing, 0, 	a.netpay_nonntwk_fac_in), 1) as netpay_nonntwk_fac_in,

		 round(ifn (a.pay_in is missing, 0, 	a.pay_in), 1) as pay_in,
		 round(ifn (a.deduct_in is missing, 0, 	a.deduct_in), 1) as deduct_in,
		 round(ifn (a.copay_in is missing, 0, 	a.copay_in), 1) as copay_in,		  	
		 round(ifn (a.coins_in is missing, 0, 	a.coins_in), 1) as coins_in,
		 round(ifn (a.cob_in is missing, 0, 	a.deduct_in), 1) as cob_in,
		 round(ifn (a.netpay_in is missing, 0, 	a.netpay_in), 1) as netpay_in,

		 round(ifn (a.pay_ntwk_prov_out is missing, 0, 		a.pay_ntwk_prov_out), 1) as pay_ntwk_prov_out,
		 round(ifn (a.deduct_ntwk_prov_out is missing, 0, 	a.deduct_ntwk_prov_out), 1) as deduct_ntwk_prov_out,
		 round(ifn (a.copay_ntwk_prov_out is missing, 0, 	a.copay_ntwk_prov_out), 1) as copay_ntwk_prov_out,		  	
		 round(ifn (a.coins_ntwk_prov_out is missing, 0, 	a.coins_ntwk_prov_out), 1) as coins_ntwk_prov_out,
		 round(ifn (a.cob_ntwk_prov_out is missing, 0, 		a.deduct_ntwk_prov_out), 1) as cob_ntwk_prov_out,
		 round(ifn (a.netpay_ntwk_prov_out is missing, 0, 	a.netpay_ntwk_prov_out), 1) as netpay_ntwk_prov_out,

		 round(ifn (a.pay_ntwk_fac_out is missing, 0, 		a.pay_ntwk_fac_out), 1) as pay_ntwk_fac_out,
		 round(ifn (a.deduct_ntwk_fac_out is missing, 0, 	a.deduct_ntwk_fac_out), 1) as deduct_ntwk_fac_out,
		 round(ifn (a.copay_ntwk_fac_out is missing, 0, 	a.copay_ntwk_fac_out), 1) as copay_ntwk_fac_out,		  	
		 round(ifn (a.coins_ntwk_fac_out is missing, 0, 	a.coins_ntwk_fac_out), 1) as coins_ntwk_fac_out,
		 round(ifn (a.cob_ntwk_fac_out is missing, 0, 		a.deduct_ntwk_fac_out), 1) as cob_ntwk_fac_out,
		 round(ifn (a.netpay_ntwk_fac_out is missing, 0, 	a.netpay_ntwk_fac_out), 1) as netpay_ntwk_fac_out,

		 round(ifn (a.pay_nonntwk_prov_out is missing, 0, 	a.pay_nonntwk_prov_out), 1) as pay_nonntwk_prov_out,
		 round(ifn (a.deduct_nonntwk_prov_out is missing, 0,a.deduct_nonntwk_prov_out), 1) as deduct_nonntwk_prov_out,
		 round(ifn (a.copay_nonntwk_prov_out is missing, 0, a.copay_nonntwk_prov_out), 1) as copay_nonntwk_prov_out,		  	
		 round(ifn (a.coins_nonntwk_prov_out is missing, 0, a.coins_nonntwk_prov_out), 1) as coins_nonntwk_prov_out,
		 round(ifn (a.cob_nonntwk_prov_out is missing, 0, 	a.deduct_nonntwk_prov_out), 1) as cob_nonntwk_prov_out,
		 round(ifn (a.netpay_nonntwk_prov_out is missing, 0,a.netpay_nonntwk_prov_out), 1) as netpay_nonntwk_prov_out,

		 round(ifn (a.pay_nonntwk_fac_out is missing, 0, 	a.pay_nonntwk_fac_out), 1) as pay_nonntwk_fac_out,
		 round(ifn (a.deduct_nonntwk_fac_out is missing, 0, a.deduct_nonntwk_fac_out), 1) as deduct_nonntwk_fac_out,
		 round(ifn (a.copay_nonntwk_fac_out is missing, 0, 	a.copay_nonntwk_fac_out), 1) as copay_nonntwk_fac_out,		  	
		 round(ifn (a.coins_nonntwk_fac_out is missing, 0, 	a.coins_nonntwk_fac_out), 1) as coins_nonntwk_fac_out,
		 round(ifn (a.cob_nonntwk_fac_out is missing, 0, 	a.deduct_nonntwk_fac_out), 1) as cob_nonntwk_fac_out,
		 round(ifn (a.netpay_nonntwk_fac_out is missing, 0, a.netpay_nonntwk_fac_out), 1) as netpay_nonntwk_fac_out,

		 round(ifn (a.pay_out is missing, 0, 	a.pay_out), 1) as pay_out,
		 round(ifn (a.deduct_out is missing, 0, a.deduct_out), 1) as deduct_out,
		 round(ifn (a.copay_out is missing, 0, 	a.copay_out), 1) as copay_out,		  	
		 round(ifn (a.coins_out is missing, 0, 	a.coins_out), 1) as coins_out,
		 round(ifn (a.cob_out is missing, 0, 	a.deduct_out), 1) as cob_out,
		 round(ifn (a.netpay_out is missing, 0, a.netpay_out), 1) as netpay_out,

		 round(ifn (b.pay_ntwk_rx is missing,    0, b.pay_ntwk_rx), 1) as pay_ntwk_rx,
		 round(ifn (b.deduct_ntwk_rx is missing, 0, b.deduct_ntwk_rx 	), 1) as deduct_ntwk_rx,
		 round(ifn (b.copay_ntwk_rx is missing,  0, b.copay_ntwk_rx	), 1) as copay_ntwk_rx,
		 round(ifn (b.coins_ntwk_rx is missing,  0, b.coins_ntwk_rx 	), 1) as coins_ntwk_rx,
		 round(ifn (b.cob_ntwk_rx is missing,    0, b.cob_ntwk_rx 	), 1) as cob_ntwk_rx,
		 round(ifn (b.netpay_ntwk_rx is missing, 0, b.netpay_ntwk_rx 	), 1) as netpay_ntwk_rx,  	

		 round(ifn (b.pay_nonntwk_rx is missing,    0, b.pay_nonntwk_rx), 1) as pay_nonntwk_rx,
		 round(ifn (b.deduct_nonntwk_rx is missing, 0, b.deduct_nonntwk_rx 	), 1) as deduct_nonntwk_rx,
		 round(ifn (b.copay_nonntwk_rx is missing,  0, b.copay_nonntwk_rx	), 1) as copay_nonntwk_rx,
		 round(ifn (b.coins_nonntwk_rx is missing,  0, b.coins_nonntwk_rx 	), 1) as coins_nonntwk_rx,
		 round(ifn (b.cob_nonntwk_rx is missing,    0, b.cob_nonntwk_rx 	), 1) as cob_nonntwk_rx,
		 round(ifn (b.netpay_nonntwk_rx is missing, 0, b.netpay_nonntwk_rx 	), 1) as netpay_nonntwk_rx,  			  	

		 round(ifn (b.pay_rx is missing,    0, b.pay_rx), 1) as pay_rx,
		 round(ifn (b.deduct_rx is missing, 0, b.deduct_rx 	), 1) as deduct_rx,
		 round(ifn (b.copay_rx is missing,  0, b.copay_rx	), 1) as copay_rx,
		 round(ifn (b.coins_rx is missing,  0, b.coins_rx 	), 1) as coins_rx,
		 round(ifn (b.cob_rx is missing,    0, b.cob_rx 	), 1) as cob_rx,
		 round(ifn (b.netpay_rx is missing, 0, b.netpay_rx 	), 1) as netpay_rx  				  				 		  

	from &outlib..merge1 as a FULL JOIN outsas.rx_dt as b
 		on (a.efamid = b.efamid AND
			a.enrolid = b.enrolid AND
			a.client = b.client);
quit;

/*STEP 4: Enrollee and Family Year Files*/
/*   This merges family sizes and plan information onto Final_util_data file for individual and family level analysis*/
/*   NOTE: The enroll_cy_in file includes enrollees with no utilization*/
proc sql;
	/*merge family sizes and plan information onto Final_util_data file for individual and family level analysis*/
	/*   NOTE: The enroll_cy_in file includes enrollees with no utilization*/
	create table &outlib..enrollee_year as
		select			
			b.plan,
			b.rx,
			b.hlthplan,
			b.fam_size,
			a.*
		from &outlib..final_util_data as a
			LEFT JOIN
				(select min(efamid) as efamid,
					min(client) as client,
					min(plan1) as plan,		
					min(rx) as rx,
					min(hlthplan) as hlthplan,			 
					count(enrolid) as fam_size
				from &outlib..&enroll_cy_in.
					group by efamid) as b
						on (a.efamid = b.efamid)
	;

	create table &outlib..enrollee_year as
		select 						 
			min(efamid) as efamid,
			min(enrolid) as enrolid,
			min(rx) as rx,
			min(hlthplan) as hlthplan,	
			min(client) as client,
			min(plan) as plan,	
			min(fam_size) as fam_size, 

			sum(a.deduct_ntwk_prov_in + a.deduct_ntwk_fac_in + a.deduct_ntwk_prov_out + a.deduct_ntwk_fac_out) as deduct_ntwk_norx,					
			sum(a.deduct_nonntwk_prov_in + a.deduct_nonntwk_fac_in + a.deduct_nonntwk_prov_out + a.deduct_nonntwk_fac_out) as deduct_nonntwk_norx,
			sum(a.deduct_ntwk_rx) as deduct_ntwk_rx,
			sum(a.deduct_nonntwk_rx) as deduct_nonntwk_rx,
			(CALCULATED deduct_ntwk_rx + CALCULATED deduct_nonntwk_rx) as deduct_total_rx,			
			(CALCULATED deduct_ntwk_norx + CALCULATED deduct_nonntwk_norx) as deduct_total_norx,
			(CALCULATED deduct_ntwk_norx + CALCULATED deduct_ntwk_rx) as deduct_total_ntwk,
			(CALCULATED deduct_nonntwk_norx + CALCULATED deduct_nonntwk_rx) as deduct_total_nonntwk,					
			(CALCULATED deduct_ntwk_rx + CALCULATED deduct_nonntwk_rx + CALCULATED deduct_ntwk_norx + CALCULATED deduct_nonntwk_norx) as deduct_total,

			sum(a.copay_ntwk_prov_in + a.copay_ntwk_fac_in + a.copay_ntwk_prov_out + a.copay_ntwk_fac_out) as copay_ntwk_norx,					
			sum(a.copay_nonntwk_prov_in + a.copay_nonntwk_fac_in + a.copay_nonntwk_prov_out + a.copay_nonntwk_fac_out) as copay_nonntwk_norx,
			sum(a.copay_ntwk_rx) as copay_ntwk_rx,
			sum(a.copay_nonntwk_rx) as copay_nonntwk_rx,
			(CALCULATED copay_ntwk_rx + CALCULATED copay_nonntwk_rx) as copay_total_rx,			
			(CALCULATED copay_ntwk_norx + CALCULATED copay_nonntwk_norx) as copay_total_norx,
			(CALCULATED copay_ntwk_norx + CALCULATED copay_ntwk_rx) as copay_total_ntwk,
			(CALCULATED copay_nonntwk_norx + CALCULATED copay_nonntwk_rx) as copay_total_nonntwk,					
			(CALCULATED copay_ntwk_rx + CALCULATED copay_nonntwk_rx + CALCULATED copay_ntwk_norx + CALCULATED copay_nonntwk_norx) as copay_total,

			sum(a.coins_ntwk_prov_in + a.coins_ntwk_fac_in + a.coins_ntwk_prov_out + a.coins_ntwk_fac_out) as coins_ntwk_norx,					
			sum(a.coins_nonntwk_prov_in + a.coins_nonntwk_fac_in + a.coins_nonntwk_prov_out + a.coins_nonntwk_fac_out) as coins_nonntwk_norx,
			sum(a.coins_ntwk_rx) as coins_ntwk_rx,
			sum(a.coins_nonntwk_rx) as coins_nonntwk_rx,
			(CALCULATED coins_ntwk_rx + CALCULATED coins_nonntwk_rx) as coins_total_rx,			
			(CALCULATED coins_ntwk_norx + CALCULATED coins_nonntwk_norx) as coins_total_norx,
			(CALCULATED coins_ntwk_norx + CALCULATED coins_ntwk_rx) as coins_total_ntwk,
			(CALCULATED coins_nonntwk_norx + CALCULATED coins_nonntwk_rx) as coins_total_nonntwk,					
			(CALCULATED coins_ntwk_rx + CALCULATED coins_nonntwk_rx + CALCULATED coins_ntwk_norx + CALCULATED coins_nonntwk_norx) as coins_total,			

			(CALCULATED deduct_ntwk_rx + CALCULATED copay_ntwk_rx + CALCULATED coins_ntwk_rx) as oop_ntwk_rx,	
			(CALCULATED deduct_nonntwk_rx + CALCULATED copay_nonntwk_rx + CALCULATED coins_nonntwk_rx) as oop_nonntwk_rx,		
			(CALCULATED oop_ntwk_rx + CALCULATED oop_nonntwk_rx) as oop_total_rx,  

			(CALCULATED deduct_ntwk_norx + CALCULATED copay_ntwk_norx + CALCULATED coins_ntwk_norx) as oop_ntwk_norx,
			(CALCULATED deduct_nonntwk_norx + CALCULATED copay_nonntwk_norx + CALCULATED coins_nonntwk_norx) as oop_nonntwk_norx,					
			(CALCULATED oop_ntwk_norx + CALCULATED oop_nonntwk_norx) as oop_total_norx,	

			(CALCULATED oop_ntwk_norx + CALCULATED oop_ntwk_rx) as oop_total_ntwk,		
			(CALCULATED oop_nonntwk_norx + CALCULATED oop_nonntwk_rx) as oop_total_nonntwk,																                
			(CALCULATED oop_total_ntwk + CALCULATED oop_total_nonntwk) as oop_total

		from &outlib..enrollee_year as a
			group by enrolid;


	create table &outlib..family_year as  /*NOTE: includes only families with size>1*/
		select min(efamid) as efamid,
			min(rx) as rx,
			min(hlthplan) as hlthplan,	
			min(client) as client,
			min(plan) as plan,	
			min(fam_size) as fam_size,

			sum(deduct_ntwk_norx) as fam_deduct_ntwk_norx,					
			sum(deduct_nonntwk_norx) as fam_deduct_nonntwk_norx,
			sum(deduct_ntwk_rx) as fam_deduct_ntwk_rx,
			sum(deduct_nonntwk_rx) as fam_deduct_nonntwk_rx,
			sum(deduct_total_rx) as fam_deduct_total_rx,					
			sum(deduct_total_norx) as fam_deduct_total_norx,
			sum(deduct_total_ntwk) as fam_deduct_total_ntwk,
			sum(deduct_total_nonntwk) as fam_deduct_total_nonntwk,
			sum(deduct_total) as fam_deduct_total,

			sum(copay_ntwk_norx) as fam_copay_ntwk_norx,					
			sum(copay_nonntwk_norx) as fam_copay_nonntwk_norx,
			sum(copay_ntwk_rx) as fam_copay_ntwk_rx,
			sum(copay_nonntwk_rx) as fam_copay_nonntwk_rx,
			sum(copay_total_rx) as fam_copay_total_rx,					
			sum(copay_total_norx) as fam_copay_total_norx,
			sum(copay_total_ntwk) as fam_copay_total_ntwk,
			sum(copay_total_nonntwk) as fam_copay_total_nonntwk,
			sum(copay_total) as fam_copay_total,

			sum(coins_ntwk_norx) as fam_coins_ntwk_norx,					
			sum(coins_nonntwk_norx) as fam_coins_nonntwk_norx,
			sum(coins_ntwk_rx) as fam_coins_ntwk_rx,
			sum(coins_nonntwk_rx) as fam_coins_nonntwk_rx,
			sum(coins_total_rx) as fam_coins_total_rx,					
			sum(coins_total_norx) as fam_coins_total_norx,
			sum(coins_total_ntwk) as fam_coins_total_ntwk,
			sum(coins_total_nonntwk) as fam_coins_total_nonntwk,
			sum(coins_total) as fam_coins_total,

			sum(oop_ntwk_rx) as fam_oop_ntwk_rx,				  
			sum(oop_nonntwk_rx) as fam_oop_nonntwk_rx,				
			sum(oop_total_rx) as fam_oop_total_rx,		

			sum(oop_ntwk_norx) as fam_oop_ntwk_norx,					
			sum(oop_nonntwk_norx) as fam_oop_nonntwk_norx,
			sum(oop_total_norx) as fam_oop_total_norx,

			sum(oop_total_ntwk) as fam_oop_total_ntwk,
			sum(oop_total_nonntwk) as fam_oop_total_nonntwk,
			sum(oop_total) as fam_oop_total

		from &outlib..enrollee_year 
			group by efamid
			having fam_size>1
		;
quit;

/*STEP 5 (OPTIONAL): create person and family level quantile outputs if requested*/
%if &quant.=Y %then %do;
		ods output Quantiles=&outlib..ind_quants;
		proc univariate data=&outlib..enrollee_year(where=(fam_size=1));
			VAR deduct_ntwk_norx 
				deduct_nonntwk_norx  
				deduct_ntwk_rx
				deduct_nonntwk_rx
				deduct_total_rx
				deduct_total_norx
				deduct_total_ntwk
				deduct_total_nonntwk
				deduct_total

				oop_ntwk_rx
				oop_nonntwk_rx
				oop_total_rx
				oop_ntwk_norx
				oop_nonntwk_norx
				oop_total_norx
				oop_total_ntwk
				oop_total_nonntwk
				oop_total
			;
		run; 

		ods output Quantiles=&outlib..fam_quants;
		proc univariate data=&outlib..family_year;
			VAR fam_deduct_ntwk_norx
				fam_deduct_nonntwk_norx
				fam_deduct_ntwk_rx
				fam_deduct_nonntwk_rx
				fam_deduct_total_rx
				fam_deduct_total_norx
				fam_deduct_total_ntwk
				fam_deduct_total_nonntwk
				fam_deduct_total


				fam_oop_ntwk_rx
				fam_oop_nonntwk_rx
				fam_oop_total_rx
				fam_oop_ntwk_norx
				fam_oop_nonntwk_norx
				fam_oop_total_norx
				fam_oop_total_ntwk
				fam_oop_total_nonntwk
				fam_oop_total
			;
		run;

		data &outlib..plan_quant_summary;
			set &outlib..ind_quants
				&outlib..fam_quants;
			client = &cur_client.;
			plan = &cur_plan.;
		run;

		proc datasets library=&outlib. noprint;
			delete ind_quants
				   fam_quants;
		run;
%end;

/*STEP 6: create the final output file for the plan*/
	/*Calculate person and family level summary statistics and merge back to the files */
proc means data=&outlib..enrollee_year(where=(fam_size=1)) max noprint;
	VAR deduct_ntwk_norx 
		deduct_nonntwk_norx  
		deduct_ntwk_rx
		deduct_nonntwk_rx
		deduct_total_rx
		deduct_total_norx
		deduct_total_ntwk
		deduct_total_nonntwk
		deduct_total

		copay_ntwk_norx
		copay_nonntwk_norx
		copay_ntwk_rx
		copay_nonntwk_rx
		copay_total_rx
		copay_total_norx
		copay_total_ntwk
		copay_total_nonntwk
		copay_total

		coins_ntwk_norx
		coins_nonntwk_norx
		coins_ntwk_rx
		coins_nonntwk_rx
		coins_total_rx
		coins_total_norx
		coins_total_ntwk
		coins_total_nonntwk
		coins_total

		oop_ntwk_rx
		oop_nonntwk_rx
		oop_total_rx
		oop_ntwk_norx
		oop_nonntwk_norx
		oop_total_norx
		oop_total_ntwk
		oop_total_nonntwk
		oop_total
	;
	output 	out=&outlib..enroll_deduct_oop(label="summary statistics for outsas.enrollee_deduct_oop_year")
		max()=
		/autoname
	;
run;

proc means data=&outlib..family_year max noprint;
	var fam_deduct_ntwk_norx
		fam_deduct_nonntwk_norx
		fam_deduct_ntwk_rx
		fam_deduct_nonntwk_rx
		fam_deduct_total_rx
		fam_deduct_total_norx
		fam_deduct_total_ntwk
		fam_deduct_total_nonntwk
		fam_deduct_total

		fam_copay_ntwk_norx
		fam_copay_nonntwk_norx
		fam_copay_ntwk_rx
		fam_copay_nonntwk_rx
		fam_copay_total_rx
		fam_copay_total_norx
		fam_copay_total_ntwk
		fam_copay_total_nonntwk
		fam_copay_total

		fam_coins_ntwk_norx
		fam_coins_nonntwk_norx
		fam_coins_ntwk_rx
		fam_coins_nonntwk_rx
		fam_coins_total_rx
		fam_coins_total_norx
		fam_coins_total_ntwk
		fam_coins_total_nonntwk
		fam_coins_total

		fam_oop_ntwk_rx
		fam_oop_nonntwk_rx
		fam_oop_total_rx
		fam_oop_ntwk_norx
		fam_oop_nonntwk_norx
		fam_oop_total_norx
		fam_oop_total_ntwk
		fam_oop_total_nonntwk
		fam_oop_total
	;
	output 	out=&outlib..family_deduct_oop(label="summary statistics for outsas.family_deduct_oop_year")
		max = 
		/autoname;
run;

proc sql;
	create table &outlib..enr_ben1 as
		/*1) append the observed maximums onto the enrollee_year file, AND
		2) identify those enrollees hitting the observed plan maximums
		*/
	select a.*,
		b.*,
		/*flags*/
		ifn(a.deduct_ntwk_norx=b.deduct_ntwk_norx_Max,1,0) as deduct_ntwk_norx_flg,
		ifn(a.deduct_nonntwk_norx=b.deduct_nonntwk_norx_Max,1,0) as deduct_nonntwk_norx_flg,
		ifn(a.deduct_ntwk_rx=b.deduct_ntwk_rx_Max,1,0) as deduct_ntwk_rx_flg,
		ifn(a.deduct_nonntwk_rx=b.deduct_nonntwk_rx_Max,1,0) as deduct_nonntwk_rx_flg,	
		ifn(a.deduct_total_rx=b.deduct_total_rx_MAX,1,0) as deduct_total_rx_flg,
		ifn(a.deduct_total_norx=b.deduct_total_norx_MAX,1,0) as deduct_total_norx_flg,
		ifn(a.deduct_total_ntwk=b.deduct_total_ntwk_MAX,1,0) as deduct_total_ntwk_flg,
		ifn(a.deduct_total_nonntwk=b.deduct_total_nonntwk_MAX,1,0) as deduct_total_nonntwk_flg,		
		ifn(a.deduct_total=b.deduct_total_MAX,1,0) as deduct_total_flg,	   

		ifn(a.copay_ntwk_norx=b.copay_ntwk_norx_Max,1,0) as copay_ntwk_norx_flg,
		ifn(a.copay_nonntwk_norx=b.copay_nonntwk_norx_Max,1,0) as copay_nonntwk_norx_flg,
		ifn(a.copay_ntwk_rx=b.copay_ntwk_rx_Max,1,0) as copay_ntwk_rx_flg,
		ifn(a.copay_nonntwk_rx=b.copay_nonntwk_rx_Max,1,0) as copay_nonntwk_rx_flg,	
		ifn(a.copay_total_rx=b.copay_total_rx_MAX,1,0) as copay_total_rx_flg,
		ifn(a.copay_total_norx=b.copay_total_norx_MAX,1,0) as copay_total_norx_flg,
		ifn(a.copay_total_ntwk=b.copay_total_ntwk_MAX,1,0) as copay_total_ntwk_flg,
		ifn(a.copay_total_nonntwk=b.copay_total_nonntwk_MAX,1,0) as copay_total_nonntwk_flg,		
		ifn(a.copay_total=b.copay_total_MAX,1,0) as copay_total_flg,	 

		ifn(a.coins_ntwk_norx=b.coins_ntwk_norx_Max,1,0) as coins_ntwk_norx_flg,
		ifn(a.coins_nonntwk_norx=b.coins_nonntwk_norx_Max,1,0) as coins_nonntwk_norx_flg,
		ifn(a.coins_ntwk_rx=b.coins_ntwk_rx_Max,1,0) as coins_ntwk_rx_flg,
		ifn(a.coins_nonntwk_rx=b.coins_nonntwk_rx_Max,1,0) as coins_nonntwk_rx_flg,	
		ifn(a.coins_total_rx=b.coins_total_rx_MAX,1,0) as coins_total_rx_flg,
		ifn(a.coins_total_norx=b.coins_total_norx_MAX,1,0) as coins_total_norx_flg,
		ifn(a.coins_total_ntwk=b.coins_total_ntwk_MAX,1,0) as coins_total_ntwk_flg,
		ifn(a.coins_total_nonntwk=b.coins_total_nonntwk_MAX,1,0) as coins_total_nonntwk_flg,		
		ifn(a.coins_total=b.coins_total_MAX,1,0) as coins_total_flg,	   

		ifn(a.oop_ntwk_norx=b.oop_ntwk_norx_Max,1,0) as oop_ntwk_norx_flg,
		ifn(a.oop_nonntwk_norx=b.oop_nonntwk_norx_Max,1,0) as oop_nonntwk_norx_flg,
		ifn(a.oop_ntwk_rx=b.oop_ntwk_rx_Max,1,0) as oop_ntwk_rx_flg,
		ifn(a.oop_nonntwk_rx=b.oop_nonntwk_rx_Max,1,0) as oop_nonntwk_rx_flg,	
		ifn(a.oop_total_rx=b.oop_total_rx_MAX,1,0) as oop_total_rx_flg,
		ifn(a.oop_total_norx=b.oop_total_norx_MAX,1,0) as oop_total_norx_flg,
		ifn(a.oop_total_ntwk=b.oop_total_ntwk_MAX,1,0) as oop_total_ntwk_flg,
		ifn(a.oop_total_nonntwk=b.oop_total_nonntwk_MAX,1,0) as oop_total_nonntwk_flg,		
		ifn(a.oop_total=b.oop_total_MAX,1,0) as oop_total_flg	  

		from &outlib..enrollee_year as a, &outlib..enroll_deduct_oop as b
		;

	create table &outlib..enr_ben2 as
			/*Create a one line dataset that identifies
			1) The observed maximums onto the enrollee_year file, AND
			2) The number hitting those maximums
			3) Assign shorter BPD final names using ABCDE convention
			*/
		select 
			min(hlthplan) as hlthplan,
			count(enrolid) as N_ind_active,
			sum(ifn(fam_size=1,1,0)) as N_deduct,  /*sample available for deductable identification*/
			min(rx) as rx,

			max(deduct_ntwk_norx_Max) 		as  IDNSV,
			sum(deduct_ntwk_norx_flg) 		as  IDNSN,

			max(deduct_nonntwk_norx) 		as  IDOSV,
			sum(deduct_nonntwk_norx_flg)    as  IDOSN,

			max(deduct_ntwk_rx) 		 		as  IDNRV,
			sum(deduct_ntwk_rx_flg) 			as  IDNRN,

			max(deduct_nonntwk_rx) 		 	as  IDORV,
			sum(deduct_nonntwk_rx_flg)  	as  IDORN,

			max(deduct_total_rx) 		 		as  IDBRV,
			sum(deduct_total_rx_flg)  		as  IDBRN,

			max(deduct_total_norx) 		 	as  IDBSV,
			sum(deduct_total_norx_flg)  	as  IDBSN,

			max(deduct_total_ntwk) 		 	as  IDNBV,
			sum(deduct_total_ntwk_flg)  	as  IDNBN,

			max(deduct_total_nonntwk) 		as  IDOBV,
			sum(deduct_total_nonntwk_flg)as  IDOBN,			   

			max(deduct_total) 		  			as  IDBBV,
			sum(deduct_total_flg)  			as  IDBBN,		

			max(coins_ntwk_norx_Max) 		as  ICNSV,
			sum(coins_ntwk_norx_flg) 		as  ICNSN,

			max(coins_nonntwk_norx)  		as  ICOSV,
			sum(coins_nonntwk_norx_flg)  as  ICOSN,

			max(coins_ntwk_rx) 		 			as  ICNRV,
			sum(coins_ntwk_rx_flg)  			as  ICNRN,

			max(coins_nonntwk_rx) 		  	as  ICORV,
			sum(coins_nonntwk_rx_flg)  	as  ICORN,

			max(coins_total_rx) 		  		as  ICBRV,
			sum(coins_total_rx_flg)  		as  ICBRN,

			max(coins_total_norx) 		  	as  ICBSV,
			sum(coins_total_norx_flg)  	as  ICBSN,

			max(coins_total_ntwk) 		  	as  ICNBV,
			sum(coins_total_ntwk_flg)  	as  ICNBN,

			max(coins_total_nonntwk) 		as  ICOBV,
			sum(coins_total_nonntwk_flg) as  ICOBN,			   

			max(coins_total) 		  			as  ICBBV,
			sum(coins_total_flg)   			as  ICBBN,		

			max(oop_ntwk_norx_Max) 			as  IONSV,
			sum(oop_ntwk_norx_flg) 			as  IONSN,

			max(oop_nonntwk_norx)  	 		as  IOOSV,
			sum(oop_nonntwk_norx_flg) 		as  IOOSN,

			max(oop_ntwk_rx) 		 				as  IONRV,
			sum(oop_ntwk_rx_flg)  				as  IONRN,

			max(oop_nonntwk_rx) 		  		as  IOORV,
			sum(oop_nonntwk_rx_flg)  		as  IOORN,

			max(oop_total_rx) 		  			as  IOBRV,
			sum(oop_total_rx_flg)  			as  IOBRN,

			max(oop_total_norx) 		  		as  IOBSV,
			sum(oop_total_norx_flg)  		as  IOBSN,

			max(oop_total_ntwk) 		  		as  IONBV,
			sum(oop_total_ntwk_flg)  		as  IONBN,

			max(oop_total_nonntwk) 		  as  IOOBV,
			sum(oop_total_nonntwk_flg)   as  IOOBN,			   

			max(oop_total) 		  				as  IOBBV,
			sum(oop_total_flg)   				as  IOBBN		

			from 
				&outlib..enr_ben1
			;

		create table &outlib..fam_ben1 as
				/*1) append the observed maximums onto the enrollee_year file, AND
				2) identify those families hitting the observed plan maximums
				*/
			select 
				a.*,
				b.*,
				/*flags*/
				ifn(a.fam_deduct_ntwk_norx=b.fam_deduct_ntwk_norx_Max,1,0) as fam_deduct_ntwk_norx_flg,
				ifn(a.fam_deduct_nonntwk_norx=b.fam_deduct_nonntwk_norx_Max,1,0) as fam_deduct_nonntwk_norx_flg,
				ifn(a.fam_deduct_ntwk_rx=b.fam_deduct_ntwk_rx_Max,1,0) as fam_deduct_ntwk_rx_flg,
				ifn(a.fam_deduct_nonntwk_rx=b.fam_deduct_nonntwk_rx_Max,1,0) as fam_deduct_nonntwk_rx_flg,	
				ifn(a.fam_deduct_total_rx=b.fam_deduct_total_rx_MAX,1,0) as fam_deduct_total_rx_flg,
				ifn(a.fam_deduct_total_norx=b.fam_deduct_total_norx_MAX,1,0) as fam_deduct_total_norx_flg,
				ifn(a.fam_deduct_total_ntwk=b.fam_deduct_total_ntwk_MAX,1,0) as fam_deduct_total_ntwk_flg,
				ifn(a.fam_deduct_total_nonntwk=b.fam_deduct_total_nonntwk_MAX,1,0) as fam_deduct_total_nonntwk_flg,		
				ifn(a.fam_deduct_total=b.fam_deduct_total_MAX,1,0) as fam_deduct_total_flg,	   

				ifn(a.fam_copay_ntwk_norx=b.fam_copay_ntwk_norx_Max,1,0) as fam_copay_ntwk_norx_flg,
				ifn(a.fam_copay_nonntwk_norx=b.fam_copay_nonntwk_norx_Max,1,0) as fam_copay_nonntwk_norx_flg,
				ifn(a.fam_copay_ntwk_rx=b.fam_copay_ntwk_rx_Max,1,0) as fam_copay_ntwk_rx_flg,
				ifn(a.fam_copay_nonntwk_rx=b.fam_copay_nonntwk_rx_Max,1,0) as fam_copay_nonntwk_rx_flg,	
				ifn(a.fam_copay_total_rx=b.fam_copay_total_rx_MAX,1,0) as fam_copay_total_rx_flg,
				ifn(a.fam_copay_total_norx=b.fam_copay_total_norx_MAX,1,0) as fam_copay_total_norx_flg,
				ifn(a.fam_copay_total_ntwk=b.fam_copay_total_ntwk_MAX,1,0) as fam_copay_total_ntwk_flg,
				ifn(a.fam_copay_total_nonntwk=b.fam_copay_total_nonntwk_MAX,1,0) as fam_copay_total_nonntwk_flg,		
				ifn(a.fam_copay_total=b.fam_copay_total_MAX,1,0) as fam_copay_total_flg,	 

				ifn(a.fam_coins_ntwk_norx=b.fam_coins_ntwk_norx_Max,1,0) as fam_coins_ntwk_norx_flg,
				ifn(a.fam_coins_nonntwk_norx=b.fam_coins_nonntwk_norx_Max,1,0) as fam_coins_nonntwk_norx_flg,
				ifn(a.fam_coins_ntwk_rx=b.fam_coins_ntwk_rx_Max,1,0) as fam_coins_ntwk_rx_flg,
				ifn(a.fam_coins_nonntwk_rx=b.fam_coins_nonntwk_rx_Max,1,0) as fam_coins_nonntwk_rx_flg,	
				ifn(a.fam_coins_total_rx=b.fam_coins_total_rx_MAX,1,0) as fam_coins_total_rx_flg,
				ifn(a.fam_coins_total_norx=b.fam_coins_total_norx_MAX,1,0) as fam_coins_total_norx_flg,
				ifn(a.fam_coins_total_ntwk=b.fam_coins_total_ntwk_MAX,1,0) as fam_coins_total_ntwk_flg,
				ifn(a.fam_coins_total_nonntwk=b.fam_coins_total_nonntwk_MAX,1,0) as fam_coins_total_nonntwk_flg,		
				ifn(a.fam_coins_total=b.fam_coins_total_MAX,1,0) as fam_coins_total_flg,	   

				ifn(a.fam_oop_ntwk_norx=b.fam_oop_ntwk_norx_Max,1,0) as fam_oop_ntwk_norx_flg,
				ifn(a.fam_oop_nonntwk_norx=b.fam_oop_nonntwk_norx_Max,1,0) as fam_oop_nonntwk_norx_flg,
				ifn(a.fam_oop_ntwk_rx=b.fam_oop_ntwk_rx_Max,1,0) as fam_oop_ntwk_rx_flg,
				ifn(a.fam_oop_nonntwk_rx=b.fam_oop_nonntwk_rx_Max,1,0) as fam_oop_nonntwk_rx_flg,	
				ifn(a.fam_oop_total_rx=b.fam_oop_total_rx_MAX,1,0) as fam_oop_total_rx_flg,
				ifn(a.fam_oop_total_norx=b.fam_oop_total_norx_MAX,1,0) as fam_oop_total_norx_flg,
				ifn(a.fam_oop_total_ntwk=b.fam_oop_total_ntwk_MAX,1,0) as fam_oop_total_ntwk_flg,
				ifn(a.fam_oop_total_nonntwk=b.fam_oop_total_nonntwk_MAX,1,0) as fam_oop_total_nonntwk_flg,		
				ifn(a.fam_oop_total=b.fam_oop_total_MAX,1,0) as fam_oop_total_flg	  

				from &outlib..family_year as a, &outlib..family_deduct_oop as b
				;
			create table &outlib..fam_ben2 as
					/*Create a one line dataset that identifies
					1) The observed maximums onto the enrollee_year file, AND
					2) The number hitting those maximums
					3) Assign final, short BPD coded names using ABCDE convention
					*/
				select 
					count(efamid) as N_fam_active,

					max(fam_deduct_ntwk_norx_Max) 		as  FDNSV,
					sum(fam_deduct_ntwk_norx_flg) 		as  FDNSN,

					max(fam_deduct_nonntwk_norx) 		as  FDOSV,
					sum(fam_deduct_nonntwk_norx_flg) as  FDOSN,

					max(fam_deduct_ntwk_rx) 		 			as  FDNRV,
					sum(fam_deduct_ntwk_rx_flg) 			as  FDNRN,

					max(fam_deduct_nonntwk_rx) 		 	as  FDORV,
					sum(fam_deduct_nonntwk_rx_flg)  	as  FDORN,

					max(fam_deduct_total_rx) 		 		as  FDBRV,
					sum(fam_deduct_total_rx_flg)  		as  FDBRN,

					max(fam_deduct_total_norx) 		 	as  FDBSV,
					sum(fam_deduct_total_norx_flg)  	as  FDBSN,

					max(fam_deduct_total_ntwk) 		 	as  FDNBV,
					sum(fam_deduct_total_ntwk_flg)  	as  FDNBN,

					max(fam_deduct_total_nonntwk) 		as  FDOBV,
					sum(fam_deduct_total_nonntwk_flg)as  FDOBN,			   

					max(fam_deduct_total) 		  			as  FDBBV,
					sum(fam_deduct_total_flg)  			as  FDBBN,		

					max(fam_coins_ntwk_norx_Max) 		as  FCNSV,
					sum(fam_coins_ntwk_norx_flg) 		as  FCNSN,

					max(fam_coins_nonntwk_norx)  		as  FCOSV,
					sum(fam_coins_nonntwk_norx_flg)  as  FCOSN,

					max(fam_coins_ntwk_rx) 		 			as  FCNRV,
					sum(fam_coins_ntwk_rx_flg)  			as  FCNRN,

					max(fam_coins_nonntwk_rx) 		  	as  FCORV,
					sum(fam_coins_nonntwk_rx_flg)  	as  FCORN,

					max(fam_coins_total_rx) 		  		as  FCBRV,
					sum(fam_coins_total_rx_flg)  		as  FCBRN,

					max(fam_coins_total_norx) 		  	as  FCBSV,
					sum(fam_coins_total_norx_flg)  	as  FCBSN,

					max(fam_coins_total_ntwk) 		  	as  FCNBV,
					sum(fam_coins_total_ntwk_flg)  	as  FCNBN,

					max(fam_coins_total_nonntwk) 		as  FCOBV,
					sum(fam_coins_total_nonntwk_flg) as  FCOBN,			   

					max(fam_coins_total) 		  			as  FCBBV,
					sum(fam_coins_total_flg)   			as  FCBBN,		

					max(fam_oop_ntwk_norx_Max) 			as  FONSV,
					sum(fam_oop_ntwk_norx_flg) 			as  FONSN,

					max(fam_oop_nonntwk_norx)  	 		as  FOOSV,
					sum(fam_oop_nonntwk_norx_flg) 		as  FOOSN,

					max(fam_oop_ntwk_rx) 		 				as  FONRV,
					sum(fam_oop_ntwk_rx_flg)  				as  FONRN,

					max(fam_oop_nonntwk_rx) 		  		as  FOORV,
					sum(fam_oop_nonntwk_rx_flg)  		as  FOORN,

					max(fam_oop_total_rx) 		  			as  FOBRV,
					sum(fam_oop_total_rx_flg)  			as  FOBRN,

					max(fam_oop_total_norx) 		  		as  FOBSV,
					sum(fam_oop_total_norx_flg)  		as  FOBSN,

					max(fam_oop_total_ntwk) 		  		as  FONBV,
					sum(fam_oop_total_ntwk_flg)  		as  FONBN,

					max(fam_oop_total_nonntwk) 		  as  FOOBV,
					sum(fam_oop_total_nonntwk_flg)   as  FOOBN,			   

					max(fam_oop_total) 		  				as  FOBBV,
					sum(fam_oop_total_flg)   				as  FOBBN		

				from 
					&outlib..fam_ben1
				;
quit;

/*Identify deductables, structure, and OOP max*/
data &outlib..plan_ben_summary(drop=i 
	keep=
	CLIENT PLAN PLANKEY HLTHPLAN
	st_year st_month end_year end_month 
	N_ind N_ind_active N_deduct 
	N_fam N_fam_active rx 
	BDBBC BOBBC
	IDNSV IDNSN IDNSC
	IDOSV IDOSN IDOSC
	IDNRV IDNRN IDNRC
	IDORV IDORN IDORC
	IDBRV IDBRN IDBRC
	IDBSV IDBSN IDBSC
	IDNBV IDNBN IDNBC
	IDOBV IDOBN IDOBC
	IDBBV IDBBN IDBBC

	FDNSV FDNSN FDNSC
	FDOSV FDOSN FDOSC
	FDNRV FDNRN FDNRC
	FDORV FDORN FDORC
	FDBRV FDBRN FDBRC
	FDBSV FDBSN FDBSC
	FDNBV FDNBN FDNBC
	FDOBV FDOBN FDOBC
	FDBBV FDBBN FDBBC

	IONSV IONSN IONSC
	IOOSV IOOSN IOOSC
	IONRV IONRN IONRC
	IOORV IOORN IOORC
	IOBRV IOBRN IOBRC
	IOBSV IOBSN IOBSC
	IONBV IONBN IONBC
	IOOBV IOOBN IOOBC
	IOBBV IOBBN IOBBC

	FONSV FONSN FONSC
	FOOSV FOOSN FOOSC
	FONRV FONRN FONRC
	FOORV FOORN FOORC
	FOBRV FOBRN FOBRC
	FOBSV FOBSN FOBSC
	FONBV FONBN FONBC
	FOOBV FOOBN FOOBC
	FOBBV FOBBN FOBBC
	);
	retain 	
		CLIENT PLAN PLANKEY HLTHPLAN
		st_year st_month end_year end_month 
		N_ind N_ind_active N_deduct 
		N_fam N_fam_active rx 
		BDBBC BOBBC
		IDNSV IDNSN IDNSC
		FDNSV FDNSN FDNSC
		IDOSV IDOSN IDOSC
		FDOSV FDOSN FDOSC
		IDNRV IDNRN IDNRC
		FDNRV FDNRN FDNRC
		IDORV IDORN IDORC
		FDORV FDORN FDORC
		IDBRV IDBRN IDBRC
		FDBRV FDBRN FDBRC
		IDBSV IDBSN IDBSC
		FDBSV FDBSN FDBSC
		IDNBV IDNBN IDNBC
		FDNBV FDNBN FDNBC
		IDOBV IDOBN IDOBC
		FDOBV FDOBN FDOBC
		IDBBV IDBBN IDBBC
		FDBBV FDBBN FDBBC

		IONSV IONSN IONSC
		FONSV FONSN FONSC
		IOOSV IOOSN IOOSC
		FOOSV FOOSN FOOSC
		IONRV IONRN IONRC
		FONRV FONRN FONRC
		IOORV IOORN IOORC
		FOORV FOORN FOORC
		IOBRV IOBRN IOBRC
		FOBRV FOBRN FOBRC
		IOBSV IOBSN IOBSC
		FOBSV FOBSN FOBSC
		IONBV IONBN IONBC
		FONBV FONBN FONBC
		IOOBV IOOBN IOOBC
		FOOBV FOOBN FOOBC
		IOBBV IOBBN IOBBC
		FOBBV FOBBN FOBBC
	;
	merge outsas.enr_ben2
		  outsas.fam_ben2;

	/*set client, plan, N_ind, and N_fam from macro parmaters*/
	N_ind 	  = &tot_enroll;
	N_fam	  = &tot_fam;
	CLIENT    = &cur_client;
	PLAN      = &cur_plan;
	PLANKEY	  = &plankey;
	st_year   = &st_year;
	st_month  = &st_month;
	end_year  = &end_year;
	end_month = &end_month; 

	/*DEDUCATABLE LOGIC*/
	array max_in{36} IDNSV IDOSV IDNRV IDORV IDBRV IDBSV IDNBV IDOBV IDBBV
		FDNSV FDOSV FDNRV FDORV FDBRV FDBSV FDNBV FDOBV FDBBV
		IONSV IOOSV IONRV IOORV IOBRV IOBSV IONBV IOOBV IOBBV
		FONSV FOOSV FONRV FOORV FOBRV FOBSV FONBV FOOBV FOBBV
	;
	array n_in 	{36} IDNSN IDOSN IDNRN IDORN IDBRN IDBSN IDNBN IDOBN IDBBN
		FDNSN FDOSN FDNRN FDORN FDBRN FDBSN FDNBN FDOBN FDBBN
		IONSN IOOSN IONRN IOORN IOBRN IOBSN IONBN IOOBN IOBBN
		FONSN FOOSN FONRN FOORN FOBRN FOBSN FONBN FOOBN FOBBN
	;
	array cats_out{36} IDNSC IDOSC IDNRC IDORC IDBRC IDBSC IDNBC IDOBC IDBBC
		FDNSC FDOSC FDNRC FDORC FDBRC FDBSC FDNBC FDOBC FDBBC
		IONSC IOOSC IONRC IOORC IOBRC IOBSC IONBC IOOBC IOBBC
		FONSC FOOSC FONRC FOORC FOBRC FOBSC FONBC FOOBC FOBBC
	;

	/*A 3 stage test for each:
		1)	Is the value non-zero?
		2) 	Are there multiple instances (enrollees/families) with the value
		3)  Is the value devisable by 10 (or some other value)
	*/

	/*The following categories apply:
		0 = No information available
		1 = Amount detected for multiple persons with appropriate value (rounds nearest 10)
		2 = Amount detected with appropriate value for only one person (rounds nearest 10)
		3 = Amount detected with not clear indication of benefit limit (Plan has value above this value)
	  NOTE: We round to the nearest dollar to avoid issue
	*/
	do i = 1 to dim(max_in);
		/*set the category for each of the possible deductables*/
		if (round(max_in{i},1) > 0 AND
			round(max_in{i},1) = round(max_in{i}, 10) AND
			n_in{i} >1) then
			do;
				cats_out{i} = 1;
			end;
		else if (round(max_in{i},1) > 0 AND round(max_in{i},1) = round(max_in{i}, 10)) then
			do;
				cats_out{i} = 2;
			end;
		else if (round(max_in{i},1) > 0 AND round(max_in{i},1) ne round(max_in{i},10)) then
			do;
				cats_out{i} = 3;
			end;
		else cats_out(i)=0;
	end;

	/*Algorithm to detect plan deductables:
	This sets the Deductable Design variables (BDBBC)
	4=single in/out of network deductables inclusive of Rx (Likely HD qualifying plan)
	3=single in/out of network deductables exclusive of Rx (Potenital HD plan)
	2=separate in and out of network deductables inclusive of Rx
	1=separate in and out of network deductables exclusive of Rx
	0=insufficient information to identify any deductable
	NOTE 1: The logic first checks for type 4 then 3 then 2 etc.  
	NOTE 2: Types 4-1 require a "clear" signal, in that, no other contraindicating signal can co-occur
	Multiple signals are registered as type 0
	NOTE 3: (I)ndividual and (F)amily are tested separately (nested OR logic):
	If either I or F variables have a clear signal, the result is assigned.
		THIS IMPLIES Inds AND Fams HAVE A PARALLEL DEDUCTABLE STRUCTURE
	*/
	if (( (rx = 1 | IDBRV>0) /*pharmacy requirement and signal*/
		&(IDBBC =1 & IDBSC ne 1) /*signal of multiple at combined level with Rx*/
		&(IDOBC ne 1 & IDOSC ne 1 & IDNBC ne 1 & IDNSC ne 1) /*no alternative clear signals*/
	)
	|( (rx = 1 | FDBRV>0) /*pharmacy requirement and signal*/
		&(FDBBC =1 & FDBSC ne 1) /*signal of multiple at combined level with Rx*/
		&(FDOBC ne 1 & FDOSC ne 1 & FDNBC ne 1 & FDNSC ne 1) /*no alternative clear signals*/
	)) then
		do;
			BDBBC = 4;
		end;
	else if (((IDBBC ne 1 & IDBSC = 1) /*signal of multiple at combined level with no Rx*/
		&(IDOBC ne 1 & IDOSC ne 1 & IDNBC ne 1 & IDNSC ne 1) /*no alternative clear signals*/
	)
	|((FDBBC ne 1 & FDBSC = 1) /*signal of multiple at combined level with no Rx*/
		&(FDOBC ne 1 & FDOSC ne 1 & FDNBC ne 1 & FDNSC ne 1) /*no alternative clear signals*/
	)) then
		do;
			BDBBC = 3;
		end;
	else if (((rx = 1 | IDBRV>0) /*pharmacy requirement and signal*/
		&((IDOBC = 1 & IDNBC ne 0) | (IDOBC ne 0 & IDNBC = 1)) /*a signal of Rx inclusion with at least on strong signal*/
		&(IDBSC ne 1 & IDBBC ne 1 & IDOSC ne 1 & IDNSC ne 1)   /*no alternative clear signals*/
	)
	|((rx = 1 | FDBRV>0) /*pharmacy requirement and signal*/
		&((FDOBC = 1 & FDNBC ne 0) | (FDOBC ne 0 & FDNBC = 1)) /*a signal of Rx inclusion with at least on strong signal*/
		&(FDBSC ne 1 & FDBBC ne 1 & FDOSC ne 1 & FDNSC ne 1)   /*no alternative clear signals*/
	)) then
		do;
			BDBBC = 2;
		end;
	else if ((((IDOSC = 1 & IDNSC ne 0) | (IDOSC ne 0 & IDNSC = 1)) /*two indicators with at least on strong signal*/
		&(IDBSC ne 1 & IDBBC ne 1 & IDOBC ne 1 & IDNBC ne 1)   /*no alternative clear signals*/
	)
	|(((FDOSC = 1 & FDNSC ne 0) | (FDOSC ne 0 & FDNSC = 1)) /*two indicators with at least on strong signal*/
		&(FDBSC ne 1 & FDBBC ne 1 & FDOBC ne 1 & FDNBC ne 1)   /*no alternative clear signals*/
	)) then
		do;
			BDBBC = 1;
		end;
	else 	BDBBC = 0;

	/*OOP MAX LOGIC*/

	/*Algorithm to detect plan OOP maximums:
		This sets the Deductable Design variables (BOBBC)
			2=OOP inclused Rx
			1=OOP is exclusive of Rx
			0=insufficient information to identify Plan OOP maximums
	   NOTE 1: The logic first checks for type 2 then 1 then defaults to type 0.  
	   NOTE 2: Types 1 and 2 require a "clear" signal, in that, no other contraindicating signal can co-occur
			   MULTIPLE "clear" signals are registered as type 0 (e.g. Rx included and Rx not included)
	   NOTE 3: (I)ndividual and (F)amily are tested separately (nested OR logic):
				If either I or F variables have a clear signal, the result of the clear signal is assigned.
				THIS IMPLIES Inds AND Fams HAVE A PARALLEL OOP STRUCTURE
				IN THE CASE OF ONLY ONE CLEAR SIGNAL, THIS "FORCES" THE OTHER.  THE ACTUAL *O***C VARIABLES MUST BE USED TO IDENTIFY
				IF A CLEAR SIGNAL FOR IND AND FAM EXISTS 
	*/
	if (( (rx = 1 | IOBRV>0) /*pharmacy requirement and signal*/
	&(IOBBC =1 & IOBSC ne 1) /*signal of multiple at combined level with Rx*/
	&(IOOBC ne 1 & IOOSC ne 1 & IONBC ne 1 & IONSC ne 1) /*no alternative clear signals*/
	)
	|( (rx = 1 | FOBRV>0) /*pharmacy requirement and signal*/
	&(FOBBC =1 & FOBSC ne 1) /*signal of multiple at combined level with Rx*/
	&(FOOBC ne 1 & FOOSC ne 1 & FONBC ne 1 & FONSC ne 1) /*no alternative clear signals*/
	)) then
		do;
			BOBBC = 2;
		end;
	else if (((IOBBC ne 1 & IOBSC = 1) /*signal of multiple at combined level with no Rx*/
	&(IDOBC ne 1 & IDOSC ne 1 & IDNBC ne 1 & IDNSC ne 1) /*no alternative clear signals*/
	)
	|((FOBBC ne 1 & FOBSC = 1) /*signal of multiple at combined level with no Rx*/
	&(FOOBC ne 1 & FOOSC ne 1 & FONBC ne 1 & FONSC ne 1) /*no alternative clear signals*/
	)) then
		do;
			BOBBC = 1;
		end;
	else 			BOBBC = 0;
run;



/*Clean Up*/
%if &del_input=N %then %do;
	proc datasets library=&outlib. noprint;
		delete 
			outpt1
			inpt1
			rx1
			outpt_dt
			inpt_dt
			rx_dt
			merge1
			final_util_data
			enrollee_year
			family_year
			enroll_deduct_oop
			family_deduct_oop
	    	enr_ben1
			enr_ben2
			fam_ben1
			fam_ben2
			;
	run;
%end;
%else %do;
	proc datasets library=&outlib. noprint;
		delete 
			&enroll_cy_in
			&outpt_in
			&inpt_in
			&rx_in
			outpt1
			inpt1
			rx1
			outpt_dt
			inpt_dt
			rx_dt
			merge1
			final_util_data
			enrollee_year
			family_year
			enroll_deduct_oop
			family_deduct_oop
	    	enr_ben1
			enr_ben2
			fam_ben1
			fam_ben2
			;
	run;
%end;

%mend deduct_oop;



