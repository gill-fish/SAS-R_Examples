/*
   Written by: Ryan Gallagher
   Edited for the purpose of sample presentation on 4/26/2023
*/

/*
   For my consulting class, we did a roleplay project where we'd be assigned as a PhD, Data Analyst, or PI. This was my
   project where I was assigned as the Data Analyst.

   The PI wanted to look at "The Effect of mRNA COVID-19 vaccine in Adult Type 2 Diabetics on COVID-19 180-Day Reinfection". Data was
   pulled from the TriNetX database where we got ~8,000 raw observations. This file shows my data cleaning and manipulation (using
   SAS) to filter exactly which patients were relevant to this question.

   The population of Adult Type 2 diabetics were filtered through TriNetX before pulling, but the question of "reinfection" meant we had 
   to find individuals who:
	a. Had COVID, then got the mRNA vaccine, then got COVID again.
		-> AND got their full vaccination (2 doses needed for full vaccination)
	b. Had COVID, did NOT get the mRNA vaccine but GOT the flu vaccine, then got COVID again
		-> This is for the purpose of setting a "time 0" for a contrasting group to those who got the mRNA vaccine
	c. Had a diagnosis within our follow-up period ('01JAN2021' - '31DEC2022')

   This cohort was formed. We were also interested in looking at comorbidities - so this code merges this cohort with data
   relating to demographics, smoking habits, and hypertension. 
*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------------------------------------*/


/* 
   To be included, a patient needs to have: Type 2 Diabetes
   and a covid positive result between Jan 1 2021 and Dec 31 2022
   and either a flu vaccination or covid vaccination
    (does covid have to be before the vaccine? - YES)
    (START AT SECOND DOSE DATE OR FLU DATE)

   Outcome is:
   Reinfection after 180 days post 2nd dose or flu dose.
*/

/* This is a powerful macro for writing frequency tables. I also assign the library "peter" which is the name of this project's PI. */
%include 'yamgast1.sas';
libname peter "~/04221/peter/libref/peter";


/* ---------------- T2DM Patients W/ COVID INFECTION & DATE OF INFECTION BTWN 01/01/21 and 12/31/2022----------------*/
data cohort_dx;
    set peter.diagn;
    by patient_num;

    /* This is the COVID-19 diagnosis code in our set */
    if dx_code = 'U07.1';
    
    drop dx_name dx_date_shifted;

    /* Filtering by date */
    if dx_date < '01JAN2021'd then delete;
    if dx_date > '31DEC2022'd then delete;
run;

/* Deleting duplicate entries of patient_number (Identifier) and dx_date (date of diagnosis) */
proc sort data=cohort_dx out=cohort_dx NODUPKEY;
    by patient_num dx_date;
run;

/* This is a slick way to make an array - now each individual patient has columns that identify each date of COVID19 diagnosis */
proc transpose data=cohort_dx out=cohort_dx
    prefix=dx_date_;
    by patient_num;
    var dx_date;
run;

/* ---------------------------------------------------------------------------------------*/

/* ------------------------------  Find Flu Vaccine ------------------------- ------------*/

/* We have immunization records from TriNetX which we call here */
data immun;
    set peter.immun;

    /* Date formatting (preference) */
    imm_date = input(immune_date_shifted, yymmdd10.);
    format imm_date date9.;

    /* All flu vaccines in our data started with 'INFLUENZA', so I called only these */
    where immunization_name like 'INFLUENZA%';

    /* Since we only care about immunizations after an infection, this is a quick way to rid entries early */
    if imm_date < '01JAN2021'd then delete;
    rename imm_date = flu_date;
run;


data immun;
    set immun;
    flu = 1;
    keep patient_num flu_date flu immnztn_status_c;
run;


proc sort data=immun out=immun NODUPKEY;
    by patient_num flu_date;
run;

proc transpose data=immun out=cohort_flu
    prefix=flu_date_;
    by patient_num;
    var flu_date;
run;

