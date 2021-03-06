use 5.020001;

use strict;
use warnings;
use ExtUtils::MakeMaker;
use FindBin;
use Data::Dumper;
use lib "$FindBin::RealBin/3rd/lib/perl5";

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::SOAP::Server',
  VERSION_FROM => 'lib/Mojolicious/Plugin/SOAP/Server.pm',
  ABSTRACT     => 'Hook a SOAP Server into your regular mojolicious server',
  AUTHOR       => 'Tobias Oetiker <tobi@oetiker.ch>',
  LICENSE      => 'artistic_2',
  PREREQ_PM    =>  {
    'XML::Compile::SOAP::Daemon' => '3.14',
    'XML::Compile::SOAP' => '3.26',
    'XML::Compile::SOAP12' => '3.06',
    'Mojolicious' => '8.26',
    'CGI' => 0,
  },
  TEST_REQUIRES => { 
    'Mojo::SOAP::Client' => 0.1.8,
  },
  BUILD_REQUIRES => {
    'CPAN::Uploader' => 0,
    'Pod::Markdown::Github' => 0,
  },
  META_MERGE   => {
    requires  => {perl => '5.020001'},
    resources => {
      license     => 'http://www.opensource.org/licenses/artistic-license-2.0',
      repository  => 'https://github.com/oposs/mojolicious-plugin-soap-server',
      bugtracker  => 'https://github.com/oposs/mojolicious-plugin-soap-server/issues'
    },
    no_index => {directory => ['t','eg']}
  },
  test => {TESTS => 't/*.t'}
);

sub MY::postamble {
   my $self = shift;
   my %r = (%{ $self->{PREREQ_PM} || {} }, %{ $self->{BUILD_REQUIRES} || {} }, %{ $self->{TEST_REQUIRES} || {} } );
   my $modules = join " ", grep !/^perl\@/, map { $r{$_} ? $_ .'@'. $r{$_} : $_ } keys %r;
   my $tpd = "$FindBin::RealBin/3rd";
   warn "** call 'make 3rd' to build missing dependencies ...\n";
   return <<"EOF";

all:: README.md README

README.md: $self->{VERSION_FROM}
	\$(PERL) -I$tpd/lib/perl5 -MPod::Markdown::Github -e "binmode(STDOUT, q(:utf8));Pod::Markdown::Github->new->filter(q($self->{VERSION_FROM}))" > README.md

README: README.md
	cp README.md README

CHANGES: $self->{VERSION_FROM} Makefile
	echo $self->{VERSION} `date +"%Y-%m-%d %H:%M:%S %z"` `git config user.name` '<'`git config user.email`'>' >> CHANGES.new
	\@echo >> CHANGES.new
	\@echo ' -' >> CHANGES.new
	\@echo >> CHANGES.new
	\@cat CHANGES >> CHANGES.new && mv CHANGES.new CHANGES
	\@\$\$EDITOR CHANGES


3rd: $tpd/touch
	mkdir -p $tpd

$tpd/touch: Makefile
	\$(NOECHO) \$(ECHO) "*** INSTALLING MISSING BITS FOR TESTING ***"
	curl -L http://cpanmin.us | env PERL_CPANM_HOME=$tpd \$(PERL) - -q --notest --local-lib-contained $tpd $modules && touch $tpd/touch
EOF
}
