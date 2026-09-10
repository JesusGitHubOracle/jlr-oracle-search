# Build Document Oriented Applications using Oracle Autonomous AI JSON Database

This repository contains examples of how to use Oracle JSON and the Oracle Database API for MongoDB to keep document-oriented application patterns while running on Oracle Database.

## Prerequisites

- Oracle AI Autonomous Database or Oracle Database 26ai, on-premises or cloud.
- Oracle REST Data Services. See [Oracle REST Data Services and Database Actions downloads](https://www.oracle.com/database/sqldeveloper/technologies/db-actions/download/).
- MongoDB client tools and drivers supported by Oracle Database API for MongoDB. See [Client Tools and Drivers](https://docs.oracle.com/en/database/oracle/mongodb-api/mgapi/support-mongodb-apis-operations-and-data-types-reference.html#GUID-0D110BE7-7BB3-4DC3-9A98-4F517271F2AE) in the Oracle documentation.

## Migration

Directory: `migration/`

These scripts help move MongoDB application databases into Oracle Autonomous AI JSON Database through backup, restore, and index metadata capture.

### MongoDB Database Space Report

Use `atlas_database_space.sh` to report the allocated collection storage, index
storage, and total occupied storage for every application database in an Atlas
cluster. It excludes `admin`, `config`, `local`, and Atlas internal databases by default.

```bash
export MONGO_URI='mongodb+srv://USER:PASS@cluster.mongodb.net/?retryWrites=true&w=majority'
./migration/atlas_database_space.sh
```

The connected user needs permission to list databases and run `dbStats` on each
reported database. Add `--include-system-databases` only when those databases
also need to be included.

### MongoDB Collection Space Report

Use `atlas_collection_space.sh` to interactively select a database and collection
and report logical document data plus allocated collection and index storage. For
sharded collections, the script sums the shard results and prints a per-shard
breakdown.

```bash
export MONGO_URI='mongodb+srv://USER:PASS@cluster.mongodb.net/?retryWrites=true&w=majority'
./migration/atlas_collection_space.sh
```

### Backup databases

`backup-app-dbs.sh` backs up MongoDB databases with `mongodump`. Use `APP_DATABASES` to back up a specific list, or set `BACKUP_MODE=all` to back up all databases except `admin`, `local`, and `config`.

```bash
export MONGO_URI='mongodb+srv://USER:PASS@cluster.mongodb.net/?retryWrites=true&w=majority'
export APP_DATABASES='appdb1 appdb2'
./migration/backup-app-dbs.sh

export BACKUP_MODE='all'
./migration/backup-app-dbs.sh
```

### Restore databases

`restore-db-archives.sh` restores every `*.archive.gz` file from a backup directory with `mongorestore`, writes restore logs, and produces a summary file. Set `TARGET_URI` to the target Oracle Database API for MongoDB connection string before running it.

```bash
 
export TARGET_URI='mongodb://USER:PASSWORD@HOST:PORT/?authMechanism=PLAIN&authSource=$external&ssl=true'
./restore-db-archives.sh ./backups/20260706_120000
```

Common restore options:

```bash
# Drop existing MongoDB collections before restoring.
export DROP_EXISTING=1

# Skip index restoration if index creation fails or will be handled separately.
export SKIP_INDEXES=1

# Write logs somewhere other than ./restore-logs.
export LOG_DIR=./restore-logs

# Tune restore parallelism. Start with values appropriate for the target capacity.
# PARALLEL_COLLECTIONS restores independent collections concurrently.
# INSERTION_WORKERS_PER_COLLECTION writes documents concurrently within a collection.
export PARALLEL_COLLECTIONS=8
export INSERTION_WORKERS_PER_COLLECTION=8

./restore-db-archives.sh ./backups/20260706_120000
```

`PARALLEL_COLLECTIONS` helps only when an archive contains multiple collections. For one-collection archives, such as the archives produced by this script's backup workflow, `INSERTION_WORKERS_PER_COLLECTION` is the setting that can increase restore throughput.

The restore script processes files ending in `.archive.gz`. For example, a backup directory like this:

```text
backups/20260706_120000/
  json_aggregations.archive.gz
  json_orders.archive.gz
```

restores the databases `json_aggregations` and `json_orders`.

### Extract indexes

`extract-db-indexes.sh` exports collection index definitions from a MongoDB database into JSON files under `indexes/`. Pass the database name and MongoDB URI as arguments. Views are detected and skipped because MongoDB views do not have collection indexes.

```bash
cd migration

./extract-db-indexes.sh sample_analytics 'mongodb+srv://USER:PASSWORD@cluster.example.mongodb.net/'
```

Example output:

```text
Exporting indexes for transactions
Exporting indexes for accounts
Exporting indexes for customers
Skipping view enriched_transactions
```

The generated files are written to `migration/indexes/` when the script is run from the `migration/` directory:

```text
indexes/
  transactions_indexes.json
  accounts_indexes.json
  customers_indexes.json
```

## Aggregation Pipelines

Directory: `aggregations/`

These examples show how to create JSON collection tables, load document data, and compare Oracle SQL/JSON approaches with MongoDB API aggregation pipelines.

Key files:

- `00-create-agg-user.sql` creates the aggregation demo user.
- `01-enrich-orders-oracle-json.sql` loads order, product, and warehouse JSON collections and builds an enriched order document with Oracle SQL/JSON.
- `02-enrich-orders-mongoapi.mongodb.js` loads the same data through the MongoDB API and enriches orders with `$lookup`, `$set`, `$unset`, and `$merge`.
- `03-regex-filter.mongodb.js` demonstrates regex filtering.
- `04-lookup-plants.mongodb.js` demonstrates lookup patterns across facility and plant documents.
- `05-lookup-plants-sql.mongodb.js` shows the SQL-oriented equivalent.
- `06-lookup-offers-sql.mongodb.js` creates `offerSummary` and `ifaOfferDaily100`, matches offer events by offer, widget, country, and date range, then returns rolled-up metrics in a `replacement` array.

## Transactions

Directory: `transactions/`

These examples show how to run MongoDB-style transactions with the Oracle Database API for MongoDB, using a bank transfer scenario with an approval step before commit.

 `bank-transfer.mongodb.js` runs the transfer with MongoDB API reads and updates inside a transaction.
 `bank-transfer-sqljson.mongodb.js` runs the transfer with SQL/JSON reads and updates through `$sql` inside a MongoDB API transaction.

## Change Streams

Directory: `changeStreams/`

These examples show how to enable `$changeStreams` in preview mode and consume insert, update, and delete events from the MongoDB API.

- `watch-orders.mongodb.js` enables change streams on `xs_orders` and watches for changes.
- `insert-orders.mongodb.js` inserts and updates a sample order so the watcher can receive events.

## Change Streams Kafka

Directory: `changeStreams-kafka/`

These examples show how to capture Oracle API for MongoDB change stream events with Node.js and publish them to an Apache Kafka topic for downstream processing.

- `mongo-kafka-cdc-cl/` contains the command-line CDC producer, including `cdc-mongodb-to-kafka.js`, which reads change events and publishes them to Kafka.
- `mongo-kafka-cdc-ui/` contains the browser-based CDC application with connection status, runtime configuration, and a live event timeline for Oracle Database changes and Kafka publishes.

## Text Search

Directory: `search/`

These examples show how to use MongoDB-style `$search` over JSON movie documents stored in Oracle using the MongoDB API.

- `01-create-text-user.sql` creates the text search demo user and grants the required privileges.
- `02-text-search-orclapi.mongodb.js` demonstrates text search patterns such as single-term search, multi-term search, `matchCriteria`, and fuzzy matching.
 Sample collection: [mflix_movies.json](https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/E_Hz1fFFFfbbIGstyg3beN0_WP6QQwwzATe_BsPXhCiGUeaSoH0WjLU7tBZnzglZ/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/search/mflix_movies.json)

## Vector Search

Directory: `vectorsearch/`

These examples show semantic search over JSON documents by using vector embeddings together with Oracle JSON collections and the MongoDB API.

- `01-load_all_minilm_model_from_par.sql` loads the MiniLM embedding model.
- `02-create-vector-embeddings.sql` creates embeddings for movie plot data.
- `03-embed-prompt.sql` embeds a natural-language prompt.
- `04-vector-search.mongodb.js` demonstrates vector search through the MongoDB API.
- Vectorized collection: [mflix_movies_embeddings.json](https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/yZJUDkTpVHdAI4vTUcuofDHWkk8w5sr2DoawtQ4PL9gQ-7hnHuNLH0gvOQNjJIRo/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/search/mflix_movies_embeddings.json)
 Embedding model: [ALL_MINILM_L12_V2](https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/hWtxHRNpBnQKaxtj5KtGVyQu4VYHqtuqAY4PUReK_6NxCeZRl94vm07lMGZAuOih/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/vector-data/all_MiniLM_L12_v2.onnx)

## References

- [Oracle JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
- [Oracle AI Vector Search Overview](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/overview-ai-vector-search.html)
- [Oracle Database API for MongoDB](https://docs.oracle.com/en/database/oracle/mongodb-api/mgapi/overview-oracle-database-api-mongodb.html)
- [Oracle JSON: From relational to document store](https://github.com/JesusGitHubOracle/jlr-oracle-json)
- [MongoDB Developer Documentation](https://www.mongodb.com/docs/development/)

## License

Copyright (c) 2026 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at [https://oss.oracle.com/licenses/upl/](https://oss.oracle.com/licenses/upl/).

## Disclaimer

ORACLE AND ITS AFFILIATES DO NOT PROVIDE ANY WARRANTY WHATSOEVER, EXPRESS OR IMPLIED, FOR ANY SOFTWARE, MATERIAL OR CONTENT OF ANY KIND CONTAINED OR PRODUCED WITHIN THIS REPOSITORY, AND IN PARTICULAR SPECIFICALLY DISCLAIM ANY AND ALL IMPLIED WARRANTIES OF TITLE, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE. FURTHERMORE, ORACLE AND ITS AFFILIATES DO NOT REPRESENT THAT ANY CUSTOMARY SECURITY REVIEW HAS BEEN PERFORMED WITH RESPECT TO ANY SOFTWARE, MATERIAL OR CONTENT CONTAINED OR PRODUCED WITHIN THIS REPOSITORY. IN ADDITION, AND WITHOUT LIMITING THE FOREGOING, THIRD PARTIES MAY HAVE POSTED SOFTWARE, MATERIAL OR CONTENT TO THIS REPOSITORY WITHOUT ANY WARRANTY OF ANY KIND, INCLUDING THAT THE CONTENT IS FREE OF DEFECTS, MERCHANTABLE, FIT FOR A PARTICULAR PURPOSE OR NON-INFRINGING. ANY OPEN SOURCE SOFTWARE IS PROVIDED BY THE APPLICABLE LICENSOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
