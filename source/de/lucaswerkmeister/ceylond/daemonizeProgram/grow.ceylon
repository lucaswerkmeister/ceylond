import ceylon.buffer {
    ByteBuffer
}

"Grow the given [[buffer]] until it can fit [[size]] more bytes.

 If [[limit]] is not [[null]], and the buffer would need to grow beyond the limit,
 an exception returned by [[onLimitExceeded]] is thrown."
void grow(ByteBuffer buffer, Integer size, Integer? limit, Throwable(Integer) onLimitExceeded) {
    variable value cap = buffer.capacity;
    value needed = buffer.position + size;
    if (cap < needed) {
        if (exists limit, needed > limit) {
            throw onLimitExceeded(limit);
        }
        if (cap == 0) {
            cap = 1; // doubling 0 won’t get us very far
        }
        while (cap < needed) {
            cap *= 2;
        }
        buffer.resize { cap; growLimit = true; };
    }
}
