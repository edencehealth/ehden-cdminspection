#!/usr/bin/Rscript
# CLI utility to invoke the EHDEN CDM Inspection and Catalogue Export packages
#
# https://github.com/EHDEN/CdmInspection
# https://raw.githubusercontent.com/EHDEN/CdmInspection/master/extras/CdmInspection.pdf
# https://github.com/EHDEN/CdmInspection/blob/master/extras/CodeToRun.R
#
# https://github.com/EHDEN/CatalogueExport
# https://raw.githubusercontent.com/EHDEN/CatalogueExport/master/inst/doc/runningCatalogueExport.pdf

library(CdmInspection)
library(CatalogueExport)
library(docopt)
library(stringr)

version_str <- "CdmInspection Wrapper v1.1"

'CdmInspection Wrapper

Usage:
  cdm_inspection.R [options]

General options:
  -h, --help                        Show this help message
  --output-base=<path>              The base output directory in which to write results [default: ./results]
  --quiet                           Runs the cdmInspection and catalogueExport with verboseMode set to FALSE and generateResultsDocument with silent set to TRUE
  --s3-target=<str>                 Optional AWS S3 bucket path to sync with the output_base directory (for uploading results to S3)
  --sql-only                        Print the SQL queries that would be executed but do not actually execute the queries
  --output-doc-template=<name>      The name of the generateResultsDocument docTemplate to use [default: EHDEN]
  --small-cell-count=<int>          To avoid patient identifiability, only cells with result counts larger than this value will be included the the output [default: 5]
  --webapi-url=<url>                The URL of the WebAPI instance to check [default: http://webapi:8080/WebAPI]

Inspection Options:
  --no-cdm-inspection               Skip the CDM Inspection entirely
  --no-vocabulary-checks            Skip the normal vocabulary checks
  --no-table-checks                 Skip the normal table checks
  --no-performance-checks           Skip the normal performance checks
  --no-webapi-checks                Skip the normal WebAPI checks
  --inspection-analysis-ids=<str>   An optional comma-separated list of analysis IDs to run

Schema Options:
  With all the following schema options, on SQL Server, specifiy both the database and the schema, for example: "cdm_instance.dbo"

  --cdm-schema=<name>               The name of database schema that contains the OMOP CDM tables [default: public]
  --results-schema=<name>           The name of database schema that contains Achilles run results [default: results]
  --scratch-schema=<name>           The name of database schema where temporary tables can be written [default: results]
  --vocab-schema=<name>             The name of database schema that contains OMOP Vocabulary [default: vocabulary]
  --oracle-temp-schema=<name>       The name of the database schema where temporary tables can be written - Oracle databases only; requires create/insert permissions to this database [default: results]

Metadata Options:
  --database-id=<name>              An ID for the database, this value will be used as the name of a subfolder of the results; example id: "SYNPUF". In "AUTO" mode, this value will be derived from the db-name value below [default: AUTO]
  --database-description=<string>   A short description of the database which will be integrated into the output. In "AUTO" mode, this value will be derived from some of the DB connection options below [default: AUTO]
  --authors=<string>                A simple string listing the authors of the harmonized data, this value will be integrated into the output [default: -]

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
  --cdm-version=<str>               Define the OMOP CDM version used: Use major and minor number only e.g. "5.3" [default: 5.3]
  --temp-table-prefix=<str>         The prefix used in the scratch analyses tables [default: tmpach]
  --no-create-indices               Prevent the creation of indices on the result tables
  --no-create-tables                Prevent the creation of the results tables in the results schema and assume they already exist
  --no-drop-scratch-tables          Prevent dropping the scratch tables at the end of the export which may be time-consuming on some DBMS

' -> doc_str

# NOTE!
# these options are currently disabled because catalogueExport uses "missing()"
# when it is processing it's function arguments. we'll have to restructure the
# call to catalogueExport to work around this.
# --source-name=<name>              Name of the data source. If blank, the CDM_SOURCE table will be queried to try to obtain this
# --export-analysis-ids=<str>       An optional comma-separated list of analysis IDs to run
# I've opened a ticket to see if upstream will fix it: https://github.com/EHDEN/CatalogueExport/issues/51

# Argument & environment variable parsing
parse_bool <- function(str_value) {
  toupper(str_value) %in% c("1", "TRUE", "YES", "Y", "ON")
}

args <- docopt(doc_str, version = version_str)
arg_defaults <- docopt(doc_str, args = c(), version = version_str)
arg_names <- names(args)

# environment variables like DQD_WEB_HOST override args like --dqd-web-host if
# the args have their default value. (user-set cli args must override envvars)
for (name in arg_names[!grepl("--", arg_names, fixed = TRUE)]) {
  envvar_name <- toupper(name)
  envvar_value <- Sys.getenv(c(envvar_name), NA)
  if (!is.na(envvar_value)) {
    if (args[[name]] == arg_defaults[[name]]) {
      if (typeof(arg_defaults[[name]]) == "logical") {
        print(str_glue("Importing logical envvar {envvar_name} into {name}"))
        args[[name]] <- parse_bool(envvar_value)
      } else {
        print(str_glue("Importing string envvar {envvar_name} into {name}"))
        args[[name]] <- envvar_value
      }
    } else {
      print(str_glue("Ignoring envvar {envvar_name}, CLI arg has precedence"))
    }
  }
}

# arg conversions: null to string
for (i in seq_along(args)) {
  if (is.null(args[[i]])) {
    args[[i]] <- ""
  }
}

# arg conversions: string to numeric
numeric_args <- c("db_port", "small_cell_count", "num_threads")
for (name in numeric_args) {
  args[[name]] <- as.numeric(args[[name]])
}

# arg conversions: csv to vector
if (args$inspection_analysis_ids != "") {
  args$inspection_analysis_ids <- toupper(
    unlist(strsplit(args$inspection_analysis_ids, ","))
  )
}
# TEMP. DISABLED SEE NOTE ABOUT THE USE OF "missing()" ABOVE
# if (args$export_analysis_ids != "") {
#   args$export_analysis_ids <- toupper(
#     unlist(strsplit(args$export_analysis_ids, ","))
#   )
# }

# arg conversions: misc
if (args$database_id == "AUTO") {
  args$database_id <- args$db_name
}
if (args$database_description == "AUTO") {
  args$database_description <- str_glue(
    "{args$db_dbms} database named '{args$db_name}' on {args$db_hostname}"
  )
}

# print parsed runtime configuration to stdout at startup
filtered_args <- args
for (name in arg_names[grepl("password", arg_names, fixed = TRUE)]) {
  filtered_args[name] <- "REDACTED"
}
for (name in arg_names[grepl("--", arg_names, fixed = TRUE)]) {
  filtered_args[name] <- NULL
}
filtered_args["help"] <- NULL
print("Runtime configuration:")
print(filtered_args)

valid_dbms <- list(
  "bigquery",
  "netezza",
  "oracle",
  "pdw",
  "postgresql",
  "redshift",
  "sql server",
  "sqlite"
)

# these dbms require the database name to be appended to the hostname
name_concat_dbms <- list(
  "netezza",
  "oracle",
  "postgresql",
  "redshift"
)

if (!(args$db_dbms %in% valid_dbms)) {
  stop("Cannot proceed with invalid dbms: ", args$db_dbms)
}

# Some connection packages need the database on the server argument.
# see ?createConnectionDetails after loading library(Achilles)
if (args$db_dbms %in% name_concat_dbms) {
  server <- paste(args$db_hostname, args$db_name, sep = "/")
} else {
  server <- args$db_hostname
}

# Create connection details using DatabaseConnector utility.
connection_details <- createConnectionDetails(
  dbms = args$db_dbms,
  user = args$db_username,
  password = args$db_password,
  server = server,
  port = args$db_port,
  pathToDriver = args$databaseconnector_jar_folder
)

output_folder <- file.path(args$output_base, args$database_id)

if (!args$no_cdm_inspection) {
  # in many cases the comments on function arguments below are directly copied
  # from the CdmInspection package docs and/or source code
  results <- cdmInspection(
    # connectionDetails: An R object of type connectionDetails created using
    # the function createConnectionDetails in the DatabaseConnector package.
    connection_details,

    # cdmDatabaseSchema: Fully qualified name of database schema that contains
    # OMOP CDM schema. On SQL Server, this should specifiy both the database
    # and the schema, so for example, on SQL Server, 'cdm_instance.dbo'
    cdmDatabaseSchema = args$cdm_schema,

    # resultsDatabaseSchema: Fully qualified name of database schema that we
    # can write final results to. Default is cdmDatabaseSchema. On SQL Server,
    # this should specifiy both the database and the schema, so for example,
    # on SQL Server: 'cdm_results.dbo'.
    resultsDatabaseSchema = args$results_schema,

    # scratchDatabaseSchema: Fully qualified name of database schema that we
    # can write temporary tables to. Default is resultsDatabaseSchema. On
    # SQL Server, this should specifiy both the database and the schema,
    # for example: 'cdm_scratch.dbo'
    scratchDatabaseSchema = args$scratch_schema,

    # vocabDatabaseSchema: String name of database schema that contains OMOP
    # Vocabulary. Default is cdmDatabaseSchema. On SQL Server, this should
    # specifiy both the database and the schema, so for example 'results.dbo'
    vocabDatabaseSchema = args$vocab_schema,

    # oracleTempSchema: For Oracle only: the name of the database schema where
    # you want all temporary tables to be managed. Requires create/insert
    # permissions to this database
    oracleTempSchema = args$oracle_temp_schema,

    # databaseName: String name of the database name. If blank, CDM_SOURCE
    # table will be queried to try to obtain this
    databaseName = args$db_name,

    # databaseId: ID of your database, this will be used as subfolder for the
    # results
    databaseId = args$database_id,

    # databaseDescription: Provide a short description of the database
    databaseDescription = args$database_description,

    # analysisIds: Analyses to run;
    # unimplemented in CdmInspection as of 17-Jun-2022
    analysisIds = args$inspection_analysis_ids,

    # smallCellCount: To avoid patient identifiability, cells with small counts
    # (<= smallCellCount) are deleted. Set to NULL if you don't want any
    # deletions
    smallCellCount = args$small_cell_count,

    # runVocabularyChecks: Boolean to determine if vocabulary checks need to be
    # run.
    runVocabularyChecks = !args$no_vocabulary_checks,

    # runDataTablesChecks: Boolean to determine if table checks need to be run.
    runDataTablesChecks = !args$no_table_checks,

    # runPerformanceChecks: Boolean to determine if performance checks need to
    # be run.
    runPerformanceChecks = !args$no_performance_checks,

    # runWebAPIChecks: Boolean to determine if WebAPI checks need to be run.
    runWebAPIChecks = !args$no_webapi_checks,

    # baseUrl: WebAPI url, example: http://server.org:80/WebAPI
    baseUrl = args$webapi_url,

    # sqlOnly: Boolean to determine if CdmInspection should be fully executed.
    # if set to TRUE just generate SQL files, don't actually run
    sqlOnly = args$sql_only,

    # outputFolder: Path to store logs and SQL files
    outputFolder = output_folder,

    # verboseMode: Boolean to determine if the console will show all execution
    # steps
    verboseMode = !args$quiet
  )

  generateResultsDocument(
    # results: Results object from cdmInspection
    results,

    # outputFolder: Folder to store the results
    output_folder,

    # docTemplate: Name of the document template (EHDEN)
    docTemplate = args$output_doc_template,

    # authors: List of author names to be added in the document
    authors = args$authors,

    # databaseDescription: Description of the database
    databaseDescription = args$database_description,

    # databaseName: Name of the database
    databaseName = args$db_name,

    # databaseId: Id of the database
    databaseId = args$database_id,

    # smallCellCount: Dates with less than this number of patients are removed
    smallCellCount = args$small_cell_count,

    # silent: Flag to not create output in the terminal (default = FALSE)
    silent = args$quiet
  )
}

if (!args$no_catalogue_export) {
  # in many cases the comments on function arguments below are directly copied
  # from the CatalogueExport package docs and/or source code

  # https://github.com/EHDEN/CatalogueExport
  # exports a set of  descriptive statistics summary from the CDM, to be
  # uploaded in the Database Catalogue
  catalogueExport(
    # connectionDetails: An R object of type connectionDetails created via
    # createConnectionDetails in the DatabaseConnector package
    connection_details,

    # cdmDatabaseSchema: Fully qualified name of database schema that contains
    # OMOP CDM. On SQL Server, this should specifiy both the database and the
    # schema, for example: cdm_instance.dbo
    cdmDatabaseSchema = args$cdm_schema,

    # resultsDatabaseSchema: Fully qualified name of database schema to write
    # final results to. Default is derived from cdmDatabaseSchema. On SQL
    # Server, this should specifiy both the database and the schema,
    # for example: cdm_results.dbo
    resultsDatabaseSchema = args$results_schema,

    # scratchDatabaseSchema: Fully qualified name of the database schema that
    # will store all of the intermediate scratch tables. On SQL Server, this
    # should specifiy both the database and the schema,
    # for example: cdm_scratch.dbo
    # It must be accessible to/from the cdmDatabaseSchema and the
    # resultsDatabaseSchema. Default is derived from resultsDatabaseSchema.
    # Making this "#" will run CatalogueExport in single-threaded mode and use
    # temporary tables instead of permanent tables
    scratchDatabaseSchema = args$scratch_schema,

    # vocabDatabaseSchema: Fully qualified name of the database schema that
    # contains OMOP Vocabulary. Default is derived from cdmDatabaseSchema. On
    # SQL Server, this should specifiy both the database and the schema,
    # for example: 'results.dbo'
    vocabDatabaseSchema = args$vocab_schema,

    # oracleTempSchema: (For Oracle only) the name of the database schema where
    # all temporary tables will be managed. Requires create/insert permissions
    # to this database
    oracleTempSchema = args$oracle_temp_schema,

    # sourceName: String name of the data source name. If blank, the CDM_SOURCE
    # table will be queried to try to obtain this
    # sourceName = args$source_name,
    # TEMP. DISABLED SEE NOTE ABOUT THE USE OF "missing()" ABOVE

    # analysisIds: (OPTIONAL) A vector containing the set of CatalogueExport
    # analysisIds for which results will be generated. If not specified, all
    # analyses will be executed. Use getAnalysisDetails to get a list of all
    # CatalogueExport analyses and their Ids
    # analysisIds = args$export_analysis_ids,
    # TEMP. DISABLED SEE NOTE ABOUT THE USE OF "missing()" ABOVE

    # createTable: If true, new results tables will be created in the results
    # schema. If not, the tables are assumed to already exist, and analysis
    # results will be inserted (slower on MPP)
    createTable = !args$no_create_tables,

    # smallCellCount: To avoid patient identifiability, cells with small counts
    # (<= smallCellCount) are deleted. Set to NULL if you don't want any
    # deletions.
    smallCellCount = args$small_cell_count,

    # cdmVersion: Define the OMOP CDM version used:  currently supports v5 and
    # above. Use major release number or minor number only (e.g. 5, 5.3)
    cdmVersion = args$cdm_version,

    # createIndices: Boolean to determine if indices should be created on the
    # resulting CatalogueExport tables. Default=TRUE
    createIndices = !args$no_create_indices,

    # numThreads: (OPTIONAL, multi-threaded mode) The number of threads to use
    # to run CatalogueExport in parallel. Default is 1 thread.
    numThreads = args$num_threads,

    # tempPrefix: (OPTIONAL, multi-threaded mode) The prefix to use for the
    # scratch CatalogueExport analyses tables. Default is "tmpach"
    tempPrefix = args$temp_table_prefix,

    # dropScratchTables: (OPTIONAL, multi-threaded mode) TRUE = drop the
    # scratch tables (may take time depending on dbms), FALSE = leave them in
    # place for later removal.
    dropScratchTables = !args$no_drop_scratch_tables,

    # sqlOnly: Boolean to determine if CatalogueExport should be fully executed
    # TRUE = just generate SQL files, don't actually run
    # FALSE = run CatalogueExport
    sqlOnly = args$sql_only,

    # outputFolder: Path to store logs and SQL files
    outputFolder = output_folder,

    # verboseMode: Boolean to determine if the console will show all execution
    # steps. Default = TRUE
    verboseMode = !args$quiet
  )
}


if (args$s3_target != "") {
  # https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/system
  system(
    paste("aws", "s3", "sync", sQuote(args$output_base), sQuote(args$s3_target)),
    intern = FALSE,
    ignore.stdout = FALSE,
    ignore.stderr = FALSE,
    wait = TRUE,
    input = NULL,
    show.output.on.console = TRUE,
    minimized = FALSE,
    invisible = TRUE,
    timeout = 0
  )
}
