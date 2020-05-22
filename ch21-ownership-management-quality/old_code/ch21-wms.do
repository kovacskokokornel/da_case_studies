********************************************************************************
* Chapter 21
*
* founder/family ownsership
* wms-management
*
* v2.0. 2020-01-24
* v2.1. 2020-02-17, cleaning code
**********************************************************************


* set the path
*cd "C:\Users\GB\Dropbox (MTA KRTK)\bekes_kezdi_textbook"
*cd "D:\Dropbox (MTA KRTK)\bekes_kezdi_textbook\"
cd "C:\Users\kezdi\Dropbox\bekes_kezdi_textbook\"


*location folders
global data_in   "da_data_repo/wms-management-survey/clean"
global data_out  "da_case_studies/ch21-ownership-management-quality"
global output   "$data_out/output"



***************************************************************
*
* PART I
*
* Data prep
***************************************************************


clear
set matsize 4000
use "$data_in\wms_da_textbook.dta"

* count original data 
count
* 14,277

* create xsec
sort firmid wave
bys firmid: gen latest=_n==_N
keep if latest==1
drop latest
count 
* 10,282



* Ownership: defone founder/family owned 
*  and drop ownership that's missing or not relevant
codebook ownership
tab ownership,mis

gen foundfam_owned = ownership=="Family owned, external CEO" ///
 | ownership=="Family owned, family CEO" ///
 | ownership=="Founder owned, CEO unknown" ///
 | ownership=="Founder owned, external CEO" ///
 | ownership=="Founder owned, family CEO" ///
 | ownership=="Founder owned, founder CEO" 




* proportion with college degree
* need correction: -44 means do not know, -99 means missing
replace degree_nm=. if degree_nm<0 
replace degree_m=. if degree_m<0 

replace degree_m = degree_m/100
 lab var degree_m "Proportion of managers with a college degree"
replace degree_nm = degree_nm/100
 lab var degree_nm "Proportion of non-managers with a college degree"
* bins from degree_nm
tabstat degree_nm, s(min p10 p25 p50 p75 p90 max)
tabstat degree_nm if degree_nm>0, s(min p10 p25 p50 p75 p90 max)

egen degree_nm_bins = cut(degree_nm), at(0,0.001,0.05,0.20,1.01)
tabstat degree_nm, by(degree_nm_bins) s(min max n)



* log employment
gen lnemp=ln(emp)
*lpoly management lnemp, nosca ci ylab(,grid) xlab(,grid)

* competition 
rename competition competition_string
encode competition_string, gen(competition)
 recode competition 1=2
 lab def competition 2 "0-4 competitors", modify
gen compet_weak  = competition==2
gen compet_moder  = competition==3
gen compet_strong = competition==4

tabstat compet_*, by(competition) 

* industry in 2 digits
gen industry=sic
lab def sic2 20 food 21 tobacco 22 textile 23 apparel 24 lumber 25 furniture ///
 26 paper 27 printing 28 chemical 29 petrol 30 rubber 31 leather 32 glass ///
 33 primary_metal 34 fabricated_metal 35 ind_machinery 36 electronic ///
 37 transport 38 instrument 39 misc_manuf
lab val industry sic2

* country numeric variable
encode cty, gen(countrycode)



**********************************************************
***** SAMPLE SELECTION

drop if ownership==""
drop if ownership == "Employees/COOP" ///
 | ownership == "Foundation/Research Institute" ///
 | ownership == "Government" ///
 | ownership == "Other" 
 
