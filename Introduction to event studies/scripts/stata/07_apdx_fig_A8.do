#delimit ;


set trace off ;
set more off ;
clear ;
set seed 101 ;

cap prog drop runme ; 
prog def runme ;


gendata ;

qui replace E_i = -999 if E_i == . ;
egen unittype = group(E_i) ;
qui replace E_i = . if E_i == -999 ;
summ ; 


egen meany = mean(y) , by(t unittype) ;

sort t ;	
graph twoway 
	(connected meany t if unittype == 2,  msize(medsmall) 
		msymbol(o) lpattern(solid) )
	(connected meany t if unittype == 1,  msize(medium) 
		msymbol(oh) lpattern(dot) )
		, legend(off) xline(9.5) 
		note("Raw means for treated and control.") 
		name(g1 , replace) nodraw ;



/* 1, unit FE's among all average to zero */
constraint define 1 1.unittype + 2.unittype = 0 ;

/* 2 pre-treatment ES dummies average to zero */
constraint define 2 D_m10 + D_m9 + D_m8 + D_m7 + D_m6 + D_m5 + D_m4 + 
	D_m3 + D_m2 + D_m1 = 0 ; 
		
/* 4, 5, 6: first few terms are the same */
constraint define 4 D_m11 = D_m10 ;
constraint define 5 D_m10 = D_m9 ;
constraint define 6 D_m9 = D_m8 ;
constraint define 7 D_m8 = D_m7 ;
	

/* model 1 */	
cnsreg y D_m11 D_m10 D_m9 D_m8 D_m7 D_m6 D_m5 D_m4 D_m3 D_m2 
	D_m1 D_p0 D_p1 D_p2 D_p3 D_p4 D_p5 D_p6 D_p7 D_p8 D_p9 D_p10 D_p11 D_p12 
	ibn.t ibn.unittype , nocons constraints(1 2 4 5 6 7)  collinear ;
matrix myb_ES2 = e(b) ;
/* create counterfactulal predictions by subtracting off the ES coefficients.
		then average these up by unit-type and time.  */
gen cf_ES2 = y ;
qui summ etime ;
local mymin = r(min) ;
local mymax = r(max) ;
forvalues i = `mymin'/`mymax' { ;
	if `i' < 0 { ;
		local j = abs(`i') ;
		replace cf_ES2 = cf_ES2 - _b[D_m`j'] * D_m`j' ;
	} ;
	if `i' >= 0 { ;
		replace cf_ES2 = cf_ES2 - _b[D_p`i'] * D_p`i' ;
	} ;
} ;
egen meancf_ES2 = mean(cf_ES2) , by(t unittype) ;




tempfile main ;
save `main' ;

/* now get the results ready to plot out */

*set trace on ;
tempfile pooled ;
forvalues i = 0/10 { ;
	drop _all ;
	set obs 2 ;
	gen label = "m`i'" in 1 ;
	replace label = "p`i'" in 2 ;

	gen etime = -1 * `i' in 1 ;
	replace etime = `i' in 2 ;

	foreach j in 2  { ;
		gen cf_m`j' = .	 ;	
		gen truth_m`j' = (0) in 1 ;	/* endless ramp function for treatment effect */
		replace truth_m`j' = (`i' + 1) in 2 ;	/* endless ramp function for treatment effect */
	
		local myb = 0 ;
		cap local myb = myb_ES`j'[1,"D_m`i'"] ;
		gen ES_b_m`j' = `myb' in 1 ;

		local myb = 0 ;
		cap local myb = myb_ES`j'[1,"D_p`i'"] ;
		replace ES_b_m`j' = `myb' in 2 ;
	} ;

	capture append using `pooled' ;
	save `pooled' , replace ;
} ;


drop if label == "m0" ;
drop if label == "p10" ;
sort etime ;
save `pooled' , replace ;

list ;

foreach i in 2 { ;
	use `pooled' , replace ;
	graph twoway (connected ES_b_m`i' truth_m`i' etime ,  msize(medsmall medium) 
		msymbol(o oh) mcolor(blue green) lpattern(solid dot) )
		, legend(off) xline(-0.5) 
		note("Estimated treatement effects.") 
		name(g`i', replace) ;

	use `main' , replace ;
		
	graph twoway 
		(connected meany  meancf_ES`i' t if unittype == 2,  
		msize(medsmall medium) msymbol(o oh) mcolor(blue orange)  
		lpattern(solid dot) )
		(connected meany  meancf_ES`i' t if unittype == 1,  
		msize(medsmall medium) msymbol(o oh) mcolor(blue orange)  
		lpattern(solid dot) )
		, legend(off) xline(7.5 11.5) 
		note("Raw means for each group, and counterfactuals.") 
		name(gfig4m`i' , replace) ;
		
		
} ;

graph combine g2 gfig4m2 ,
	ti("Getting closer to the raw data.  DiD data structure.") ;
	graph export figures/apdx_fig_A08.png , replace ;


end ;

cap prog drop gendata ;
program define gendata ;

/*****************
	MAIN DGP OPTIONS
	
/* Possible Treatment Effect Types */
	1 - zero TE
	2 - Step fn TE
	3 - Ramp-up Forever
	4 - Ramp-up Plateau
	5 - AR(1) type

/* Distribution of E_i */
	T = 19; E_i ~ U(6,14)

/* Are there Never-treated units ?? */
	Yes; No
	
/*  Y0 ("signal" for potential outcomes) dynamics */
	1 - Base: Y0 = 0
	2 - Levels variation: Y0_i,t = E_i
	3 - trends variation: Y0_i,t = t * E_i

	END OF MAIN OPTIONS
******************/

drop _all ;

/* ES data structure w/ 2 treatment dates */
set obs 10 ;									/* number of units */
gen i = _n ;
gen E_i = 8 + 4 * (i >= 6) ;
gen treated = 1 ;							/* all units treated */
expand 20 ;									/* number of time periods */

/*
/* NxT DiD data structure */
set obs 10 ;									/* number of units */
gen i = _n ;
gen treated = i > 5 ;							/* half of units treated */
gen E_i = 11 if treated == 1 ;
expand 20 ;									/* number of time periods */
*/

sort i ;
qui by i: gen t = _n ;

xtset i t ;

/* make variables that determine the DGP */
gen D = (t == E_i) ; 						/* the event "pulse" */
gen etime = (t - E_i) ;						/* event time */

/* gen TE = 1 * (etime >= 0) ;					/* step function treatment effect */
*/
gen TE = (etime >= 0) * (etime+1) ;				/* endless ramp function for treatment effect */
replace TE = 0 if E_i == . ;

gen treated_post = etime >= 0 ;

*gen Y0_pure = 0 ;							/* simplest counterfactual */
*gen Y0_pure = 0 + 4 * treated ;					/* level shift */
gen Y0_pure = 0 + 6 * (E_i >= 10) ;					/* level shift */
*gen Y0_pure = 4 * treated +  0.4 * treated * t ;			/* treated have a pre-trend ... */

gen eps = sqrt(0.2) * rnormal() ;
gen actual = Y0_pure + TE * treated ;		
gen y = actual + eps ;						/* observed Y */

/* create variables used for estimation */
/* event time dummies */
qui summ etime ;
local mymin = r(min) ;
local mymax = r(max) ;
forvalues i = `mymin'/`mymax' { ;
	if `i' < 0 { ;
		local j = abs(`i') ;
		gen D_m`j' = (etime == `i') ;
	} ;
	if `i' >= 0 { ;
		gen D_p`i' = (etime == `i') ;
	} ;
} ;

end ;


runme ;