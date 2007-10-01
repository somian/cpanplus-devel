BEGIN {
    use FindBin; 
    use File::Spec;
    
    ### paths to our own 'lib' and 'inc' dirs
    ### include them, relative from t/
    my @paths   = map { "$FindBin::Bin/$_" } qw[../lib inc];

    ### absolute'ify the paths in @INC;
    my @rel2abs = map { File::Spec->rel2abs( $_ ) }
                    grep { not File::Spec->file_name_is_absolute( $_ ) } @INC;
    
    ### use require to make devel::cover happy
    require lib;
    for ( @paths, @rel2abs ) { 
        my $l = 'lib'; 
        $l->import( $_ ) 
    }

    use Config;

    ### and add them to the environment, so shellouts get them
    $ENV{'PERL5LIB'} = join ':', 
                        grep { defined } $ENV{'PERL5LIB'}, @paths, @rel2abs;
    
    ### add our own path to the front of $ENV{PATH}, so that cpanp-run-perl
    ### and friends get picked up
    $ENV{'PATH'} = join $Config{'path_sep'}, 
                    grep { defined } "$FindBin::Bin/../bin", $ENV{'PATH'};

    ### Fix up the path to perl, as we're about to chdir
    ### but only under perlcore, or if the path contains delimiters,
    ### meaning it's relative, but not looked up in your $PATH
    $^X = File::Spec->rel2abs( $^X ) 
        if $ENV{PERL_CORE} or ( $^X =~ m|[/\\]| );

    ### chdir to our own test dir, so we know all files are relative 
    ### to this point, no matter whether run from perlcore tests or
    ### regular CPAN installs
    chdir "$FindBin::Bin" if -d "$FindBin::Bin"
}

BEGIN {
    use IPC::Cmd;
   
    ### Win32 has issues with redirecting FD's properly in IPC::Run:
    ### Can't redirect fd #4 on Win32 at IPC/Run.pm line 2801
    $IPC::Cmd::USE_IPC_RUN = 0 if $^O eq 'MSWin32';
    $IPC::Cmd::USE_IPC_RUN = 0 if $^O eq 'MSWin32';
}

use strict;
use CPANPLUS::Configure;
use CPANPLUS::Error ();

use File::Path      qw[rmtree];
use FileHandle;
use File::Basename  qw[basename];

{   ### Force the ignoring of .po files for L::M::S
    $INC{'Locale::Maketext::Lexicon.pm'} = __FILE__;
    $Locale::Maketext::Lexicon::VERSION = 0;
}

my $Env = 'PERL5_CPANPLUS_TEST_VERBOSE';

# prereq has to be in our package file && core!
use constant TEST_CONF_PREREQ           => 'Cwd';   
use constant TEST_CONF_MODULE           => 'Foo::Bar::EU::NOXS';
use constant TEST_CONF_AUTHOR           => 'EUNOXS';
use constant TEST_CONF_INST_MODULE      => 'Foo::Bar';
use constant TEST_CONF_INVALID_MODULE   => 'fnurk';
use constant TEST_CONF_MIRROR_DIR       => 'dummy-localmirror';
use constant TEST_CONF_CPAN_DIR         => 'dummy-CPAN';

### we might need this Some Day when we're installing into
### our own sandbox. see t/20.t for details
# use constant TEST_INSTALL_DIR       => do {
#     my $dir = File::Spec->rel2abs( 'dummy-perl' );
# 
#     ### clean up paths if we are on win32    
#     ### dirs with spaces will be.. bad :(
#     $^O eq 'MSWin32'
#         ? Win32::GetShortPathName( $dir )
#         : $dir;
# };        

# use constant TEST_INSTALL_DIR_LIB 
#     => File::Spec->catdir( TEST_INSTALL_DIR, 'lib' );
# use constant TEST_INSTALL_DIR_BIN 
#     => File::Spec->catdir( TEST_INSTALL_DIR, 'bin' );
# use constant TEST_INSTALL_DIR_MAN1 
#     => File::Spec->catdir( TEST_INSTALL_DIR, 'man', 'man1' );
# use constant TEST_INSTALL_DIR_MAN3
#     => File::Spec->catdir( TEST_INSTALL_DIR, 'man', 'man3' );
# use constant TEST_INSTALL_DIR_ARCH
#     => File::Spec->catdir( TEST_INSTALL_DIR, 'arch' );
# 
# use constant TEST_INSTALL_EU_MM_FLAGS =>
#     ' INSTALLDIRS=site' .
#     ' INSTALLSITELIB='     . TEST_INSTALL_DIR_LIB .
#     ' INSTALLSITEARCH='    . TEST_INSTALL_DIR_ARCH .    # .packlist
#     ' INSTALLARCHLIB='     . TEST_INSTALL_DIR_ARCH .    # perllocal.pod
#     ' INSTALLSITEBIN='     . TEST_INSTALL_DIR_BIN .
#     ' INSTALLSCRIPT='      . TEST_INSTALL_DIR_BIN .
#     ' INSTALLSITEMAN1DIR=' . TEST_INSTALL_DIR_MAN1 .
#     ' INSTALLSITEMAN3DIR=' . TEST_INSTALL_DIR_MAN3;