* keep observations with non-missing variables
foreach v of varlist management foundfam  ///
 degree_nm compet_moder compet_strong industry countrycode lnemp {
	drop if `v'==.
}

* drop tiny and large firms
tabstat emp, s(min p1 p50 p99 max n)
count if emp<50
drop if emp<50 
count if emp>5000
drop if emp>5000

count
* 8,440


*************************************************************
* VARIATION IN X, DISTRUBUTION OF OTHER VARIABLES


tab foundfam,mis

tab competition, sum(foundfam)
tab degree_nm_bins
tab country, sum(foundfam)
tab industry, sum(foundfam)

* look at data for modelling
hist emp, percent ylab(, grid)
hist lnemp, width(0.3) percent ylab(, grid)
hist degree_nm, width(0.05) percent ylab(, grid)

lpoly management degree_nm, nosca ci xlab(, grid) ylab(, grid)
lpoly management lnemp, nosca ci xlab(, grid) ylab(, grid)

gen degree_nm_sq= degree_nm^2

*age 
gen age_young=firmage<30
gen age_old=firmage>80 & firmage<.
gen age_unknown=firmage==.

sum management foundfam
sum industry countrycode degree_nm* compet_moder compet_strong age_*

sum management
sum foundfam
tab foundfam, sum(management)



* save workfile for matching and regression
save "$data_out/work.dta",replace


***************************************************************
* PART II
* Analysis: regression and matching
***************************************************************

*************************************************************
* REGRESSIONS
*************************************************************

use "$data_out/work.dta" ,clear

sum industry country degree_nm degree_nm_sq compet_moder compet_strong ///
 age_young age_old age_unknown lnemp 

* y on x
reg management foundfam_own , robust
 outreg2 using "$output/ch21-foundfam-reg1", 2aster dec(2) symbol(**, *) ///
 ctitle("no confounders") tex(frag) nonotes replace


* y on x and all confounders
reg management foundfam ///
 i.industry i.countrycode ///
 degree_nm degree_nm_sq compet_moder compet_strong ///
 age_young age_old age_unknown lnemp ///
 , robust
 outreg2 using "$output/ch21-foundfam-reg1", 2aster dec(2) symbol(**, *) ///
 keep(foundfam) ctitle("with confounders") tex(frag) nonotes append

* y on x and all confounders interacted with industry and country
reg management foundfam ///
 i.industry##i.countrycode ///
 i.industry##c.degree_nm i.industry##c.degree_nm_sq i.industry##i.compet_moder i.industry##i.compet_strong ///
 i.industry##i.age_young i.industry##i.age_old i.industry##i.age_unknown i.industry##c.lnemp ///
 i.countrycode##c.degree_nm i.countrycode##c.degree_nm_sq i.countrycode##i.compet_moder i.countrycode##i.compet_strong ///
 i.countrycode##i.age_young i.countrycode##i.age_old i.countrycode##i.age_unknown i.countrycode##c.lnemp ///
 , robust
 outreg2 using "$output/ch21-foundfam-reg1", 2aster dec(2) symbol(**, *) ///
 keep(foundfam) ctitle("with confounders interacted") tex(frag) nonotes append


 
*************************************************************
* EXACT MATCHING
***************************************************************** 

use "$data_out/work.dta" ,clear
count
egen empbin5=cut(emp_firm), group(5)
 tabstat emp_firm, by(empbin) s(min max n)
gen n=1
gen n1 = foundfam
gen n0 =1-foundfam
gen age_mid = age_young==0 & age_old==0 & age_unknown==0
gen agecat = age_young + 2*age_mid + 3*age_old + 4*age_unknown
tabstat firmage, by(agecat) s(min max n)

sum management
tab foundfam

gen y0 = management if foundfam==0
gen y1 = management if foundfam==1

collapse (sum) n n0 n1 (mean) y0 y1 , ///
 by(degree_nm_bins agecat competition empbin industry countrycode)
 
* # theoretical combinations
dis 4*4*3*5*20*24

* # combinations in the data
count

* # firms with no exact match
tabstat n if n0==0 | n1==0, s(sum)

* # firms with exact match
tabstat n if n0>=1 & n1>=1, s(sum)

* examples with founder/family only
* random order just for the examples
set seed 12345
tempvar sortorder
gen `sortorder' = runiform()
sort `sortorder'
lis industry countrycode degree competition agecat empbin n1 n0 if n1==1 & n0==0 & _n<20

* examples with other only: 
lis industry countrycode degree competition agecat empbin n1 n0 if n1==0 & n0==1 & _n<20

* examples of similar firms unmatched
sort countrycode industry degree competition agecat empbin n
lis industry countrycode degree competition agecat empbin n1 n0 ///
 if countrycode==2 & industry==20 & n==1 & _n<340

gen d=y1-y0

* ATE
sum d [w=n]
* ATET
sum d [w=n1]


 
***************************************************************** 
* Matching on the propensity score 
***************************************************************** 

* SOLUTION With replacement

use "$data_out/work.dta" ,clear

psmatch2  foundfam ///
 i.industry i.countrycode ///
 degree_nm degree_nm_sq compet_moder compet_strong ///
 age_young age_old age_unknown lnemp ///
 , out(management) ate
 

psmatch2  foundfam ///
 i.industry##i.countrycode ///
 i.industry##c.degree_nm i.industry##c.degree_nm_sq i.industry##i.compet_moder i.industry##i.compet_strong ///
 i.industry##i.age_young i.industry##i.age_old i.industry##i.age_unknown i.industry##c.lnemp ///
 i.countrycode##c.degree_nm i.countrycode##c.degree_nm_sq i.countrycode##i.compet_moder i.countrycode##i.compet_strong ///
 i.countrycode##i.age_young i.countrycode##i.age_old i.countrycode##i.age_unknown i.countrycode##c.lnemp ///
 , out(management) ate
 
 

***************************************************************** 
* CHECK common support
***************************************************************** 
use "$data_out/Ch21_wms_workfile_xsec.dta" ,clear


qui tab industry, gen(i)
qui tab cty, gen(c)

tabstat compet_mod compet_str i1-i20 c1-c21, by(foundfam)
tabstat degree_nm, by(foundfam) s(min p1 p5 p95 p99 max n) 
tabstat emp, by(foundfam) s(min p1 p5 p95 p99 max n)
* common support check passed








