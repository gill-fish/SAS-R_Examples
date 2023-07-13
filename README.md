# SAS-R_Examples
A compilation of personal code samples from the SAS and R programming language. 

Data used in these analyses are pulled from the TriNetX database. This information comes as de-indentified patient information
where multiple .csv files with different information must be combined and manipulated. 

*forest.sas* - Project code which creates a logistic regression macro, extracts the OR & 95% CI from all 30 variables against the outcome, and builds a forest plot. This uses
               proc logistic, proc sgplot, and SAS macros. 

*forest.png* - Forest plot generated from forest.sas

*Covid_project.sas* - a SAS data analysis example from an in-class, roleplay project. The question of
                    interest and rationale for analysis steps are featured as comments in this file.
                    The end of this file also shows extraction of descriptive statistics and regression
                    fitting.
                    
*diagnosis_match.sas* - A SAS data analysis example with a focus on writing macros to generate datasets. This
                      code was used in the Sickle Cell Disease research project that I do data analysis for.
                      
*Multiple_Regression_AssignmentEX.pdf* - This is an assignemnt I completed in a statistical models class this semester which
                                       focuses on multiple regression. This assignemnt highlights model diagnostics, box-cox
                                       transformations, and stepwise variable selection.
                                       This file is a pdf generated from R Markdown (.rmd).
