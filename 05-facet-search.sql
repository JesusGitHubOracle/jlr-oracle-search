set echo off
set serveroutput off size unlimited
set linesize 220
set pagesize 100
set long 1000000
set longchunksize 1000000

/* Run as json_text user.
 The JSON Result Set Interface lets an application submit a search request as JSON and receive a single JSON CLOB response.
A result-set descriptor defines the requested hits, counts, groupings, and facets. Oracle calculates them together, avoiding repeated query parsing and index lookups, which is especially useful for search pages and interactive filtering.
It works with Oracle Text CONTEXT and JSON search indexes, and supports facet group counts plus aggregates such as COUNT, MIN, MAX, AVG, and SUM (the last two for numeric values).
 
 This script will showcase how to use Oracle Text JSON search with faceted search over the J_MOVIES JSON collection.
 CTX_QUERY.RESULT_SET searches a JSON search index and returns both matchingdocuments and facet calculations in one JSON result.
 String facets (such as genres and rated) require SEARCH_ON TEXT_VALUE_STRING.
*/

--  Run this once. This is a pre-requisite for faceted search 
/*ALTER INDEX j_movies_text_idx REBUILD
  PARAMETERS ('SEARCH_ON TEXT_VALUE_STRING');*/

--  Faceted search with CTX_QUERY.RESULT_SET

variable rs_output clob

DECLARE
  rs_descriptor CLOB := q'~
{
  "$query" : {
    "plot" : { "$contains" : "mystery" }
  },
  "$search" : {
    "start" : 1,
    "end"   : 10
  },
  "$facet" : [
    { "$uniqueCount" : "genres" },
    { "$uniqueCount" : "rated" },
    { "$uniqueCount" : { "path" : "year", "type" : "number" } },
    { "$count" : {
        "path"   : "year",
        "bucket" : [
          { "$lt" : 1950 },
          { "$gte" : 1950, "$lt" : 1980 },
          { "$gte" : 1980 }
        ]
      }
    },
    { "$avg" : "imdb.rating" }
  ]
}~';

BEGIN
  DBMS_LOB.CREATETEMPORARY(:rs_output, TRUE);

  CTX_QUERY.RESULT_SET(
    index_name             => 'j_movies_text_idx',
    query                  => NULL,
    result_set_descriptor  => rs_descriptor,
    result_set             => :rs_output,
    format                 => CTX_QUERY.JSON_FORMAT
  );
END;
/

-- Pretty-print the matching documents and the facet results.
SELECT JSON_QUERY(:rs_output, '$' RETURNING CLOB PRETTY) AS facet_result
FROM dual;

-- RESULT_SET exposes JSON-search hits as rowids. Resolve them to user-facing
-- movie data, retaining the relevance order returned by Oracle Text.
COLUMN title FORMAT A30
COLUMN plot FORMAT A140
COLUMN year FORMAT 9999
COLUMN genres FORMAT A30

WITH search_hits AS (
  SELECT hit_position,
         score,
         rowid_text
  FROM JSON_TABLE(
         :rs_output,
         '$."$hit"[*]'
         COLUMNS (
           hit_position FOR ORDINALITY,
           score        NUMBER       PATH '$.score',
           rowid_text   VARCHAR2(18) PATH '$.rowid'
         )
       )
)
SELECT JSON_VALUE(m.data, '$.title' RETURNING VARCHAR2(1000)) AS title,
       JSON_VALUE(m.data, '$.plot'  RETURNING CLOB NULL ON ERROR) AS plot,
       JSON_VALUE(m.data, '$.year'  RETURNING NUMBER NULL ON ERROR) AS year,
       JSON_QUERY(m.data, '$.genres' RETURNING CLOB) AS genres,
       h.score AS relevance
FROM search_hits h
JOIN j_movies m
  ON m.ROWID = CHARTOROWID(h.rowid_text)
ORDER BY h.hit_position;


/*
TITLE                          PLOT                                                                                                                                          YEAR GENRES                          RELEVANCE
------------------------------ -------------------------------------------------------------------------------------------------------------------------------------------- ----- ------------------------------ ----------
The Guatemalan Handshake       A mysterious power failure in a small mountain town coincides with the disappearance of one of its most eccentric young residents. Mystery p  2006 ["Comedy","Drama"]                     13
                               iles upon mystery as his family and friends ...                                                                                                                                             

Murder, My Sweet               After being hired to find an ex-con's former girlfriend, Philip Marlowe is drawn into a deeply complex web of mystery and deceit.             1944 ["Crime","Drama","Film-Noir"]           7
The Hospital                   Horror/mystery in which an over-burdened doctor struggles to find meaning in his life while a murderer stalks the halls of his hospital.      1971 ["Comedy","Drama","Mystery"]            7
Murder by Death                Five famous literary detective characters and their sidekicks are invited to a bizarre mansion to solve an even stranger mystery.             1976 ["Comedy","Mystery","Thriller"          7
                                                                                                                                                                                  ]                                        

The Last of Sheila             A year after Sheila is killed in a hit-and-run, her multi-millionaire husband invites a group of friends to spend a week on his yacht playin  1973 ["Crime","Drama","Mystery"]             7
                               g a scavenger hunt-style mystery game. The game turns out to be all too real and all too deadly.                                                                                            

Un papillon sur l'èpaule       Mystery film about a man who finds there is another world to the one we know.                                                                 1978 ["Drama","Thriller"]                    7
Who Is Killing the Great Chefs Mystery abounds when it is discovered that, one by one, the greatest Chefs in Europe are being killed. The intriguing part of the murders is  1978 ["Comedy","Mystery","Crime"]            7
of Europe?                     that each chef is killed in the same manner that...                                                                                                                                        

Agatha                         A fictional account of the real life, eleven day, never explained 1926 disappearance of famed murder mystery writer Agatha Christie is prese  1979 ["Drama","Mystery","Thriller"]          7
                               nted. On a cold winter day, her damaged car with ...                                                                                                                                        

Sherlock Holmes in New York    In this mystery, Holmes pursues his arch-enemy Moriarty to New York, which the villainous scoundrel has carried out the ultimate bank robber  1976 ["Crime","Mystery"]                     7
                               y. Meanwhile, Holmes enjoys a blossoming romance ...                                                                                                                                        

The Mirror Crack'd             Jane Marple solves the mystery when a local woman is poisoned and a visiting movie star seems to have been the intended victim.               1980 ["Crime","Mystery","Thriller"]          7
*/



 
