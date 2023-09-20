FROM edence/rcore
LABEL maintainer="edenceHealth <info@edence.health>"

ARG AG="apt-get -yq"
ARG DEBIAN_FRONTEND="noninteractive"

RUN --mount=type=cache,sharing=private,target=/var/cache/apt \
    --mount=type=cache,sharing=private,target=/var/lib/apt \
  set -eux; \
  find /var/cache/app /var/lib/apt || :; \
  # enable the above apt cache mount to work by preventing auto-deletion
  rm -f /etc/apt/apt.conf.d/docker-clean; \
  echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
    >/etc/apt/apt.conf.d/01keep-debs; \
  # apt installations
  $AG update; \
  $AG install --no-install-recommends \
    cmake \
    curl \
    iputils-ping \
    libcairo2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libfribidi-dev \
    libgit2-dev \
    libharfbuzz-dev \
    libjpeg-dev \
    libpng-dev \
    libsodium-dev \
    libtiff5-dev \
  ;

WORKDIR /app
COPY renv.lock ./
RUN --mount=type=cache,sharing=private,target=/renv_cache \
    --mount=type=cache,sharing=private,target=/root/.cache/R/renv \
  set -eux; \
  find /renv_cache /root/.cache/R/renv || :; \
  Rscript \
    -e 'renv::activate("/app")' \
    -e 'renv::restore()' \
    -e 'renv::isolate()' \
  ;

# https://ohdsi.github.io/DatabaseConnector/articles/Connecting.html#the-jar-folder
ENV DATABASECONNECTOR_JAR_FOLDER="/usr/local/lib/DatabaseConnectorJars"
RUN set -eux; \
  Rscript \
    -e 'renv::activate("/app")' \
    -e 'library(DatabaseConnector)' \
    -e 'downloadJdbcDrivers("oracle")' \
    -e 'downloadJdbcDrivers("postgresql")' \
    -e 'downloadJdbcDrivers("redshift")' \
    -e 'downloadJdbcDrivers("spark")' \
    -e 'downloadJdbcDrivers("sql server")' \
  ;

WORKDIR /output

COPY ["entrypoint.sh", "cdm_inspection.R", "/app/"]
USER nonroot

ENTRYPOINT ["/app/entrypoint.sh"]
