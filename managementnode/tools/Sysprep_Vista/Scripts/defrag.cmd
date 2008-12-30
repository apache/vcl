rem Defragments the hard drive
rem -w            Performs full defragmentation. Attempts to consolidate all file
rem               fragments, regardless of their size.
rem -v            Specifies verbose mode. The defragmentation and analysis output
rem               is more detailed.

"%SystemRoot%\system32\Defrag.exe" %SystemDrive% -w -v