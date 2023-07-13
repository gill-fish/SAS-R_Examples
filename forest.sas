/*
   Ryan Gallagher
   June/July 2023
   Aufderheide Project - Making Forest Plots
*/


libname auf 'auf';


/* --------------------------------------*/
/* Initial Cleaning & Setting Inclusion Criteria */
/* --------------------------------------*/

data isch;
    set auf.dn;

    *format age age.;
    *format Time_btwn_prehosp_ED_ECG EDECGaq.;

    if Prehospital_Ischemic = "Y";

    if Change_in_ECG_Classification = "Yes Decreased" then j=1;
    if Change_in_ECG_Classification = "No" | Change_in_ECG_Classification = "Yes Increased" then j=0;

    aged10 = age/10;
    /* Do this for the last three variables too */

    
    Time_betwn_prehos_ED_ECG = Time_btwn_prehosp_ED_ECG/10;

    If Initial_cardiac_arrest_rhythm = "PEA"|
        Initial_cardiac_arrest_rhythm = "Asystole" |
        Initial_cardiac_arrest_rhythm = "AED" then I_cardiac_arrest_rhythm = "Non_Shockable";
    If Initial_cardiac_arrest_rhythm = "VF/VT" then I_cardiac_arrest_rhythm = "Shockable";

run;




data nonisch;
    set auf.dn;

    if Prehospital_Non_Ischemic = "Y";

    if Change_in_ECG_Classification = "Yes Increased" then j=1;
    if Change_in_ECG_Classification = "No" then j=0;

    aged10 = age/10;
    Time_betwn_prehos_ED_ECG = Time_btwn_prehosp_ED_ECG/10;

    If Initial_cardiac_arrest_rhythm = "PEA"|
        Initial_cardiac_arrest_rhythm = "Asystole" |
        Initial_cardiac_arrest_rhythm = "AED" then I_cardiac_arrest_rhythm = "Non_Shockable";
    If Initial_cardiac_arrest_rhythm = "VF/VT" then I_cardiac_arrest_rhythm = "Shockable";
run;



/* --------------------------------------*/
/* Build regression macro */
/* --------------------------------------*/

%macro logi(var= , group=, cont='no', refer=);

    %if ~%sysfunc(exist(work.tbls)) %then %do;
        data tbls;
            length Parameter $100.;
        run;
    %end;

    proc logistic data=&group;
        ods output ExactOddsRatio=otter;

        %if &cont='yes' %then %do;
            class &var(ref=&refer) / param=ref;
        %end;

    /* exact statement? change table output*/
    /* Exact statement will create a new table (maybe just rename oddsratiowald)
       This will make me have to go through the macro again if any changes are necessary */
    
        model j=&var / orpvalue firth;
        oddsratio &var;
        exact &var / estimate=odds cltype=midp;
    run;

    data tbls;
        set tbls otter;
    run;
%mend;

/* All continuous variables */
%let cont_list = aged10 Prehospital_defibrillations Ed_defibrillations Prehospital_epinephrine_dose
    Total_defibrillations ED_epinephrine_push_dose Total_epinephrine_push_dose
    Prehospital_rearrests ED_rearrests Total_rearrests Time_from_ROSC_to_ECG Time_betwn_prehos_ED_ECG
    Duration_of_prehospital_CPR;
%let cont_num = %sysfunc(countw(&cont_list));

/* All categorical variables with their reference groups */
%let cat_list = Gender Witnessed_status Bystander_CPR I_cardiac_arrest_rhythm Epinephrine_infusion
    Prehospital_norepinephrine ED_norepinephrine Any_norepinephrine Dopamine_infusion;
%let ref_list = F Unwitnessed N Non_Shockable N N N N N;
%let cat_num = %sysfunc(countw(&cat_list));

/* run %logi over all continuous variables */
%macro cont_isch;
%do i=1 %to &cont_num;
    %let c_var = %scan(&cont_list, &i);
    %logi(var=&c_var, group=isch);
%end;
%mend;

%macro cont_NONisch;
%do i=1 %to &cont_num;
    %let c_var = %scan(&cont_list, &i);
    %logi(var=&c_var, group=nonisch);
%end;
%mend;

/* run %logi over all categorical variables */
%macro cat_isch;
%do i=1 %to &cat_num;
    %let c_var = %scan(&cat_list, &i);
    %let c_ref = %scan(&ref_list, &i);
    %logi(var=&c_var, group=isch, cont='yes', refer="&c_ref");