/* Routine steps above, we now have unique patient_numbers with the dates of their flu vaccine */
data cohort_flu;
    merge cohort_flu immun;
    by patient_num;
    drop flu_date _NAME_;
run;


/* ----------------------------------------------------------*/
/* ------------------- FIND COVID VACCINE STUFF -------------*/
/* ----------------------------------------------------------*/

/* 
   Lots of data cleaning here - for mRNA, I chose only to look at Pfizer and Moderna. These were input
   in 3-4 different ways, so here I'm just making them all common identifiers for each respective vaccine.
*/

data covid;
    set peter.immun;
    
    imm_date = input(immune_date_shifted, yymmdd10.);
    format imm_date date9.;

    if imm_product = "Modernna COVID-19 Vaccine" then imm_product = "Moderna COVID-19 Vaccine";
    if mfg_title="Pfizer" then mfg_title="PFIZER";

    if imm_product="COVID-19 mRNA LNP-S PF (Moderna) vaccine" then imm_product="Moderna COVID-19 Vaccine";
    if imm_product="COVID-19 mRNA LNP-S PF (Pfizer) vaccine" then imm_product="Pfizer-BioNTech COVID-19 Vacc";

    if mfg_title="PFIZER" | mfg_title="MODERNA US, INC." |
        imm_product="COVID-19 mRNA LNP-S PF (Moderna) vaccine" |
        imm_product="COVID-19 mRNA LNP-S PF (Pfizer) vaccine" |
        imm_product="Moderna COVID-19 Vaccine" |
        imm_product="Pfizer" |
        imm_product="Pfizer-BioNTech COVID-19 Vacc";

    if mfg_title="NA" & imm_product="NA" then delete;
    if mfg_title="PFIZER" & imm_product="NA" then imm_product="Pfizer-BioNTech COVID-19 Vacc";
    if mfg_title="MODERNA US, INC." & imm_product="NA" then imm_product="Moderna COVID-19 Vaccine";
    if mfg_title="NA" & imm_product="Moderna COVID-19 Vaccine" then mfg_title="MODERNA US, INC.";
    if mfg_title="NA" & imm_product="Pfizer-BioNTech COVID-19 Vacc" then mfg_title="PFIZER";
run;

/* This is creating a cohort similar to what was done in the flu set. */

data covid;
    set covid;

    if imm_date < '01JAN2021'd then delete;
    if imm_date > '31DEC2022'd then delete;
    
    rename imm_date = covid_vacc_date;
    if mfg_title = "MODERNA US, INC." then moderna=1;
    else moderna=0;
    if mfg_title = "PFIZER" then pfizer=1;
    else pfizer=0;
run;

proc sort data=covid out=covid nodupkey;
    by patient_num covid_vacc_date;
run;

proc transpose data=covid out=covid_vacc prefix=_covid_vacc_date;
    by patient_num;
    var covid_vacc_date;
run;

data covid_vacc;
    set covid_vacc;

    rename _covid_vacc_date2 = scnd_covid_dose;
    keep patient_num _covid_vacc_date2;
run;
    

/* ----------------------------------- form cohort -------------------------------- */


/* We now can merge all the created datasets - COVID-19 diagnosis + flu vaccine info + covid vaccine info. */
data cohort;
    merge cohort_dx cohort_flu covid_vacc;
    by patient_num;

    drop _NAME_;
run;

/* Now we'd like to find the soonest COVID-19 diagnosis after their respective vaccines (depending on if they're in the flu only or COVID group) */

