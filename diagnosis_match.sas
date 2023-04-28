/*
   Written by: Ryan Gallagher
   Edited for the purpose of sample presentation on 4/26/2023
*/


/* 
   This file matches diagnoses to individuals in an input cohort (defined in cohorts.sas)
   These diagnoses datasets assign each patient a binary outcome for the respective diagnosis (gotten from TriNetX EMR pulls)
   and a date of the diagnosis. These are to be merged to one large dataset with all outcomes.
*/
   

data match;
    merge scd.cardiomyopathy(in=carmyo)
        scd.chronic_kidney_disease(in=ckd)
        scd.dysrhythmia(in=dys)
        scd.heart_failure(in=fail)
        scd.hematuria(in=hema)
        scd.hemodialysis(in=dial)
        scd.long_qt(in=qt)
        scd.proteinuria(in=prot)
        scd.pulmonary_fibrosis(in=pulfib)
        scd.pulmonary_hypertension(in=pulhyp)
        ;
    by patient_id;

run;

* Checking that all dates are properly formatted;
proc contents data=match VARNUM;
run;

/* Begin creating a macro that takes a dataset and a last_date */
%macro d_match(base=, last=);

/* Take off library prefix - if base=scd.kids19 then nopref=kids19*/
%let nopref = %scan(&base, -1);
%put &nopref;


/* Merge selected cohort with datasets */
data &nopref._m;
    merge &base(in=invar) match;
    if invar;
run;

/* Define a list to reference each dataset */
%local list;
%let list=cardiomyopathy chronic_kidney_disease dysrhythmia heart_failure
          hematuria hemodialysis long_qt proteinuria pulmonary_fibrosis pulmonary_hypertension;

/* Check for date discrepancies. These new datasets will not be assigned to a library just yet. */
data &nopref._m;
    set &nopref._m;

    %do i=1 %to %_count(&list);
        %let diag=%scan(&list, &i);
        
        if &diag._d > &last then do;
            &diag.=0;
            &diag._d=.;
    end;
  %end;
run;

%mend;

/* Call macro to apply to different datasets, with different end dates */
%d_match(base=scd.kids19, last=last19_d);
%d_match(base=scd.kids20, last=last20_d);
%d_match(base=scd.adults19, last=last19_d);
%d_match(base=scd.adults20, last=last20_d);
%d_match(base=scd.transition19, last=last19_d);
%d_match(base=scd.transition20, last=last20_d);


/* Check frequency statistics for these new datasets (This can and should be macro'd)*/
title 'kid19 freq';
proc freq data=kids19_m;
    tables sex race age cardiomyopathy chronic_kidney_disease dysrhythmia heart_failure
          hematuria hemodialysis long_qt proteinuria pulmonary_fibrosis pulmonary_hypertension;
    format age age.;
run;

title 'kid20 freq';
proc freq data=kids20_m;
    tables cardiomyopathy chronic_kidney_disease dysrhythmia heart_failure
          hematuria hemodialysis long_qt proteinuria pulmonary_fibrosis pulmonary_hypertension;
run;

title 'adults19 freq';
proc freq data=adults19_m;
    tables sex race age cardiomyopathy chronic_kidney_disease dysrhythmia heart_failure
          hematuria hemodialysis long_qt proteinuria pulmonary_fibrosis pulmonary_hypertension;
    format age age.;
run;


title 'adults20 freq';
proc freq data=adults20_m;
    tables cardiomyopathy chronic_kidney_disease dysrhythmia heart_failure
          hematuria hemodialysis long_qt proteinuria pulmonary_fibrosis pulmonary_hypertension;
run;


/* Write to SAS library when sufficient (This also could be macro'd)*/
data scd.kids19_m;
    set kids19_m;
run;

data scd.kids20_m;
    set kids20_m;
run;

data scd.adults19_m;
    set adults19_m;
run;

data scd.adults20_m;
    set adults20_m;
run;

data scd.transition19_m;
    set transition19_m;
run;

data scd.transition20_m;
    set transition20_m;
run;


