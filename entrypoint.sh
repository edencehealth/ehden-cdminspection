#!/bin/sh

warn() {
  printf '%s %s\n' "$(date '+%FT%T')" "$*" >&2
}

die() {
  warn "FATAL:" "$@"
  exit 1
}

main() {
  warn "ENTRYPOINT starting; $(id)"

  # https://ohdsi.github.io/DatabaseConnector/articles/Connecting.html#the-jar-folder
  # this envvar should be defined in the Dockerfile and override-able at runtime
  : "${DATABASECONNECTOR_JAR_FOLDER:?This environment variable is required}"

  # normally this will only be one directory
  for dir in /app/renv/library/R-*/*/; do
    if [ -n "$R_LIBS" ]; then
      export R_LIBS="${R_LIBS}:${dir}"
    else
      export R_LIBS="${dir}"
    fi
  done

  set -eux
  : "R_LIBS=${R_LIBS}" # print this at startup to aid debugging
  exec /app/cdm_inspection.R "$@"
}

main "$@"