%end;
%mend;

%macro cat_NONisch;
%do i=1 %to &cat_num;
    %let c_var = %scan(&cat_list, &i);
    %let c_ref = %scan(&ref_list, &i);
    %logi(var=&c_var, group=nonisch, cont='yes', refer="&c_ref");
%end;
%mend;

/* --------------------------------------*/
/* Run Macros */
/* --------------------------------------*/

/* Ischemic */
%cont_isch;
%cat_isch;

data OR_isch;
    set tbls;

    if not missing(Parameter);

    
    if _N_=16 then Parameter = "Witnessed Status - Unwitnessed vs Bystander";
    if _N_=17 then Parameter = "Witnessed Status - Unwitnessed vs EMS";
run;

/* reset the tbls set */
data tbls;
    length Parameter $100.;
run;

/* Nonischemic */
%cont_nonisch;
%cat_nonisch;

data OR_nonisch;
    set tbls;

    
    if not missing(Parameter);

    
    if _N_=16 then Parameter = "Witnessed Status - Unwitnessed vs Bystander";
    if _N_=17 then Parameter = "Witnessed Status - Unwitnessed vs EMS";
run;


/* ------------------------*/
/*	  Formatting       */
/* ------------------------*/
proc format;
    value $y_labs
    "aged10" = "Age (per 10 years)"
    "Gender" = "Gender - M vs F"
    "Witnessed_status EMS vs Unwitnessed" = "Witnessed Status - EMS vs Unwitnessed"
    "Witnessed_status Bystander vs Unwitnesse" = "Witnessed Status - Bystander vs Unwitnessed"
    "Witnessed_status Bystander vs EMS" = "Witnessed Status - Bystander vs EMS"
    "Bystander_CPR" = "Bystander CPR"
    "I_cardiac_arrest_rhy" = "Initial Cardiac Arrest Rhythm - Shockable vs. Nonshockable"
    "Prehospital_defibril" = "Prehospital Defibrillations"
    "ED_defibrillations" = "ED Defibrillations"
        "Total_defibrillation" = "Total Defibrillations"
        "Prehospital_epinephr" = "Prehospital Epinephrine Push Dose"
        "ED_epinephrine_push_" = "ED Epinephrine Push Dose"
        "Total_epinephrine_pu" = "Total Epinephrine Push Dose"
        "Prehospital_norepine" = "Prehospital Norepinephrine"
        "ED_norepinephrine" = "ED Norepinephrine"
        "Any_norepinephrine" = "Any Norepinephrine"
        "Epinephrine_infusion" = "Epinephrine Infusion"
        "Dopamine_infusion" = "Dopamine Infusion"
        "Prehospital_rearrest" = "Prehospital Rearrests"
       "ED_rearrests" = "ED Rearrests"
       "Total_rearrests" = "Total Rearrests"
       "Time_from_ROSC_to_EC" = "Time from ROSC to Prehospital ECG Acquisition"
        "Time_betwn_prehos_ED" = "Time between Prehospital and ED ECG Acquisition"
        "Duration_of_prehospi" = "Duration of Prehospital CPR Prior to First ROSC"
        ;

    value $order
        "aged10" = '01'
        "Gender" = '02'
    "Witnessed Status - Unwitnessed vs Bystander" = '03'
    "Witnessed Status - Unwitnessed vs EMS" = '04'
    "Witnessed Status - Bystander vs EMS" = '05'
    "Bystander_CPR" = '06'
    "I_cardiac_arrest_rhy" = '07'
    "Prehospital_defibril" = '08'
    "ED_defibrillations" = '09'
        "Total_defibrillation" = '10'
        "Prehospital_epinephr" = '11'
        "ED_epinephrine_push_" = '12'
        "Total_epinephrine_pu" = '13'
        "Prehospital_norepine" = '15'
        "ED_norepinephrine" = '16'
        "Any_norepinephrine" = '17'
        "Epinephrine_infusion" = '14'
        "Dopamine_infusion" = '18'
        "Prehospital_rearrest" = '19'
       "ED_rearrests" = '20'
       "Total_rearrests" = '21'
       "Time_from_ROSC_to_EC" = '22'
       "Time_betwn_prehos_ED" = '23'
       "Duration_of_prehospi" = '24'
        ;
run;

data OR_isch;
    length Parameter $50.;
    format Parameter $y_labs.;
    set OR_isch;

    order = put(Parameter, order.);
run;

