import ceylon.buffer {
    ByteBuffer
}

"Writes the given unsigned [[integer]] in network byte order (big-endian) to the [[buffer]].
 Exactly [[size]] bytes of output are written."
void writeInteger(variable Integer integer, Integer size, ByteBuffer buffer) {
    "Does not support signed integers"
    assert (integer >= 0);
    "Does not support integers longer than the runtime addressable integer size"
    assert (0 <= 8*size <= runtime.integerAddressableSize);
    "Integer must fit into [[size]] bytes"
    assert (integer < 256^size || size == 8);
    "Buffer must have [[size]] bytes available"
    assert (buffer.available >= size);
    if (size != 0) { // [[modulus]] calculation is invalid in size 0
        value modulus = 256^(size-1);
        variable value sizeBytes = 0; // #FFFF.., [[size]] bytes wide
        for (index in 0:size) {
            sizeBytes = sizeBytes.leftLogicalShift(8).or(#FF);
        }
        for (index in 0:size) {
            buffer.put((integer / modulus).byte);
            integer = integer.leftLogicalShift(8).and(sizeBytes);
        }
    }
}

"Reads an unsigned [[Integer]] in network byte order (big-endian) from the given [[buffer]],
 which must not have more than [[runtime.integerAddressableSize]]/8 bytes [[available|ceylon.buffer::Buffer.available]].
 All available bytes in the buffer are read."
Integer readInteger(ByteBuffer buffer) {
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
