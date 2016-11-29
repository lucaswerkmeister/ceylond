import ceylon.buffer {
    ByteBuffer
}
import ceylon.test {
    assertEquals,
    test,
    parameters
}
import de.lucaswerkmeister.ceylond.packetBased {
    readInteger,
    writeInteger
}

"Test cases for [[testReadInteger]]."
shared [String][] readIntegerTests = concatenate(generalReadIntegerTests, nativeReadIntegerTests);
"General test cases for [[testReadInteger]] that work on all platforms."
[String][] generalReadIntegerTests = [
    "00",
    "01",
    "7F",
    "80",
    "FF",
    "0000",
    "FFFF",
    "010000",
    "00000000",
    "7FFFFFFF"
].collect((t) => [t]);
"Test cases for [[testReadInteger]] that only work on the JVM because they exceed the addressable integer size on JS."
native [String][] nativeReadIntegerTests;
native ("jvm") [String][] nativeReadIntegerTests = [
    "FFFFFFFF",
    "0100000000",
    "0000000000000000",
    "7FFFFFFFFFFFFFFF"
].collect((t) => [t]);
native ("js") [String][] nativeReadIntegerTests = [];

"Test cases for [[testWriteInteger]]."
shared [Integer,Integer][] writeIntegerTests = concatenate(generalWriteIntegerTests, nativeWriteIntegerTests);
"General test cases for [[testWriteInteger]] that work on all platforms"
[Integer,Integer][] generalWriteIntegerTests = [
    [#00, 1],
    [#00, 1],
    [#7F, 1],
    [#FF, 1],
    [#0000, 2],
    [#FFFF, 2],
    [#10000, 3],
    [#7FFFFFFF, 4]
];
"Test cases for [[testWriteInteger]] that only work on the JVM because they exceed the addressable integer size on JS."
native [Integer,Integer][] nativeWriteIntegerTests;
native ("jvm") [Integer,Integer][] nativeWriteIntegerTests = [
    [#FFFFFFFF, 4],
    [#100000000, 5],
    [#100000000, 8],
    [#7FFFFFFFFFFFFFFF, 8]
];
native ("js") [Integer,Integer][] nativeWriteIntegerTests = [];

test
parameters (`value readIntegerTests`)
shared void testReadInteger(variable String str) {
    ByteBuffer buf = ByteBuffer.ofSize(str.size / 2);
    assert (exists Integer int = parseInteger(str, 16));
    while (!str.empty) {
        assert (exists b = parseInteger(str[0..1], 16));
        buf.put(b.byte);
        str = str[2...];
    }
    buf.flip();
    Integer int_ = readInteger(buf);
    assertEquals {
        expected = int;
        actual = int_;
    };
}

test
parameters (`value writeIntegerTests`)
shared void testWriteInteger(Integer int, Integer size) {
    ByteBuffer buf = ByteBuffer.ofSize(size);
    writeInteger(int, size, buf);
    buf.flip();
    assert (exists Integer int_ = parseInteger("".join(buf.collect((b) => formatInteger(b.unsigned, 16).padLeading(2, '0'))), 16));
    assertEquals {
        expected = int;
        actual = int_;
    };
}
