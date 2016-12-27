"""A convenience wrapper around `de.lucaswerkmeister.ceylond.core` for packet-based daemons.
   Packets are a useful abstraction on top of the `core` module,
   since the socket itself does not necessarily preserve boundaries between writes or reads:
   especially on internet-based sockets, transmissions may be fragmented and/or grouped together.
   This module takes care of that:
   a *packet* consists of a *length*, a *type*, and the content (*length* bytes),
   and is always delivered to the *packet handler* (registered as a [[map from type to handler|TypeMap]])
   as a single unit.
   The number of bytes in the length and type is specified by the user of this module;
   the type may be size zero to disable it completely.

   See [[startPacketBased]] for a usage example and [[makePacketBasedInstance]] and its parameters for details."""
native ("jvm", "js") module de.lucaswerkmeister.ceylond.packetBased "1.0.0" {
    shared import de.lucaswerkmeister.ceylond.core "1.0.0";
}