data cohort;
    set cohort;

    if not missing(dx_date_1) & not missing(dx_date_2);

    /* I'll be using arrays here over a for loop */
    *array covid_vacc{*} _covid_vacc_date:;
    array flu_date{*} flu_date:;
    array dx_date{*} dx_date_:;

    soonest_dx_after_vacc = .;
    found=0;

     /* Get soonest dx_date after their second covid vacc */
    if not missing(scnd_covid_dose) then do i=1 to dim(dx_date);
        if not missing(dx_date[i]) then do;

            if dx_date[i] > scnd_covid_dose and (soonest_dx_after_vacc=. or dx_date[i] < soonest_dx_after_vacc) then do;
                soonest_dx_after_vacc = dx_date[i];
                found_covid=1;
            end;
        end;
    end;

    i=.;
    format soonest_dx_after_vacc date9.;

    /* I decide to call the COVID vacc group the 'intervention group' and the flu group the 'control' group. I make two variables when I could've made just one. */
    if not missing(scnd_covid_dose) & min(of dx_date{*}) < scnd_covid_dose then intervention=1;
    else intervention=0;

    if missing(scnd_covid_dose) & flu = 1 then control=1;
    else control=0;

    /* Some error checking */
    if control=0 & intervention=0 then delete;

    /* Get soonest dx_date after their flu shot */
    if control=1 then do i=1 to dim(dx_date);
        if not missing(dx_date[i]) then do;
            if dx_date[i] > min(of flu_date{*}) and (soonest_dx_after_vacc=. or dx_date[i] < soonest_dx_after_vacc) then do;
                soonest_dx_after_vacc = dx_date[i];
                found_flu=1;
            end;
        end;
    end;

    if control=1 and found_flu=. then delete;

    format flu_dose_d date9.;
    drop i;
run;

/* Keep only variables on intrest */
data cohort;
    set cohort;
    keep patient_num scnd_covid_dose soonest_dx_after_vacc intervention control flu_dose_d;
run;


/*---------------------------------------------------------------------*/
/*------------------------ Merge to include variables -----------------*/
/*---------------------------------------------------------------------*/

/* Missing soonest_dx_after_vacc means they didnt get reinfected */
/* Need age, gender, BMI, hypertension, and smoking */

/* This section goes through formatting and merging the datasets of intrest. */

/* --- Hypertension --- */
data hypertension;
    set peter.diagn;
    by patient_num;

    where dx_code like 'I10%';
run;

proc sort data=hypertension out=hypertension nodupkey;
    by patient_num dx_code;
run;

data hypertension;
    set hypertension;
    TEMPhypertension=1;
    keep patient_num TEMPhypertension;
run;
/* ----------------------*/

/* ---- Smoking ---------*/

proc sort data=peter.lifestyle out=smoking NODUPKEY;
    by patient_num;
run;

data smoking;
    set SMOKING;
    keep patient_num tobacco_user_c tobacco_user_name;
run;

/* ------------------------*/

/* -------- BMI  ----------*/
/* Here, we assign categorical groups based on BMI value */

data obesity;
    set peter.avg_vitals;

    length BMI $12;
    if missing(meanBMI) then BMI='';
    else if meanBMI < 18.5 then BMI = 'Underweight';
    else if 18.5 <= meanBMI <= 24.9 then BMI = 'Normal';
    else if 24.9 < meanBMI <= 29.9 then BMI = 'Overweight';
    else if 29.9 < meanBMI then BMI = 'Obese';

    keep patient_num meanBMI BMI;
run;

/* ------- demographics ----- */

proc sort data=peter.demog3 out=demog nodupkey;
    by patient_num;
run;

/* --------------------------- */


/* ----------- MERGED ---------*/

/* This set has our cohort of intrest. It's about 500 observations with 60% in the COVID group. */
/* For some of the assigned analysis, this is where I made new variables. */

data master;
    merge cohort(in=coh) hypertension smoking obesity demog;
    by patient_num;

    if coh;

    /* Create an AGE variable */
    b_day = input(birth_date_shifted, yymmdd10.);
    if not missing(soonest_dx_after_vacc) then age = year(soonest_dx_after_vacc) - year(b_day);
    else age=year(scnd_covid_dose) - year(b_day);

    /* Format the death_day */
    death_day = input(death_d, yymmdd10.);
    format death_day date9.;

    drop b_day death_d;
run;

proc sort data=master out=master NODUPKEY;
    by patient_num;
run;

