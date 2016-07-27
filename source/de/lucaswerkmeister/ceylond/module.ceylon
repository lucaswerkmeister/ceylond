"A module for writing Ceylon daemons
 that communicate over a system-provided socket."
native ("jvm", "js") module de.lucaswerkmeister.ceylond "1.0.0" {
    shared import ceylon.buffer "1.2.2";
    native ("jvm") import java.base "7";
    native ("jvm") import ceylon.interop.java "1.2.2";
}