proc sort data=OR_isch;
    by order;
run;

data OR_nonisch;
    length Parameter $50.;
    format Parameter $y_labs.;
    set OR_nonisch;

    order = put(Parameter, order.);
run;

proc sort data=OR_nonisch;
    by order;
run;


data OR_isch;
    set OR_isch;

    if LowerCL <= 0 then LowerCL = 0.001;
    lowercl_r = round(lowercl, 0.001);
    uppercl_r = round(uppercl, 0.001);
    est_r = round(Estimate, 0.001);
    OR_CI = cat(est_r, ' (', lowercl_r, ' to ', uppercl_r, ')');
run;

data OR_nonisch;
    set OR_nonisch;

    /* HELP WITH ED DEFIB */
    *if OddsRatioEst < 900;

    lowercl_r = round(lowercl, 0.001);
    uppercl_r = round(uppercl, 0.001);
    est_r = round(Estimate, 0.001);

    OR_CI = cat(est_r, ' (', lowercl_r, ' to ', uppercl_r, ')');
     
run;

/* Create x-axis arrows for OR interpretation. */

data arrowsannoISCH;
    length function $20.;
    x1=66;
    x2=43;
    y1=2.5;
    y2=2.5;
    function = 'arrow';
    shape = 'filled';
    linecolor='black';
    output;

    x1=54.5;
    y1=1;
    function='text';
    label='Sustained Ischemia or Evolution of STEM I';
    width=200;
    textsize=7.8;
    output;

    x1=69;
    x2=92;
    y1=2.5;
    y2=2.5;
    function='arrow';
    shape='filled';
    linecolor='black';
    output;

    x1=80;
    y1=1;
    function='text';
    label='Resolved Ischemia';
    width=200;
    textsize=7.8;
    output;
run;

data arrowsannoNONISCH;
    length function $20.;
    length label $40.;
    x1=66;
    x2=43;
    y1=2.5;
    y2=2.5;
    function = 'arrow';
    shape = 'filled';
    linecolor='black';
    output;

    x1=54.5;
    y1=1;
    function='text';
    label='Sustained Non-Ischemia';
    width=200;
    textsize=7.8;
    output;

    x1=69;
    x2=92;
    y1=2.5;
    y2=2.5;
    function='arrow';
    shape='filled';
    linecolor='black';
    output;

    x1=80;
    y1=1;
    function='text';
    label='Evolution to Ischemic or STEM I';
    width=250;
    textsize=7.8;
    output;
run;
    

title 'ischemic';

proc contents data=OR_isch;
proc print data=OR_isch;
run;


title 'nonischemic';
proc contents data=OR_nonisch;
proc print data=OR_nonisch;
run;
/* --------------------------------------*/
/* Build Plots */
/* --------------------------------------*/

ods graphics on / imagename='forest_ISCH' width=10in height=8in;
proc sgplot data=OR_isch sganno=arrowsannoISCH noautolegend;
    refline 1 / axis=x;
    scatter x=Estimate y=Parameter / markerattrs=or (symbol=DiamondFilled size=8);

    highlow y=Parameter low=lowercl high=uppercl / Clipcap clipcapshape=closedarrow;

    yaxistable OR_CI / nolabel location=inside position=right Title = "Odds Ratio (95% CI)" titleattrs=(size=8 weight=Bold);

    xaxis label=" " min=0.05 max=10 type=log;
    yaxis label=' ' colorbands=odd colorbandsattrs=(color=gray transparency=0.7) discreteorder=data reverse; /* Put order here */

    title "Forest Plot - Ischemic Patients";
run;

ods graphics off;

ods graphics on / imagename = 'forest_NONISCH' width=10in height=8in;
proc sgplot data=OR_nonisch sganno=arrowsannoNONISCH noautolegend;
    refline 1 / axis=x;
    scatter x=Estimate y=Parameter / markerattrs=or (symbol=DiamondFilled size=8);

    highlow y=Parameter low=lowercl high=uppercl / Clipcap clipcapshape=closedarrow;

    yaxistable OR_CI / nolabel location=inside position=right Title = "Odds Ratio (95% CI)" titleattrs=(size=8 weight=Bold);
    
    
    yaxis label=' ' colorbands=odd colorbandsattrs=(color=gray transparency=0.7) discreteorder=data reverse;
    xaxis label=" " min=0.05 max=10 type=log;
    
    title "Forest Plot - Nonischemic Patients";
run;

ods graphics off;

       