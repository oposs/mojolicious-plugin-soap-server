package Mojolicious::Plugin::SOAP::Server;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use XML::Compile::WSDL11;
use XML::Compile::SOAP11;
use XML::Compile::SOAP12;
use XML::Compile::SOAP::Daemon::CGI;
use Mojo::Util qw(dumper);
our $VERSION = '0.1.0';
use Carp qw(carp croak);

has wsdl => sub ($self) {
    XML::Compile::WSDL11->new;
};

has daemon => sub ($self) {
   XML::Compile::SOAP::Daemon::CGI->new; 
};

# do not depend on LWP
use constant { 
    RC_OK                 => 200,
    RC_METHOD_NOT_ALLOWED => 405,
    RC_NOT_ACCEPTABLE     => 406,
};

sub register ($self,$app,$conf={}) {
    my $log = $app->log;
    my $wsdl = XML::Compile::WSDL11->new($conf->{wsdl});
    $wsdl->importDefinitions(
        $conf->{xsds} 
    ) if $conf->{xsds};

    my $controller = $conf->{controller};
    for my $op ($wsdl->operations()){
        my $code;
        my $method = $op->name;
        if ($controller->can($method)){
            $app->log->debug(__PACKAGE__ . " Register handler for $method");
            $code = $op->compileHandler(
                callback => sub {
                    my ($ctrl,$param,$c) = @_;
                    my $ret = eval {
                        local $ENV{__DIE__};
                        $controller->$method(@_);
                    };
                    if ($@) {
                        if (ref $@ eq 'HASH') {
                            $c->log->error("$method - $@->{status} $@->{text}");
                            return {
                                _RETURN_CODE => $@->{status},
                                _RETURN_TEXT => $@->{text},
                            }
                        }
                        $log->error("$method - $@");
                        return {
                            _RETURN_CODE => 500,
                            _RETURN_TEXT => 'Internal Error'
                        }
                    }
                    return $ret;
                }
            );
        }
        else {
            $app->log->debug(__PACKAGE__ . " Adding stub handler $method");
            $code = $op->compileHandler(
                callback => $conf->{default_cb} || sub {
                    warn "No handler for $method";
                    return {
                        _RETURN_CODE => 404,
                        _RETURN_TEXT => 'No handler found',
                    };
                }
            );
        }
        $self->daemon->addHandler($op->name,$op,$code);
    }
    my $r = $app->routes;
    $app->types->type(
        soapxml => 'text/xml; charset="utf-8"'
    );
    $r->any($conf->{endPoint}.'/*catchall' => { catchall => '' })
    ->to(cb => sub ($c) {
        if ( $c->req->method !~ /^(M-)?POST$/ ) {
            return $c->render(
                status => RC_METHOD_NOT_ALLOWED . " Expected POST",
                text => 'SOAP wants you to POST!'
            );
        }
        my $format = 'txt';
        my $body = $c->req->body;
        my ($rc,$msg,$xml) = $self->daemon->process(
            \$body,
            $c,
            $c->req->headers->header('soapaction')
        );
        my $bytes = $xml;
        my $err;
        if(UNIVERSAL::isa($bytes, 'XML::LibXML::Document')) {
            $bytes = $bytes->toString($rc == RC_OK ? 0 : 1);
            $format = 'soapxml';
        }
        else {
            $err = $bytes;
        }
        if (not $bytes) {
            $bytes = "[$rc] $err";
        }
    
        $c->render(
            status => $rc,
            format => $format,
            data => $bytes,
        );
    });
}

1;
=head1 NAME

Mojolicious::Plugin::SOAPServer

=head1 