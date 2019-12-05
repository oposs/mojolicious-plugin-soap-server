Mojo-SOAP
=========

A Mojo wrapper for XML::Compile::SOAP providing a SOAP Client and a SOAP Server.

The SOAP Client is written in a non-blocking fashion. Returning a promise when called.

See the code in the example directory for inspiration on how to use this package.

TODO
----

* pod documentation for client and server modules
* handle server methods returning a promise so that the server part also can become non-blocking.