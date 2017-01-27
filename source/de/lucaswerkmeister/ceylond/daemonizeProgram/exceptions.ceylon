class ProcessExit(shared Integer exitCode) extends Exception("process.exit(``exitCode``)") {}

class StandardInputExceeded(shared Integer limit) extends Exception("standard input exceeded configured limit of ``limit`` bytes") {}
class StandardOutputExceeded(shared Integer limit) extends Exception("standard output exceeded configured limit of ``limit`` bytes") {}
class StandardErrorExceeded(shared Integer limit) extends Exception("standard error exceeded configured limit of ``limit`` bytes") {}
