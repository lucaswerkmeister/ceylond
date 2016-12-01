#include <error.h>
#include <langinfo.h>
#include <locale.h>
#include <string.h>

int main(int argc, char *argv[]) {
  setlocale(LC_CTYPE, "");
  if (strcmp(nl_langinfo(CODESET), "UTF-8") != 0)
    error(1, 0, "non-UTF-8 encoding (%s) not supported, please use an UTF-8 locale", nl_langinfo(CODESET));
}
