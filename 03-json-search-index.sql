SET echo on
SET serveroutput on size unlimited
SET define on
SET linesize 220
SET pagesize 100
SET long 1000000
set longchunksize 1000000

/* Run as json_text user.  
   - Create JSON search index for text search over the JSON documents.
  -  JSON_TEXTCONTAINS examples for full-text search: Prefix matching and fuzzy search
*/

-- cleanup  
DROP INDEX IF EXISTS "j_movies_text_idx";

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
WHERE JSON_TEXTCONTAINS(DATA, '$.title', 'Robbery')
FETCH FIRST 10 ROWS ONLY;
/*
TITLE                                                        PLOT                                                                                                                                                    YEAR
------------------------------------------------------------ ------------------------------------------------------------------------------------------------------------------------------------------------------ -----
The Great Train Robbery                                      In Victorian England, a master criminal makes elaborate plans to steal a shipment of gold from a moving train.                                          1978
The Great Diamond Robbery                                    Jeweller Phillippe Golden purchases one of the largest diamonds ever from an auction. Diamond thief Rick Dunne is released from prison to consult in c  1992
                                                             onstructing safety precautions. However...                                                                                                                  

Great Communist Bank Robbery                                 In 1959, in Romania, six former members of the nomenklatura and the secret police organize a hold up of the National Bank. After their arrest, the sta  2004
                                                             te forces them to play themselves in a ...                                                                                                                  

Great Communist Bank Robbery                                 In 1959, in Romania, six former members of the nomenklatura and the secret police organize a hold up of the National Bank. After their arrest, the sta  2004
                                                             te forces them to play themselves in a ...                                                                                                                  

The Great Train Robbery                                      A group of bandits stage a brazen train hold-up, only to find a determined posse hot on their heels.                                                    1903

 
The Great St. Trinian's Train Robbery                        The all-girl school foil an attempt by train robbers to recover two and a half million pounds hidden in their school.                                   1966
Robbery                                                      A dramatization of the Great Train Robbery. While not a 'how to', it is very detail dependent, showing the care and planning that took place to pull i  1967
                                                             t off.                                                                                                                                                      


*/


-- Combining multiple operators with AND, OR, and NOT. 
COLUMN title format a40
COLUMN plot format a140
COLUMN genres format a40
SELECT
  JSON_VALUE(m.data, '$.title' RETURNING VARCHAR2(500)) AS title,
  JSON_VALUE(m.data, '$.plot'  RETURNING VARCHAR2(4000)) AS plot,
  JSON_QUERY(m.data, '$.genres' RETURNING CLOB)          AS genres
FROM j_movies m
WHERE JSON_TEXTCONTAINS(m.data, '$.title', 'bank robbery', 1)
  AND NOT JSON_TEXTCONTAINS(m.data, '$.genres', '(Comedy OR Romance)')
ORDER BY SCORE(1) DESC
FETCH FIRST 10 ROWS ONLY;

/*

TITLE                                                        PLOT                                                                                                                                                    YEAR
------------------------------------------------------------ ------------------------------------------------------------------------------------------------------------------------------------------------------ -----
The Great Train Robbery                                      In Victorian England, a master criminal makes elaborate plans to steal a shipment of gold from a moving train.                                          1978
The Great Diamond Robbery                                    Jeweller Phillippe Golden purchases one of the largest diamonds ever from an auction. Diamond thief Rick Dunne is released from prison to consult in c  1992
                                                             onstructing safety precautions. However...                                                                                                                  

Great Communist Bank Robbery                                 In 1959, in Romania, six former members of the nomenklatura and the secret police organize a hold up of the National Bank. After their arrest, the sta  2004
                                                             te forces them to play themselves in a ...                                                                                                                  

Great Communist Bank Robbery                                 In 1959, in Romania, six former members of the nomenklatura and the secret police organize a hold up of the National Bank. After their arrest, the sta  2004
                                                             te forces them to play themselves in a ...                                                                                                                  

The Great Train Robbery                                      A group of bandits stage a brazen train hold-up, only to find a determined posse hot on their heels.                                                    1903

TITLE                                                        PLOT                                                                                                                                                    YEAR
------------------------------------------------------------ ------------------------------------------------------------------------------------------------------------------------------------------------------ -----
The Great St. Trinian's Train Robbery                        The all-girl school foil an attempt by train robbers to recover two and a half million pounds hidden in their school.                                   1966
Robbery                                                      A dramatization of the Great Train Robbery. While not a 'how to', it is very detail dependent, showing the care and planning that took place to pull i  1967
                                                             t off.                                                                                                                                                      

*/
--  prefix matching, typically used for typeahead  
COLUMN title format a40
COLUMN plot format a140
COLUMN genres format a40
SELECT
  JSON_VALUE(m.data, '$.title' RETURNING VARCHAR2(500)) AS title,
  JSON_VALUE(m.data, '$.plot'  RETURNING VARCHAR2(4000)) AS plot,
  JSON_QUERY(m.data, '$.genres' RETURNING CLOB)          AS genres
