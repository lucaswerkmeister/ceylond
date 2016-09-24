suppressWarnings ("expressionTypeNothing")
void closeAndExit(void close())() {
    close();
    process.exit(0);
}
