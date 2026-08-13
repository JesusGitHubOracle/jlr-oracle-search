SET echo on
SET serveroutput on size unlimited
SET define on
SET linesize 220
SET pagesize 100
SET long 1000000
set longchunksize 1000000

/* Run as json_text user. 
 This script will showcase how to use Oracle Text JSON search with prefix matching using a precomputed materialized view. 
 This avoids the need to extract the title from the JSON document at query time, which is more efficient for prefix matching.
*/
-- cleanup
DROP INDEX j_movies_title_ac_idx;
DROP MATERIALIZED VIEW j_movies_title_ac_mv;

BEGIN
  CTX_DDL.drop_preference('mflix_title_ac_wordlist');
END;
/


--  Create a wordlist optimized for prefixes of 3–12 characters
BEGIN
  CTX_DDL.CREATE_PREFERENCE(
    'mflix_title_ac_wordlist',
    'BASIC_WORDLIST'
  );

  CTX_DDL.SET_ATTRIBUTE(
    'mflix_title_ac_wordlist', 'PREFIX_INDEX', 'TRUE'
  );

  CTX_DDL.SET_ATTRIBUTE(
    'mflix_title_ac_wordlist', 'PREFIX_MIN_LENGTH', '3'
  );

  CTX_DDL.SET_ATTRIBUTE(
    'mflix_title_ac_wordlist', 'PREFIX_MAX_LENGTH', '12'
  );
END;
/

 

--  Create the title-only materialized view
CREATE MATERIALIZED VIEW j_movies_title_ac_mv
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS
SELECT
  rowid AS source_rowid,
  JSON_VALUE(
    DATA  ,
    '$.title'
    RETURNING VARCHAR2(1000)
    NULL ON EMPTY
    NULL ON ERROR
  ) AS title_autocomplete
FROM j_movies
WHERE JSON_VALUE(
        DATA,
        '$.title'
        RETURNING VARCHAR2(1000)
        NULL ON EMPTY
        NULL ON ERROR
      ) is not null;

-- Create the prefix-optimized Oracle Text index.
CREATE INDEX j_movies_title_ac_idx
  ON j_movies_title_ac_mv (title_autocomplete)
  INDEXTYPE IS ctxsys.context
  PARAMETERS (
    'WORDLIST mflix_title_ac_wordlist
     SYNC (ON COMMIT)'
  );

-- Test query for the prefix 'politi'
COLUMN title format a60
SELECT
  title_autocomplete AS title,
  score(1) AS relevance
FROM j_movies_title_ac_mv
WHERE contains(title_autocomplete, 'politi%', 1) > 0
ORDER BY score(1) DESC
FETCH FIRST 10 ROWS ONLY;

/* 
 TITLE                                                           RELEVANCE 
____________________________________________________________ ____________ 
Beyond Gay: The Politics of Pride                                      15 
Political Animals                                                      15 
The Power of Nightmares: The Rise of the Politics of Fear              15 
 */

 
EXPLAIN PLAN FOR
SELECT
  title_autocomplete AS title,
  score(1) AS relevance
FROM j_movies_title_ac_mv
WHERE contains(title_autocomplete, 'politi%', 1) > 0
ORDER BY score(1) DESC
FETCH FIRST 10 ROWS ONLY;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format=>'all'));

/*
 ---------------------------------------------------------------------------------------------------------------------------------------------    
| Id  | Operation                              | Name                  | Rows  | Bytes | Cost (%CPU)| Time     |    TQ  |IN-OUT| PQ Distrib |    
---------------------------------------------------------------------------------------------------------------------------------------------    
|   0 | SELECT STATEMENT                       |                       |    10 |   300 |     8  (13)| 00:00:01 |        |      |            |    
|*  1 |  COUNT STOPKEY                         |                       |       |       |            |          |        |      |            |    
|   2 |   PX COORDINATOR                       |                       |       |       |            |          |        |      |            |    
|   3 |    PX SEND QC (ORDER)                  | :TQ10002              |    10 |   300 |     8  (13)| 00:00:01 |  Q1,02 | P->S | QC (ORDER) |    
|   4 |     VIEW                               |                       |    10 |   300 |     8  (13)| 00:00:01 |  Q1,02 | PCWP |            |    
|*  5 |      SORT ORDER BY STOPKEY             |                       |    10 |   270 |     8  (13)| 00:00:01 |  Q1,02 | PCWP |            |    
|   6 |       PX RECEIVE                       |                       |    10 |   300 |            |          |  Q1,02 | PCWP |            |    
|   7 |        PX SEND RANGE                   | :TQ10001              |    10 |   300 |            |          |  Q1,01 | P->P | RANGE      |    
|*  8 |         SORT ORDER BY STOPKEY          |                       |    10 |   300 |            |          |  Q1,01 | PCWP |            |    
|   9 |          MAT_VIEW ACCESS BY INDEX ROWID| J_MOVIES_TITLE_AC_MV  |    10 |   270 |     7   (0)| 00:00:01 |  Q1,01 | PCWP |            |    
|  10 |           PX RECEIVE                   |                       |       |       |     5   (0)| 00:00:01 |  Q1,01 | PCWP |            |    
|  11 |            PX SEND HASH (BLOCK ADDRESS)| :TQ10000              |       |       |     5   (0)| 00:00:01 |  Q1,00 | S->P | HASH (BLOCK|    
|  12 |             PX SELECTOR                |                       |       |       |            |          |  Q1,00 | SCWC |            |    
|* 13 |              DOMAIN INDEX              | J_MOVIES_TITLE_AC_IDX |       |       |     5   (0)| 00:00:01 |  Q1,00 |      |            |    
---------------------------------------------------------------------------------------------------------------------------------------------    
*/