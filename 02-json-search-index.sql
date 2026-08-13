SET echo on
SET serveroutput on size unlimited
SET define on
SET linesize 220
SET pagesize 100
SET long 1000000
set longchunksize 1000000

/* Run as json_text user.  
  This script will do the following:
  -  Load the j_movies JSON collection FROM OCI Object Storage.
     Note: If you are using Oracle AI database instead of Oracle AI Autonomous JSON,  you can populate the JSON collection table using an External Table
     YOU can use the following commands to download the JSON file from OCI Object Storage to your local machine:
       wget -O mflix_movies.json 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/E_Hz1fFFFfbbIGstyg3beN0_WP6QQwwzATe_BsPXhCiGUeaSoH0WjLU7tBZnzglZ/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/search/mflix_movies.json'
       or
       curl -L -o mflix_movies.json 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/E_Hz1fFFFfbbIGstyg3beN0_WP6QQwwzATe_BsPXhCiGUeaSoH0WjLU7tBZnzglZ/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/search/mflix_movies.json'
  - Create JSON search index for text search over the JSON documents.
  -  JSON_TEXTCONTAINS examples for full-text search: Prefix matching and fuzzy search
*/

-- cleanup  
DROP INDEX IF EXISTS "j_movies_text_idx";
DROP TABLE IF EXISTS "j_movies" PURGE;

-- create a JSON collection to hold the documents
BEGIN
  DBMS_CLOUD.copy_collection(
    collection_name => 'j_movies',
    credential_name => NULL,
    file_uri_list   => 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/E_Hz1fFFFfbbIGstyg3beN0_WP6QQwwzATe_BsPXhCiGUeaSoH0WjLU7tBZnzglZ/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/search/mflix_movies.json',
    format          => json_object(
      'recorddelimiter' value '0x''01''',
      'unpackarrays'    value 'true',
      'maxdocsize'      value 67108864
    )
  );
END;
/

--Validate loaded documents...

COLUMN title format a60
COLUMN year format 9999

SELECT count(*) AS document_count
FROM j_movies;

-- retrieve Sample documents

SELECT
  JSON_VALUE(DATA, '$.title' returning varchar2(200)) as title,
  JSON_VALUE(DATA, '$.year' returning number null on error) as year
FROM j_movies
FETCH FIRST 10 ROWS ONLY;


-- Create Oracle Text JSON search index on j_movies. 

CREATE SEARCH INDEX j_movies_text_idx
ON j_movies (DATA)
FOR JSON;

  
-- Full-text search with JSON_TEXTCONTAINS
-- In the below query, the plot field must contain the word Robbery.
COLUMN title format a60
COLUMN plot format a150
COLUMN year format 9999
SELECT
  JSON_VALUE(DATA, '$.title' returning varchar2(200)) as title,
  JSON_VALUE(DATA, '$.plot' returning varchar2(200)) as plot,
  JSON_VALUE(DATA, '$.year' returning number null on error) as year
FROM j_movies
WHERE JSON_TEXTCONTAINS(DATA, '$.plot', 'Robbery')
FETCH FIRST 10 ROWS ONLY;

-- Combining multiple operators with AND, OR, and NOT. 
COLUMN title format a40
COLUMN plot format a140
COLUMN genres format a40
SELECT
  JSON_VALUE(m.data, '$.title' RETURNING VARCHAR2(500)) AS title,
  JSON_VALUE(m.data, '$.plot'  RETURNING VARCHAR2(4000)) AS plot,
  JSON_QUERY(m.data, '$.genres' RETURNING CLOB)          AS genres
FROM j_movies m
WHERE JSON_TEXTCONTAINS(m.data, '$.plot', 'bank robbery', 1)
  AND NOT JSON_TEXTCONTAINS(m.data, '$.genres', '(Comedy OR Romance)')
ORDER BY SCORE(1) DESC
FETCH FIRST 10 ROWS ONLY;

