shared abstract class MessageProtocolException(String message, Exception? cause = null) extends Exception(message, cause) {}

shared sealed class NonAsciiHeaderCharacterException(Integer codepoint)
extends MessageProtocolException("Header character '``codepoint.character``' (``codepoint``, #``formatInteger { codepoint; radix = 16; }.padLeading { size = 2; character = '0'; }``) is not an ASCII character") {}

shared sealed class HeaderWithoutColonException(String header)
extends MessageProtocolException("Header '``header``' does not contain a colon (header name separator)") {}

shared sealed class NoContentLengthException()
extends MessageProtocolException("Content-Length header missing") {}

shared sealed class InvalidContentLengthException(String contentLength)
extends MessageProtocolException("Content-Length header '``contentLength`` is not valid") {}

shared sealed class DecodeContentException(Exception cause)
extends MessageProtocolException("Error while decoding content", cause) {}

shared sealed class ParseContentException(Exception cause)
extends MessageProtocolException("Error while parsing content", cause) {}