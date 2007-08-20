use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Flickr::Simple',
    VERSION_FROM      => 'lib/Flickr/Simple.pm', # finds $VERSION
    PREREQ_PM         => {
    				'Log::Agent' => 0.307,
				'Flickr::API' => 0.08,
				'Storable' => 2.15,
			}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Flickr/Simple.pm', # retrieve abstract from module
       AUTHOR         => 'Rev. Jeffrey Paul <sneak@datavibe.net>') : ()),
);
