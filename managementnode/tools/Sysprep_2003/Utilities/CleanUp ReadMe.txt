

CleanUp [Version 1.41]


 Cleans temporary files out of the %TEMP% directory.

 Temporary files include the following patterns:
 *.tmp;  ~*.*;  _*.*;  *.~*;  *._*;  gl*.exe;  mse0*.*; ol*.tmp.html;
 msohtml*.*; vbe; frontpagetempdir; exchangeperflog_*.dat; vpmectmp;
 twain.log; tw*.mtx


 Syntax: CleanUp.exe [/Y] [/O] [/A] [/P:folder] [/Q]

 /Y suppresses the 'Are you sure?' prompt.
 /O deletes only old files (recommended). Any files that have been created,
    modified or accessed on the same day will be skipped.
 /A deletes all files, not just temporary files (Use caution!).
 /P allows you to clean out a folder other than %TEMP%.
   (When used with /A the %WINDIR%, System32 and root folders are not allowed.)
 /Q suppresses all output, including errors.

 /? or -? displays this syntax and always returns 1.
  A successful completion returns 0.


Copyright 1999-2003 Marty List, www.OptimumX.com


==================================================================


Revision History:
	1.41	12/31/2003
	Changed /o behavior to ignore the accessed date on folders.

	1.40	12/21/2003
	Added additional temporary file patterns.

	1.30	10/09/2002
	Added additional temporary file patterns.

	1.20	03/12/2001
	Modified /O switch to check the created, modified and accessed dates.

	1.10	07/05/2000
	Added support for the /O switch to delete only old files.

	1.00 	12/12/2000
	Initial release.
