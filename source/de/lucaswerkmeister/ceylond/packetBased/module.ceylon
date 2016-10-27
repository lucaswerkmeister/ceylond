"""A convenience wrapper around `de.lucaswerkmeister.ceylond.core` for packet-based daemons.
   A *package* consists of a *length*, a *type*, and the content (*length* bytes).
   The number of bytes in the length and type is specified by the user of this module;
   the type may be size zero to disable it completely."""
native ("jvm", "js") module de.lucaswerkmeister.ceylond.packetBased "1.0.0" {
    shared import de.lucaswerkmeister.ceylond.core "1.0.0";
}
