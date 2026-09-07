# JSON Full-Text Search with Oracle AI Database 26ai

Oracle AI Database supports JSON data natively alongside relational database features, including transactions, indexing, declarative querying, and views. JSON documents can be stored, indexed, and queried without requiring a fixed relational schema for their document attributes.

You can use the Oracle SQL condition `JSON_TEXTCONTAINS` to perform full-text searches over JSON while keeping the JSON data in the Oracle Database.

A JSON search index is an Oracle Text index designed specifically for JSON data. It enables efficient word and phrase searches within JSON documents. After creating a JSON search index, you can use the PL/SQL procedure `CTX_QUERY.RESULT_SET` to perform faceted searches over JSON data.

This repository uses a movies dataset and SQL scripts to demonstrate JSON full-text search features, including relevance scoring, prefix matching, fuzzy matching, thesaurus-based synonym expansion, and faceted search over JSON data.

## Prerequisites

You need access to either Oracle AI Database 26ai or Autonomous AI Database. For more information, see:

* [Oracle AI Autonomous JSON Database](https://www.oracle.com/autonomous-database/autonomous-json-database/)
* [Oracle AI Database 26ai](https://www.oracle.com/database/technologies/oracle-database-software-downloads.html)

## Scripts

Run the scripts in this order:

1. `01-oracle-json-user-ADB.sql` or `01-oracle-json-user-DB.sql`
2. `02.load-collection.sql`
3. `03-json-search-index.sql`
4. `04-synonyms.sql`
5. `05-facet-search.sql`

### `01-oracle-json-user-ADB.sql` and `01-oracle-json-user-DB.sql`

Creates the `JSON_TEXT` schema and grants the privileges required by the examples, including `DB_DEVELOPER_ROLE`. The Autonomous AI Database version also grants access to `DBMS_CLOUD`; the Oracle AI Database version grants access to a database directory. Both scripts can optionally enable the schema in Oracle REST Data Services (ORDS), which is a prerequisite for using the Oracle Database API for MongoDB.

### `02.load-collection.sql`

Loads the sample dataset into an Oracle JSON collection table from an external table. The source file is [`movies.ndjson`](movies.ndjson), which contains one movie document per line; the complete sample download is available as [`movies-json.zip`](https://github.com/JesusGitHubOracle/jlr-oracle-search/blob/main/movies-json.zip).

For Autonomous AI Database, upload `movies.ndjson` to your OCI Object Storage bucket, create a pre-authenticated request (PAR), and replace the example `movies_par_url` value in the script. For Oracle AI Database, copy `movies.ndjson` to a file system accessible to the database server, create a `movies_dir` `DIRECTORY` object for that location, and grant the schema access to it. The script uses `DBMS_CLOUD.CREATE_EXTERNAL_TABLE` for Autonomous AI Database and the `ORACLE_BIGDATA` driver for Oracle AI Database.

### `03-json-search-index.sql`
 
 Creates a JSON search index and includes examples of:

* `JSON_TEXTCONTAINS` for full-text search on JSON fields
* Relevance ranking with `SCORE()`
* Prefix matching
* Fuzzy matching  
* Execution-plan inspection to confirm the Oracle Text domain index is used


### `04-synonyms.sql`

Creates an Oracle Text thesaurus to store synonyms. This  improves search recall by expanding queries to match equivalent terms (e.g., searching for "robot" also returns "android" and "cyborg").

### `05-facet-search.sql`

Uses `CTX_QUERY.RESULT_SET` to find movies whose plot contains a given search term. It returns the first ten matches together with genre and rating facets, year buckets, and an average IMDb rating. Before running this script, rebuild the JSON search index with `SEARCH_ON TEXT_VALUE_STRING`, as shown in the script; this is required for string facets such as `genres` and `rated`.

## Reference documentation

* [Database & Cloud Technology Blog - JSON](https://blogs.oracle.com/coretec/category/crt-json)
* [Loading an array of JSON documents with DBMS_CLOUD](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-json-load-arrays-unpack.html)
* [Oracle SQL Condition JSON_TEXTCONTAINS](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/oracle-sql-condition-json_textcontains.html)
* [Oracle Text query operators](https://docs.oracle.com/en/database/oracle/oracle-database/19/ccref/oracle-text-CONTAINS-query-operators.html)
* [Oracle Text thesaurus features](https://docs.oracle.com/en/database/oracle/oracle-database/23/ccapp/overview-oracle-text-thesaurus-features.html)
* [Overview of the JSON Result Set Interface](https://docs.oracle.com/en/database/oracle/oracle-database/26/ccapp/overview-json-result-set-interface.html)
* [JSON facet search with CTX_QUERY.RESULT_SET](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/json-facet-search-pl-sql-procedure-ctx_query-result_set.html)
* [Oracle Text users and roles](https://docs.oracle.com/en/database/oracle/oracle-database/26/ccapp/oracle-text-users-and-roles.html)
* [Oracle JSON: From relational to document store](https://github.com/JesusGitHubOracle/jlr-oracle-json)

## License

Copyright (c) 2026 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at [https://oss.oracle.com/licenses/upl/](https://oss.oracle.com/licenses/upl/).

## Disclaimer

ORACLE AND ITS AFFILIATES DO NOT PROVIDE ANY WARRANTY WHATSOEVER, EXPRESS OR IMPLIED, FOR ANY SOFTWARE, MATERIAL OR CONTENT OF ANY KIND CONTAINED OR PRODUCED WITHIN THIS REPOSITORY, AND IN PARTICULAR SPECIFICALLY DISCLAIM ANY AND ALL IMPLIED WARRANTIES OF TITLE, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE. FURTHERMORE, ORACLE AND ITS AFFILIATES DO NOT REPRESENT THAT ANY CUSTOMARY SECURITY REVIEW HAS BEEN PERFORMED WITH RESPECT TO ANY SOFTWARE, MATERIAL OR CONTENT CONTAINED OR PRODUCED WITHIN THIS REPOSITORY. IN ADDITION, AND WITHOUT LIMITING THE FOREGOING, THIRD PARTIES MAY HAVE POSTED SOFTWARE, MATERIAL OR CONTENT TO THIS REPOSITORY WITHOUT ANY WARRANTY OF ANY KIND, INCLUDING THAT THE CONTENT IS FREE OF DEFECTS, MERCHANTABLE, FIT FOR A PARTICULAR PURPOSE OR NON-INFRINGING. ANY OPEN SOURCE SOFTWARE IS PROVIDED BY THE APPLICABLE LICENSOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
