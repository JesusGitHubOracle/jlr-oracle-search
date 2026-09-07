--  Script to Create a JSON Collection Table,  first we will create an external table to load the JSON documents from a PAR file in OCI Object Storage or from a local file system. 
--  Then we will create a JSON collection table to hold the documents. 
--  The collection table will be used to create an Oracle Text search index for full-text search over the JSON documents.  
 
 -- Cleanup any existing tables and indexes
DROP TABLE mflix_movies_ext;
DROP TABLE j_movies CASCADE CONSTRAINTS PURGE;



-- Option 1: if Oracle ADB
-- OCI PAR URL for the movies.ndjson file in OCI Object Storage.  

define movies_par_url = 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/AZGoEtDMDnDRjsdPNiB9ARjn9kUTnHL9YV_xBcDx71bET11_EnHooQCv0Pn0sdOo/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/search/movies.ndjson';

BEGIN
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'mflix_movies_ext',
    credential_name => NULL,  -- use NULL for a PAR URL
    format          => JSON_OBJECT('type' VALUE 'jsondoc'),
    file_uri_list   => '&&movies_par_url'
  );
END;


select count(*) from mflix_movies_ext;

/* 21349 */


-- option 2,  if your deployment is  Oracle AI Database 26ai
 

DROP TABLE mflix_movies_ext;
DROP TABLE j_movies CASCADE CONSTRAINTS PURGE;

CREATE TABLE mflix_movies_ext (
  data JSON
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_BIGDATA
  DEFAULT DIRECTORY movies_dir
  ACCESS PARAMETERS (
    com.oracle.bigdata.fileformat = jsondoc 
  )
  LOCATION (movies_dir:'movies.ndjson')
)
PARALLEL
REJECT LIMIT UNLIMITED;

select count(*) from mflix_movies_ext;

/* 21349 */


-- Create the collection table to hold the JSON documents.  The collection table will be used to create the Oracle Text search index.

CREATE JSON COLLECTION TABLE j_movies;

INSERT INTO j_movies
SELECT *
FROM mflix_movies_ext;
commit;
SELECT count(*) AS document_count
FROM j_movies;


WITH collection_objects AS (
  SELECT table_name AS object_name
  FROM   user_tables
  WHERE  table_name = 'J_MOVIES'
  UNION
  SELECT index_name
  FROM   user_indexes
  WHERE  table_name = 'J_MOVIES'
  UNION
  SELECT segment_name
  FROM   user_lobs
  WHERE  table_name = 'J_MOVIES'
  UNION
  SELECT index_name
  FROM   user_lobs
  WHERE  table_name = 'J_MOVIES'
)
SELECT ROUND(SUM(s.bytes) / 1024 / 1024, 2) AS collection_allocated_mb
FROM   collection_objects o
JOIN   user_segments s
       ON s.segment_name = o.object_name;
-- 
WITH collection_objects AS (
  SELECT table_name AS object_name, 'table' AS object_kind
  FROM   user_tables
  WHERE  table_name = 'J_MOVIES'

  UNION ALL

  SELECT index_name, 'index'
  FROM   user_indexes
  WHERE  table_name = 'J_MOVIES'

  UNION ALL

  SELECT segment_name, 'JSON/LOB data'
  FROM   user_lobs
  WHERE  table_name = 'J_MOVIES'

  UNION ALL

  SELECT index_name, 'JSON/LOB index'
  FROM   user_lobs
  WHERE  table_name = 'J_MOVIES'
)
SELECT o.object_kind,
       s.segment_type,
       s.segment_name,
       ROUND(s.bytes / 1024 / 1024, 2) AS allocated_mb
FROM   collection_objects o
JOIN   user_segments s
       ON s.segment_name = o.object_name
ORDER  BY o.object_kind, s.segment_type, s.segment_name;

/*
  COUNT(*)
----------
     21349


JSON collection table J_MOVIES created.


21,349 rows inserted.


Commit complete.


DOCUMENT_COUNT
--------------
         21349


COLLECTION_ALLOCATED_MB
-----------------------
                  50.25


OBJECT_KIND    SEGMENT_TYPE       SEGMENT_NAME                                                                                                                     ALLOCATED_MB
-------------- ------------------ -------------------------------------------------------------------------------------------------------------------------------- ------------
JSON/LOB data  LOBSEGMENT         SYS_LOB0000347698C00003$$                                                                                                                1.25
JSON/LOB index LOBINDEX           SYS_IL0000347698C00003$$                                                                                                                  .06
index          INDEX              SYS_C0042861                                                                                                                              .94
index          LOBINDEX           SYS_IL0000347698C00003$$                                                                                                                  .06
table          TABLE              J_MOVIES                                                                                                                                   48
*/