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
COPY renv.txt ./

RUN \
  --mount=type=cache,sharing=private,target=/renv_cache \
  --mount=type=cache,sharing=private,target=/root/.cache/R/renv \
  # --mount=type=secret,id=GITHUB_PAT \
  if [ -f "/run/secrets/GITHUB_PAT" ]; then export GITHUB_PAT=$(cat "/run/secrets/GITHUB_PAT"); fi; \
  set -eux; \
  Rscript \
    --vanilla \
    -e 'options(renv.config.cache.symlinks = FALSE)' \
    -e 'renv::activate()' \
    -e 'renv::install(packages=readLines("renv.txt"))' \
    -e 'renv::isolate()' \
    -e 'renv::snapshot(type="all")' \
  ;

# https://ohdsi.github.io/DatabaseConnector/articles/Connecting.html#the-jar-folder
ENV DATABASECONNECTOR_JAR_FOLDER="/usr/local/lib/DatabaseConnectorJars"
RUN set -eux; \
  Rscript \
    --vanilla \
    -e 'renv::activate("/app")' \
    -e 'library(DatabaseConnector)' \
    -e 'downloadJdbcDrivers("all")' \
  ;

WORKDIR /output

COPY ["entrypoint.sh", "cdm_inspection.R", "/app/"]
USER nonroot

ENTRYPOINT ["/app/entrypoint.sh"]
