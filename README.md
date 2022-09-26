# CdmInspection Container

This container provides the EHDEN [CdmInspection](https://github.com/EHDEN/CdmInspection) and [CatalogueExport](https://github.com/EHDEN/CatalogueExport) R packages with a small wrapper for use in a container environment.

The container can be used and configured via command-line arguments (for example passed to `docker run`) or with environment variables.

## environment variables

Each command line argument has an equivalent environment variable, to determine name of the environment variable:

1. start with the argument and remote the leading dashes
2. convert to uppper-case
3. replace dashes with underscores
4. boolean, flag-style arguments like `--skip-achilles` are assumed to be false, but they can be enabled by setting them with the values: `1`, `TRUE`, `YES`, `Y`, or `ON`

For example:
  * `--small-cell-count=5` becomes `SMALL_CELL_COUNT=5`
  * `--quiet` becomes `QUIET=1`

## interactive help text

The following text is printed when invoking the container with the `-h` or `--help` arguments.

```
CdmInspection Wrapper

Usage:
  cdm_inspection.R [options]

General options:
  -h, --help                        Show this help message
  --output-base=<path>              The base output directory in which to write results [default: ./results]
  --quiet                           Runs the cdmInspection and catalogueExport with verboseMode set to FALSE and generateResultsDocument with silent set to TRUE
  --sql-only                        Print the SQL queries that would be executed but do not actually execute the queries
  --output-doc-template=<name>      The name of the generateResultsDocument docTemplate to use [default: EHDEN]
  --small-cell-count=<int>          To avoid patient identifiability, only cells with result counts larger than this value will be included the the output [default: 5]
  --webapi-url=<url>                the URL of the WebAPI instance to check [default: http://webapi:8080/WebAPI]

Inspection Options:
  --no-cdm-inspection               skip the CDM Inspection entirely
  --no-vocabulary-checks            skip the normal vocabulary checks
  --no-table-checks                 skip the normal table checks
  --no-performance-checks           skip the normal performance checks
  --no-webapi-checks                skip the normal WebAPI checks
  --inspection-analysis-ids=<str>   An optional comma-separated list of analysis IDs to run

Schema Options:
  With all the following schema options, on SQL Server, specifiy both the database and the schema, for example: "cdm_instance.dbo"

  --cdm-schema=<name>               name of database schema that contains the OMOP CDM tables [default: public]
  --results-schema=<name>           name of database schema that contains Achilles run results [default: results]
  --scratch-schema=<name>           name of database schema where temporary tables can be written [default: results]
  --vocab-schema=<name>             name of database schema that contains OMOP Vocabulary [default: vocabulary]
  --oracle-temp-schema=<name>       (Oracle databases only); name of the database schema where temporary tables can be written; requires create/insert permissions to this database [default: results]

Metadata Options:
  --database-id=<name>              An ID for the database, this value will be used as the name of a subfolder of the results; example id: "SYNPUF". In "AUTO" mode, this value will be derived from the db-name value below [default: AUTO]
  --database-description=<string>   a short description of the database which will be integrated into the output. In "AUTO" mode, this value will be derived from some of the DB connection options below [default: AUTO]
  --authors=<string>                a simple string listing the authors of the harmonized data, this value will be integrated into the output [default: -]

CDM DB Options:
  --db-dbms=<name>                  The database management system for the CDM database [default: postgresql]
  --db-hostname=<name>              The hostname the database server is listening on [default: db]
  --db-port=<n>                     The port the database server is listening on [default: 5432]
  --db-name=<name>                  The name of the database on the database server; if blank the CDM_SOURCE table will be queried to obtain this name [default: cdm]
  --db-username=<name>              The username to connect to the database server with [default: pgadmin]
  --db-password=<name>              The password to connect to the database server with [default: postgres]
  --databaseconnector-jar-folder=<directory>   The path to the driver jar files used by the DatabaseConnector to connect to various DBMS [default: /usr/local/lib/DatabaseConnectorJars]

Catalogue Export Options:
  --no-catalogue-export             Skip running the EHDEN CatalogueExport entirely
  --num-threads=<n>                 The number of threads use when running CatalogueExport [default: 1]
  --source-name=<name>              Name of the data source. If blank, the CDM_SOURCE table will be queried to try to obtain this
  --cdm-version=<str>               Define the OMOP CDM version used: Use major and minor number only e.g. "5.3" [default: 5.3]
  --export-analysis-ids=<str>       An optional comma-separated list of analysis IDs to run
  --temp-table-prefix=<str>         The prefix used in the scratch analyses tables [default: tmpach]
  --no-create-indices               Prevent the creation of indices on the result tables
  --no-create-tables                Prevent the creation of the results tables in the results schema and assume they already exist
  --no-drop-scratch-tables          Prevent dropping the scratch tables at the end of the export which may be time-consuming on some DBMS
```
