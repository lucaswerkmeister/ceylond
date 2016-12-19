"An error in the packet protocol itself.
 Exceptions of this kind are fatal and result in immediate connection termination.
 They are not sent to the application’s exception handler."
shared abstract class PacketProtocolException(String message)
        of MaximumLengthExceededException | UnknownTypeException
        extends Exception(message) {}

"The length specified in the packet header exceeds the maximum length defined by the application."
shared sealed class MaximumLengthExceededException(shared Integer maximumLength, shared Integer actualLength)
        extends PacketProtocolException("Received length ``actualLength`` exceeds maximum packet length ``maximumLength``") {}

"The type specified in the packet header is unknown to the application."
shared sealed class UnknownTypeException(shared Integer type, shared Integer typeSize, shared Category<Integer> knownTypes)
        extends PacketProtocolException("Unknown packet type ``type`` (0x``formatInteger(type, 16).padLeading(2 * typeSize, '0')``)") {}
