use Test::More tests => 3;
BEGIN { use_ok('Flickr::Simple') };

#this key/secret is for use specifically with the test suite
my $apikey = 'f50971bbae967490c573467d2d8eb4c4';
my $apisecret = 'eac50bd2591c09c0';

my $authobj = Flickr::Simple::Auth->new(
	{
		apikey          => $apikey,
		apisecret       => $apisecret,
	}
);

ok($authobj);
#$authobj->_test;
ok(!$authobj->error);
