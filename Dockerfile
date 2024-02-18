FROM edence/rcore
LABEL maintainer="edenceHealth <info@edence.health>"

ARG AG="apt-get -yq --no-install-recommends"
ARG DEBIAN_FRONTEND="noninteractive"

RUN set -eux; \
  $AG update; \
  $AG install \
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
  --mount=type=secret,id=GITHUB_PAT \
  if [ -f "/run/secrets/GITHUB_PAT" ]; then export GITHUB_PAT=$(cat "/run/secrets/GITHUB_PAT"); fi; \
  set -eux; \
  Rscript \
    -e 'download.file("https://raw.githubusercontent.com/OHDSI/Hades/main/hadesWideReleases/2023Q3/renv.lock", "hades-renv.lock")' \
    -e 'options(renv.config.cache.symlinks = FALSE)' \
    # -e 'renv::activate()' \
    -e 'renv::restore(lockfile="hades-renv.lock")' \
    -e 'renv::install(packages=readLines("renv.txt"))' \
    -e 'renv::isolate()' \
    -e 'renv::snapshot(type="all")' \
  ;

# https://ohdsi.github.io/DatabaseConnector/articles/Connecting.html#the-jar-folder
ENV DATABASECONNECTOR_JAR_FOLDER="/usr/local/lib/DatabaseConnectorJars"
RUN set -eux; \
  Rscript \
    -e 'renv::activate()' \
    -e 'DatabaseConnector::downloadJdbcDrivers("all")' \
  ;

WORKDIR /output

COPY ["cdm_inspection.R", "/app/"]
USER nonroot

ENTRYPOINT ["/usr/bin/Rscript", "/app/cdm_inspection.R"]
