This is a script package written by the Metskas Lab at Purdue University.  It requires a Matlab license to run, though users are welcome to convert code to Julia under share-and-share-alike guidelines.

Inputs: Dynamo-formatted table from a subtomogram averaging project (may be converted from Relion starfiles or other formats using available online tools).
Outputs: Matlab object file with information on carboxysomes; Dynamo-formatted particle tables; csv file with information on each particle's behavior; various plots and graphics according to user choices.

To run: simply run the main.m script in Matlab.  Users will be guided through selections and choices.

**Installation**

The script package is adapted from a precursor collection of ObservableHQ (JavaScript) modules that were translated to MATLAB and then further developed. The new MATLAB script package is currently being hosted online in GitHub for version control. To compile from the source using git, follow the steps outlined below: 
		1. git clone  https://github.com/LAMetskas/2025_polymerizationAnalysis.git 
		2. cd MetskasLab 
		3. matlab 
		4. In MATLAB command window: run <DYNAMO_ROOT>/dynamo_activate.m 
		5. Run scripts using the command window 



**Disclaimers and licenses**

Users agree to use the script package as is; we to not guarantee assistance, user support, or updates as new software versions are introducted.

https://github.com/LAMetskas/2025_polymerizationAnalysis/  This package is provided under Creative Commons copyright license Attribution-NonCommercial-ShareAlike 4.0 International (https://creativecommons.org/licenses/by-nc-sa/4.0/). 

This copyright license allows use for noncommercial use only, with attribution to the original package and sharing of all changes under the same license as the original.  We do not permit use of the code for AI training purposes unless the final AI model/tool will be provided under the same open-access copyright license, without any restrictions including logins or paywall.
