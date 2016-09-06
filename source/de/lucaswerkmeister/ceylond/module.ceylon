"A module for writing Ceylon daemons
 that communicate over a system-provided socket.

 Note: On the JVM, this module looks at `IOException` error messages to determine their cause,
 and Java localizes those messages,
 so it’s recommended to run Java with `LC_MESSAGES=C`."
native ("jvm", "js") module de.lucaswerkmeister.ceylond "1.0.0" {
    shared import ceylon.buffer "1.2.2";
    shared import ceylon.logging "1.2.2";
    import ceylon.collection "1.2.2";
    native ("jvm") import java.base "7";
    native ("jvm") import ceylon.interop.java "1.2.2";
}
