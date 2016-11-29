"A module for writing Ceylon daemons
 that communicate over a system-provided socket.

 Backend-specific limitations:

 - On the JVM, this module looks at `IOException` error messages to determine their cause.
   Java localizes those messages, so it’s recommended to run Java with `LC_MESSAGES=C`.
 - On Node.js, connections to non-concurrent servers
   that are attempted while the server is handling another connection
   are not accepted once the server becomes ready again –
   only connections that are newly made when the server is free succeed."
native ("jvm", "js") module de.lucaswerkmeister.ceylond.core "1.0.0" {
    shared import ceylon.buffer "1.3.1";
    shared import ceylon.logging "1.3.1";
    import ceylon.collection "1.3.1";
    native ("jvm") import java.base "7";
    native ("jvm") import ceylon.interop.java "1.3.1";
}
