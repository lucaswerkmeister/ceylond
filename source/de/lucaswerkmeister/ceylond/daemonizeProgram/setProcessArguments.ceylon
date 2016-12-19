import ceylon.interop.java {
    javaClass,
    createJavaStringArray
}

"Set [[process.arguments]]."
native void setProcessArguments(String[] arguments);

native ("jvm") void setProcessArguments(String[] arguments) {
    assert (exists setupArgumentsMethod = javaClass<\Iprocess>().declaredMethods.array.find((m) => m.name == "setupArguments"));
    setupArgumentsMethod.invoke(process, createJavaStringArray(arguments));
}

native ("js") void setProcessArguments(String[] arguments) {
    dynamic {
        // set Node process.argv, with two dummies because of https://github.com/ceylon/ceylon.language/issues/503
        eval("(function(args){process.argv=args;})")(dynamic [ "dummy1", "dummy2", *arguments ]);
        // delete Ceylon process.argv
        eval("(function(process){delete process.argv;})")(process);
        // next evaluation of Ceylon process.arguments will reinitialize Ceylon process.argv from new Node process.argv
    }
}
