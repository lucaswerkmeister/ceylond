"""A convenience wrapper around `de.lucaswerkmeister.ceylond.core` for record-based daemons.
   A *record* is considered to be a string, encoded in some fashion (usually UTF-8),
   terminated by a *record separator* (also a string).
   For example, the record separator might be `"\n"`, in which case a record is a line;
   it might also be `"::"`, in which case the socket message `a::b::c::` is interpreted
   as the three records `a`, `b`, and `c`."""
native ("jvm", "js") module de.lucaswerkmeister.ceylond.recordBased "1.0.0" {
    shared import de.lucaswerkmeister.ceylond.core "1.0.0";
}
