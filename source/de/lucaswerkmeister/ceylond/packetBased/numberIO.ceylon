import ceylon.buffer {
    ByteBuffer
}

"Writes the given unsigned [[integer]] in network byte order (big-endian) to the [[buffer]].
 Exactly [[size]] bytes of output are written."
shared void writeInteger(Integer integer, Integer size, ByteBuffer buffer) {
    "Does not support signed integers"
    assert (integer >= 0);
    "Does not support integers longer than the runtime addressable integer size"
    assert (0 <= 8 * size <= runtime.integerAddressableSize);
    "Integer must fit into [[size]] bytes"
    assert (integer.rightLogicalShift(8 * size) == 0 || 8*size >= runtime.integerAddressableSize);
    "Buffer must have [[size]] bytes available"
    assert (buffer.available >= size);
    if (size > 0) {
        for (offset in (size - 1) .. 0) {
            value byte = integer.rightLogicalShift(8 * offset).byte;
            buffer.put(byte);
        }
    }
}

"Reads an unsigned [[Integer]] in network byte order (big-endian) from the given [[buffer]],
 which must not have more than [[runtime.integerAddressableSize]]/8 bytes [[available|ceylon.buffer::Buffer.available]].
 All available bytes in the buffer are read."
shared Integer readInteger(ByteBuffer buffer) {
    "Does not support integers longer than the runtime addressable integer size"
    assert (8*buffer.available <= runtime.integerAddressableSize);
    variable Integer integer = 0;
    while (buffer.hasAvailable) {
        integer = integer.leftLogicalShift(8).or(buffer.get().unsigned);
    }
    "Does not support signed integers"
    assert (integer >= 0);
    return integer;
}