FROM j_movies m
WHERE JSON_TEXTCONTAINS(m.data, '$.title', 'politi%', 1)
  AND NOT JSON_TEXTCONTAINS(m.data, '$.genres', '(Comedy OR Romance)')
ORDER BY SCORE(1) DESC
FETCH FIRST 10 ROWS ONLY;

/*
COLUMN title format a40
COLUMN plot format a140
COLUMN genres format a40
SELECT
  JSON_VALUE(m.data, '$.title' RETURNING VARCHAR2(500)) AS title,
  JSON_VALUE(m.data, '$.plot'  RETURNING VARCHAR2(4000)) AS plot,
  JSON_QUERY(m.data, '$.genres' RETURNING CLOB)          AS genres
FROM j_movies m
WHERE JSON_TEXTCONTAINS(m.data, '$.title', 'politi%', 1)
  AND NOT JSON_TEXTCONTAINS(m.data, '$.genres', '(Comedy OR Romance)')
ORDER BY SCORE(1) DESC
FETCH FIRST 10 ROWS ONLY;

*/

-- EXPLAIN PLAN for the above query to show that the Oracle Text index is being used.
EXPLAIN PLAN FOR
SELECT
  JSON_VALUE(data, '$.title' RETURNING VARCHAR2(1000)) AS title
FROM j_movies
WHERE JSON_TEXTCONTAINS(data, '$.title', 'politi%')
FETCH FIRST 10 ROWS ONLY;
SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY());

/*
 
--------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                           | Name              | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib |
--------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                    |                   |    10 | 16860 |    10   (0)| 00:00:01 |        |      |            |
|*  1 |  COUNT STOPKEY                      |                   |       |       |            |          |        |      |            |
|   2 |   PX COORDINATOR                    |                   |       |       |            |          |        |      |            |
|   3 |    PX SEND QC (RANDOM)              | :TQ10001          |    11 | 18546 |    10   (0)| 00:00:01 |  Q1,01 | P->S | QC (RAND)  |
|   4 |     BUFFER SORT                     |                   |    10 | 16860 |            |          |  Q1,01 | PCWP |            |
|*  5 |      COUNT STOPKEY                  |                   |       |       |            |          |  Q1,01 | PCWC |            |
|   6 |       TABLE ACCESS BY INDEX ROWID   | J_MOVIES          |    11 | 18546 |    10   (0)| 00:00:01 |  Q1,01 | PCWP |            |
|   7 |        PX RECEIVE                   |                   |       |       |     4   (0)| 00:00:01 |  Q1,01 | PCWP |            |
|   8 |         PX SEND HASH (BLOCK ADDRESS)| :TQ10000          |       |       |     4   (0)| 00:00:01 |  Q1,00 | S->P | HASH (BLOCK|
|   9 |          PX SELECTOR                |                   |       |       |            |          |  Q1,00 | SCWC |            |
|* 10 |           DOMAIN INDEX              | J_MOVIES_TEXT_IDX |       |       |     4   (0)| 00:00:01 |  Q1,00 |      |            |
--------------------------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   1 - filter(ROWNUM<=10)
   5 - filter(ROWNUM<=10)
  -- 10 - access("CTXSYS"."CONTAINS"("J_MOVIES"."DATA" /*+ LOB_BY_VALUE */ ,'(politi%) INPATH (/title)')>0)
 
Note
-----
   -- automatic DOP: Computed Degree of Parallelism is 2 because of degree limit
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
 