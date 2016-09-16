"A module for writing Ceylon daemons
 that communicate over a system-provided socket.

 Backend-specific limitations:

 - On the JVM, this module looks at `IOException` error messages to determine their cause.
   Java localizes those messages, so it’s recommended to run Java with `LC_MESSAGES=C`.
 - On the JVM, reading from a closed socket is not supported.
   Once the other side closes their end of the socket,
   a [[SocketClosedException]] will occur,
   even if some data is still pending to be read.
 - On Node.js, connections to non-concurrent servers
   that are attempted while the server is handling another connection
   are not accepted once the server becomes ready again –
   only connections that are newly made when the server is free succeed."
native ("jvm", "js") module de.lucaswerkmeister.ceylond "1.0.0" {
    shared import ceylon.buffer "1.2.2";
    shared import ceylon.logging "1.2.2";
    import ceylon.collection "1.2.2";
    native ("jvm") import java.base "7";
    native ("jvm") import ceylon.interop.java "1.2.2";
}
