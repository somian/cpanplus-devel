# CPANPLUS - README for somian's GitHub REPOSITORY

## REASON

Add / Change functionality of Cpanplus so that on Cygwin and on M$Whyyn it will do more of what I want.

## GOALS

+ Solve problem of Error Loading SQLite on Cygwin (see below).

+ Refine the APPDATA - PERL5_CPANPLUS_HOME handling.

+ Add XDG-guideline configuration for config, data and cache.

+ Customize the creation of build reports.

### The SQLite / Module::Load problem


	[ERROR] [Sat Feb  2 06:02:33 2013] Could not load source engine 'CPANPLUS::Internals::Source::SQLite'
	[MSG] [Sat Feb  2 06:02:33 2013] Falling back to CPANPLUS::Internals::Source::Memory

After the initial `s reconfigure` following fresh installation of CPANPLUS, this always happens.

	Compilation failed in require at /usr/lib/perl5/5.14/Module/Load.pm line 27.

The full dying message is:

	Can't locate DBI.pm in @INC (@INC contains:
	/opt/usr/lib/perl5/5.14/i686-cygwin-threads-64int
	/usr/local/lib/perl5
	/home/somian/.config/Perl5/CygwinPerl/lib
	/usr/lib/perl5/site_perl/5.14/i686-cygwin-threads-64int
	/usr/lib/perl5/site_perl/5.14
	/usr/lib/perl5/vendor_perl/5.14/i686-cygwin-threads-64int
	/usr/lib/perl5/vendor_perl/5.14
	/usr/lib/perl5/5.14/i686-cygwin-threads-64int
	/usr/lib/perl5/5.14
	/usr/lib/perl5/site_perl/5.10
	/usr/lib/perl5/vendor_perl/5.10
	/usr/lib/perl5/site_perl/5.8
	/home/somian/.cpanplus/lib)
	   at /usr/lib/perl5/site_perl/5.10/DBIx/Simple.pm line 3.

-------------------------------------

Last modified: 2013-02-02T19:58:32 UTC+00:00