--  prefix matching, typically used for typeahead  
COLUMN title format a40
COLUMN plot format a140
COLUMN genres format a40
SELECT
  JSON_VALUE(m.data, '$.title' RETURNING VARCHAR2(500)) AS title,
  JSON_VALUE(m.data, '$.plot'  RETURNING VARCHAR2(4000)) AS plot,
  JSON_QUERY(m.data, '$.genres' RETURNING CLOB)          AS genres
FROM j_movies m
WHERE JSON_TEXTCONTAINS(m.data, '$.title', 'polit%', 1)
  AND NOT JSON_TEXTCONTAINS(m.data, '$.genres', '(Comedy OR Romance)')
ORDER BY SCORE(1) DESC
FETCH FIRST 10 ROWS ONLY;

-- EXPLAIN PLAN for the above query to show that the Oracle Text index is being used.
EXPLAIN PLAN FOR
SELECT
  JSON_VALUE(data, '$.title' RETURNING VARCHAR2(1000)) AS title
FROM j_movies
WHERE JSON_TEXTCONTAINS(data, '$.title', 'polit%')
FETCH FIRST 10 ROWS ONLY;
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());

/*
------------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                           | Name                  | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib |
------------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                    |                       |    10 | 17310 |    10   (0)| 00:00:01 |        |      |            |
|*  1 |  COUNT STOPKEY                      |                       |       |       |            |          |        |      |            |
|   2 |   PX COORDINATOR                    |                       |       |       |            |          |        |      |            |
|   3 |    PX SEND QC (RANDOM)              | :TQ10001              |    11 | 19041 |    10   (0)| 00:00:01 |  Q1,01 | P->S | QC (RAND)  |
|   4 |     BUFFER SORT                     |                       |    10 | 17310 |            |          |  Q1,01 | PCWP |            |
|*  5 |      COUNT STOPKEY                  |                       |       |       |            |          |  Q1,01 | PCWC |            |
|   6 |       TABLE ACCESS BY INDEX ROWID   | j_movies              |    11 | 19041 |    10   (0)| 00:00:01 |  Q1,01 | PCWP |            |
|   7 |        PX RECEIVE                   |                       |       |       |     4   (0)| 00:00:01 |  Q1,01 | PCWP |            |
|   8 |         PX SEND HASH (BLOCK ADDRESS)| :TQ10000              |       |       |     4   (0)| 00:00:01 |  Q1,00 | S->P | HASH (BLOCK|
|   9 |          PX SELECTOR                |                       |       |       |            |          |  Q1,00 | SCWC |            |
|* 10 |           DOMAIN INDEX              | j_movies_text_idx     |       |       |     4   (0)| 00:00:01 |  Q1,00 |      |            |
------------------------------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   1 - filter(ROWNUM<=10)
   5 - filter(ROWNUM<=10)
  10 - access("CTXSYS"."CONTAINS"("J_MOVIES"."DATA" /*+ LOB_BY_VALUE * ,'(polit%) INPATH (/title)')>0)
*/

-- Fuzzy search using JSON_TEXTCONTAINS  with fuzzy operator and NEAR operator. 
-- The following query will return documents where the title field contains words that are fuzzy matches for "Briget" and "Jons" within 5 words of each other. 
SELECT
  JSON_VALUE(data, '$.title' RETURNING VARCHAR2(1000)) AS title,
  JSON_VALUE(data, '$.plot'  RETURNING VARCHAR2(4000)) AS plot,
  SCORE(1) AS relevance
FROM j_movies
WHERE JSON_TEXTCONTAINS(
        data,
        '$.title',
        'NEAR((fuzzy(Briget,60,100,weight), fuzzy(Jons,50,100,weight)), 5)',
        1
      )
ORDER BY SCORE(1) DESC
FETCH FIRST 10 ROWS ONLY;


/*
TITLE                                PLOT                                                                                                                           RELEVANCE 
____________________________________ ___________________________________________________________________________________________________________________________ ____________ 
Bridget Jones's Diary                A British woman is determined to improve herself while she looks for love in a year in which she keeps a personal diary.              14 
Bridget Jones: The Edge of Reason    After finding love, Bridget Jones questions if she really has everything she's dreamed of having.                                     14
*/
 