use FindBin;
use lib $FindBin::Bin.'/../3rd/lib/perl5';
use lib $FindBin::Bin.'/../lib';
use lib $FindBin::Bin.'/../example/lib';
use Mojo::File 'curfile';
use Test::More;
use Test::Mojo;

use Mojo::Util qw(dumper);
use Mojo::SOAP::Client;

my $t = Test::Mojo->new(
    curfile->dirname->child('../example/exsoaple.pl'));


my $sc = Mojo::SOAP::Client->new(
    log => $t->app->log,
    wsdl => curfile->dirname->child('../example/nameservice.wsdl'),
    xsds => [
        curfile->dirname->child('../example/nameservice.xsd')
    ],
    endPoint => '/SOAP'
);
use Data::Dumper;

my $in;
my $err;

$sc->call_p('getCountries')->then(sub {
    $in = shift;
})->wait;

is_deeply $in, {
    'parameters' => {
        'country' => [
            'Switzerland',
            'Germany'
        ]
    }
};

$in = undef;
$sc->call_p('getNamesInCountry',{
    country => 'Switzerland'
})->then(sub {
    $in = shift;
})->wait; 
is_deeply $in, {
    'parameters' => {
        'name' => [
            qw(A B C),'Switzerland'
        ]
    }
};

eval { 
    $sc->call('getNamesInCountry',{
        country => 'Lock'
    });
};

like $@->message, qr{^/SOAP - 401 Unauthorized};

done_testing;