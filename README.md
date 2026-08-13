# JSON Full-Text Search with Oracle AI Database 26ai

Oracle AI Database supports JSON data natively with relational database features, including transactions, indexing, declarative querying, and views. JSON data can be stored in the database, indexed, and queried without any need for a schema that defines the data.

You can use the Oracle SQL condition `JSON_TEXTCONTAINS` to perform full-text searches over JSON while keeping the JSON data in the Oracle Database.

A JSON search index is an Oracle Text index designed specifically for JSON data. It enables efficient word and phrase searches within JSON documents. After creating a JSON search index, you can use the PL/SQL procedure `CTX_QUERY.RESULT_SET` to perform faceted searches over JSON data.

This repository uses a movies dataset and SQL scripts to demonstrate JSON full-text search features, including relevance scoring, prefix matching, fuzzy matching, thesaurus-based synonym expansion, and faceted search over JSON data.

## Prerequisites

Oracle AI Database 26ai on any platform or Autonomous AI Database,  you can find more information on the below links:
* [Oracle AI Autonomous JSON Database](https://www.oracle.com/autonomous-database/autonomous-json-database/)
* [Oracle AI Database 26ai](https://www.oracle.com/database/technologies/oracle-database-software-downloads.html)

### Scripts

#### `01-oracle-json-user.sql`

Creates the `JSON_TEXT` schema and grants the privileges required to manage Oracle Text indexes. It can also enable the schema for access through Oracle REST Data Services (ORDS), if you want to use the Oracle Database API for MongoDB.

#### `02-json-search-index.sql`

Loads the sample dataset into an Oracle JSON collection table. The file is a top-level JSON array, so the script uses `unpackarrays` to load each movie as a document and sets `maxdocsize` to 64 MiB to accommodate the complete source array.

It then creates a JSON search index and includes examples of:

* `JSON_TEXTCONTAINS` for full-text search on JSON fields
* Relevance ranking with `SCORE()`
* Prefix matching
* Fuzzy matching  
* Execution-plan inspection to confirm the Oracle Text domain index is used

#### `03-prefix-matching-mv.sql`

Creates a title-only materialized view and an Oracle Text `CONTEXT` index over it. The `BASIC_WORDLIST` preference enables prefix indexing for three- to twelve-character prefixes, providing an efficient type-ahead pattern.

The materialized view uses `REFRESH COMPLETE ON DEMAND`. Refresh it after a collection reload:

```sql
BEGIN
  DBMS_MVIEW.REFRESH('J_MOVIES_TITLE_AC_MV', 'C');
END;
/
```

### `04-synonyms.sql`

Creates an Oracle Text thesaurus to store synonyms. This  improves search recall by expanding queries to match equivalent terms (e.g., searching for "robot" also returns "android" and "cyborg").

### `05-facet-search.sql`

Uses `CTX_QUERY.RESULT_SET` to find movies whose plot contains a given search term. It returns the first ten matches together with genre and rating facets, year buckets, and an average IMDb rating.

## Reference documentation

* [Loading an array of JSON documents with DBMS_CLOUD](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-json-load-arrays-unpack.html)
* [Oracle SQL Condition JSON_TEXTCONTAINS](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/oracle-sql-condition-json_textcontains.html)
* [Oracle Text query operators](https://docs.oracle.com/en/database/oracle/oracle-database/19/ccref/oracle-text-CONTAINS-query-operators.html)
* [Oracle Text thesaurus features](https://docs.oracle.com/en/database/oracle/oracle-database/23/ccapp/overview-oracle-text-thesaurus-features.html)
* [Overview of the JSON Result Set Interface](https://docs.oracle.com/en/database/oracle/oracle-database/26/ccapp/overview-json-result-set-interface.html)
* [JSON facet search with CTX_QUERY.RESULT_SET](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/json-facet-search-pl-sql-procedure-ctx_query-result_set.html)
* [Oracle Text users and roles](https://docs.oracle.com/en/database/oracle/oracle-database/26/ccapp/oracle-text-users-and-roles.html)
* [Oracle JSON: From relational to document store](https://github.com/JesusGitHubOracle/jlr-oracle-json)
