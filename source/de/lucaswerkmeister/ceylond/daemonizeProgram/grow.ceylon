import ceylon.buffer {
    ByteBuffer
}

"Grow the given [[buffer]] until it can fit [[size]] more bytes."
void grow(ByteBuffer buffer, Integer size) {
    variable value cap = buffer.capacity;
    value needed = buffer.position + size;
    if (cap < needed) {
        while (cap < needed) {
            cap *= 2;
        }
        buffer.resize { cap; growLimit = true; };
    }
}