data master;
    set master;

    /* 
       This is where I create the binary 'Reinfection' outcome (our primary outcome of intrest). It's created such that
       if the time between the repsecitve vaccination date and the reinfection day is LESS THAN 180 days, then reinfection=1.
       Else, reinfection=0
    */

    if missing(soonest_dx_after_vacc) then reinfectionTEMP_180=0;
    if not missing(soonest_dx_after_vacc) & intervention=1 then time_to_reinf = intck('days', scnd_covid_dose, soonest_dx_after_vacc);
    if not missing(soonest_dx_after_vacc) & control=1 then time_to_reinf = intck('days', flu_dose_d, soonest_dx_after_vacc);

    if not missing(time_to_reinf) & time_to_reinf < 180 then reinfectionTEMP_180 = 1;
    else if not missing(time_to_reinf) & time_to_reinf >= 180 then reinfectionTEMP_180=0;

    /* I spend some lines renaming groups for the sake of organization and clairity */
    if intervention=1 then group="covid vaccination";
    else group="flu vaccination";

    rename tobacco_user_name = tobacco;
    rename death_day = death_d;
run;

data master;
    set master;

    if reinfectionTEMP_180=1 then reinfection_180="Yes";
    else if reinfectionTEMP_180=0 then reinfection_180="No";
    
    if TEMPhypertension=1 then hypertension="Yes";
    else if missing(TEMPhypertension) then hypertension="No";

    if tobacco = "NA" | tobacco = "Passive" then tobacco="Never";

    if not missing(time_to_reinf) then reinfection=1;
    else reinfection=0;

    /* 
	I wanted to fit a Chi-Squared test, so I had to combine categories to avoid low cell counts
    */
    if race="Asian" | race="Multiracial" | race="Native Hawaiian or Other Pa" |
        race="American Indian or Alaska N" then race="Black or Other";

    if race = "Black or African American" | race="Other" then race="Black or Other";

    if death_d > '31DEC2022'd then death=0 & death_d = 'NA';
  
    /* 
	My professor assigned us to do some Survival Analysis and fit a Kaplain Meier curve with a Cox Regression.
	This section is for that analysis (which I did in R)
    */
 
    /* DEC 31st 2022 is the last day */
    if (control=1 & death=1) then time = intck('days', flu_dose_d, death_d);
    if (control=1  & death=0) then time = intck('days',flu_dose_d, '31DEC2022'd);

    if (intervention=1 & death=1) then time = intck('days', scnd_covid_dose, death_d);
    if (intervention=1 & death=0) then time = intck('days',scnd_covid_dose, '31DEC2022'd);


run;

/* Fit a logistic regression model using our variables */

proc genmod data=master;
    class sex(ref="Male") tobacco(ref="Never") Hypertension(ref='No') group(ref="flu vaccination");
    model reinfectionTEMP_180(event='1') = group age sex meanBMI tobacco hypertension / dist=bin link=logit;
run;
 
/* Export this dataset for Survival Analysis in R */
proc export data=master outfile="../cohort.csv" replace dbms=csv;
run;


/* This creates descriptive statistic tables in .RTF format. I send these to PI in my other projects */
%yamgast(dat=master, grp=reinfection_180,
    vlist=
    age\medR meanSD\
    sex\freq\
    time_to_reinf\medR meanSD\
    BMI\freq\
    meanBMI\medR meanSD\
    tobacco\freq\
    hypertension\freq\,

    pct=col, total=yes, test=yes, ncont=no, missing=no, testlbl=yes,
    style=journal, title=Summary, ps=600, w1=4cm, w2=3cm, w3=3cm,
    file=peter2.rtf);

/*
%yamgast(dat=master, grp=group,
    vlist=
    reinfection_180\freq\
    time_to_reinf\medR meanSD\
    age\medR meanSD\
    sex\freq\
    BMI\freq\
    meanBMI\medR meanSD\
    tobacco\freq\
    hypertension\freq\,

    pct=col, total=yes, test=yes, ncont=no, missing=no, testlbl=yes,
    style=journal, title=Summary, ps=600, w1=4cm, w2=3cm, w3=3cm,
    file=peter.rtf);
    


