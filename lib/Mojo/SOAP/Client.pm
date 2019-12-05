package Mojo::SOAP::Client;

use Mojo::Base -base, -signatures;

use Mojo::Promise;
use XML::Compile::WSDL11;      # use WSDL version 1.1
use XML::Compile::SOAP11;      # use SOAP version 1.1
use XML::Compile::SOAP12;
use XML::Compile::Transport::SOAPHTTP_MojoUA;
use HTTP::Headers;
use File::Basename qw(dirname);
use Mojo::Util qw(b64_encode dumper);
use Mojo::Log;
use Carp;


has log => sub ($self) {
    Mojo::Log->new;
};

has request_timeout => 5;

has insecure => 0;

has 'wsdl' => sub ($self) {
    croak "path to wsdl spec file must be provided in wsdl property";
};

has 'xsds' => sub ($self) {
    [];
};

has 'port';

has 'endPoint' => sub ($self) {
    $self->wsdlCompiler->endPoint(
        $self->port ? ( port => $self->port) : ()
    );
};

has 'ca';
has 'cert';
has 'key';

has wsdlCompiler => sub ($self) {
    my $wc = XML::Compile::WSDL11->new($self->wsdl);
    for my $xsd ( @{$self->xsds}) {
        $wc->importDefinitions($xsd)
    }
    return $wc;
};

has httpUa => sub ($self) {
    XML::Compile::Transport::SOAPHTTP_MojoUA->new(
        address => $self->endPoint,
        ua_start_callback => sub ($ua,$tx) {
            $ua->ca($self->ca)
                if $self->ca;
            $ua->cert($self->cert)
                if $self->cert;
            $ua->key($self->key)
                if $self->key;
            $ua->request_timeout($self->request_timeout)
                if $self->request_timeout;
            $ua->insecure($self->insecure)
                if $self->insecure;
        },
    );
};

has uaProperties => sub ($self) {
    {
#       header => HTTP::Headers->new(
#           Authorization => 'Basic '. b64_encode("$user:$password","")
#       )
    }
};

has transport => sub ($self) {
    $self->httpUa->compileClient(
        %{$self->uaProperties}
    );
};

has clients => sub ($self) {
    return {};
};

=head2 call_p($operation,$params)

 my $pro = $nevis->call_p('queryUsers',{
    query => {
        detailLevels => {
            credentialDetailLevel => 'LOW',
            userDetailLevel => 'MEDIUM',
            userDetailLevel => 'LOW',
            defaultDetailLevel => 'EXCLUDE'
        },
        user => {
            loginId => 'aakeret'
        }
        numRecords => 100,
        skipRecords => 0,
    }
 });

 $pro->then(sub ($resp) {
     print Dumper $resp
 });

=cut

sub call_p ($self,$operation,$params={}) {
    my $clients = $self->clients;
    my $call = $clients->{$operation} //= $self->wsdlCompiler->compileClient(
        operation => $operation,
        transport => $self->transport,
        async => 1,
    );
    $self->log->debug(__PACKAGE__ . " $operation called");
    return Mojo::Promise->new(sub ($resolve,$reject) {
        $call->(
            %$params,
            _callback => sub ($answer,$trace,@rest) {
                my $res = $trace->response;
                my $client_warning =
                    $res->headers->header('client-warning');
                return $reject->($client_warning)
                    if $client_warning;
                if (not $res->is_success) {
                    if (my $f = $answer->{Fault}){
                        $self->log->error(__PACKAGE__ . " $operation - ".$f->{_NAME} .": ". $f->{faultstring});
                        return $reject->($f->{faultstring});
                    }
                    return $reject->($self->endPoint.' - '.$res->code.' '.$res->message)
                }
                # $self->log->debug(__PACKAGE__ . " $operation completed - ".dumper($answer));
                return $resolve->($answer,$trace);
            }
        );
    });
}

sub call ($self,$operation,$params) {
    my ($ret,$err);
    $self->call_p($operation,$params)
        ->then(sub { $ret = shift })
        ->catch(sub { $err = shift })
        ->wait;
    Mojo::SOAP::Exception->throw($err) if $err;
    return $ret;
}

package Mojo::SOAP::Exception {
  use Mojo::Base 'Mojo::Exception';
}

1;