sub gimme_conf { 

    ### don't load any other configs than the heuristic one
    ### during tests. They might hold broken/incorrect data
    ### for our test suite. Bug [perl #43629] showed this.
    my $conf = CPANPLUS::Configure->new( load_configs => 0 );
    $conf->set_conf( hosts  => [ { 
                        path        => File::Spec->rel2abs(TEST_CONF_CPAN_DIR),
                        scheme      => 'file',
                    } ],      
    );
    $conf->set_conf( base       => 'dummy-cpanplus' );
    $conf->set_conf( dist_type  => '' );
    $conf->set_conf( signature  => 0 );
    $conf->set_conf( verbose    => 1 ) if $ENV{ $Env };
    
    ### never use a pager in the test suite
    $conf->set_program( pager   => '' );

    ### dmq tells us that we should run with /nologo
    ### if using nmake, as it's very noise otherwise.
    {   my $make = $conf->get_program('make');
        if( $make and basename($make) =~ /^nmake/i and
            $make !~ m|/nologo|
        ) {
            $make .= ' /nologo';
            $conf->set_program( make => $make );
        }
    }
    
    _clean_test_dir( [
        $conf->get_conf('base'),     
        TEST_CONF_MIRROR_DIR,
#         TEST_INSTALL_DIR_LIB,
#         TEST_INSTALL_DIR_BIN,
#         TEST_INSTALL_DIR_MAN1, 
#         TEST_INSTALL_DIR_MAN3,
    ], (  $ENV{PERL_CORE} ? 0 : 1 ) );
        
    return $conf;
};

{
    my $fh;
    my $file = ".".basename($0).".output";
    sub output_handle {
        return $fh if $fh;
        
        $fh = FileHandle->new(">$file")
                    or warn "Could not open output file '$file': $!";
       
        $fh->autoflush(1);
        return $fh;
    }
    
    sub output_file { return $file }
    
    
    
    ### redirect output from msg() and error() output to file
    unless( $ENV{$Env} ) {
    
        print "# To run tests in verbose mode, set ".
              "\$ENV{$Env} = 1\n" unless $ENV{PERL_CORE};
    
        1 while unlink $file;   # just in case
    
        $CPANPLUS::Error::ERROR_FH  =
        $CPANPLUS::Error::ERROR_FH  = output_handle();
        
        $CPANPLUS::Error::MSG_FH    =
        $CPANPLUS::Error::MSG_FH    = output_handle();
        
    }        
}


### clean these files if we're under perl core
END { 
    if ( $ENV{PERL_CORE} ) {
        close output_handle(); 1 while unlink output_file();

        _clean_test_dir( [
            gimme_conf->get_conf('base'),   
            TEST_CONF_MIRROR_DIR,
    #         TEST_INSTALL_DIR_LIB,
    #         TEST_INSTALL_DIR_BIN,
    #         TEST_INSTALL_DIR_MAN1, 
    #         TEST_INSTALL_DIR_MAN3,
        ], 0 ); # DO NOT be verbose under perl core -- makes tests fail
    }
}



### whenever we start a new script, we want to clean out our
### old files from the test '.cpanplus' dir..
sub _clean_test_dir {
    my $dirs    = shift || [];
    my $verbose = shift || 0;

    for my $dir ( @$dirs ) {

        ### no point if it doesn't exist;
        next unless -d $dir;

        my $dh;
        opendir $dh, $dir or die "Could not open basedir '$dir': $!";
        while( my $file = readdir $dh ) { 
            next if $file =~ /^\./;  # skip dot files
            
            my $path = File::Spec->catfile( $dir, $file );
            
            ### directory, rmtree it
            if( -d $path ) {
                print "# Deleting directory '$path'\n" if $verbose;
                eval { rmtree( $path ) };
                warn "Could not delete '$path' while cleaning up '$dir'" if $@;
           
            ### regular file
            } else {
                print "# Deleting file '$path'\n" if $verbose;
                1 while unlink $path;
            }            
        }       
    
        close $dh;
    }
    
    return 1;
}
1;
