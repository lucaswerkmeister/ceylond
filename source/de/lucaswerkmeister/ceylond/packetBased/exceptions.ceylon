"An error in the packet protocol itself.
 Exceptions of this kind are fatal and result in immediate connection termination.
 They are not sent to the application’s exception handler."
shared abstract class PacketProtocolException(String message)
        of MaximumLengthExceededException | UnknownTypeException
        extends Exception(message) {}

"The length specified in the packet header exceeds the maximum length defined by the application."
shared sealed class MaximumLengthExceededException(
    "The configured maximum length."
    shared Integer maximumLength,
    "The actual received length."
    shared Integer actualLength)
        extends PacketProtocolException("Received length ``actualLength`` exceeds maximum packet length ``maximumLength``") {}

"The type specified in the packet header is unknown to the application."
shared sealed class UnknownTypeException(
    "The received type."
    shared Integer type,
    "The size of a type in bytes (needed for error message formatting)."
    shared Integer typeSize,
    "All types known to the system (currently unused)."
    shared Category<Integer> knownTypes)
        extends PacketProtocolException("Unknown packet type ``type`` (0x``formatInteger(type, 16).padLeading(2 * typeSize, '0')``)") {}
