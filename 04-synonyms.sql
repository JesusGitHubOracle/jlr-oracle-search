
/* Run as json_text user.
  This script will showcase how to use Oracle Text JSON search with synonym expansion through a thesaurus.
  The thesaurus is created using CTX_THES.CREATE_THESAURUS and CTX_THES.CREATE_RELATION.
  The query uses the SYN operator to expand the search term "robot" to include "android" and "cyborg".
*/

 
--cleanup
BEGIN
  CTX_THES.DROP_THESAURUS('movie_thes');
END;
/

-- create a small movie-search thesaurus
BEGIN
  CTX_THES.CREATE_THESAURUS('movie_thes', FALSE);

  CTX_THES.CREATE_RELATION(
    'movie_thes', 'robot', 'SYN', 'android'
  );

  CTX_THES.CREATE_RELATION(
    'movie_thes', 'robot', 'SYN', 'cyborg'
  );
END;
/
-- expands "robot" to include "android" and "cyborg".
SELECT
  JSON_VALUE(data, '$.title' RETURNING VARCHAR2(1000)) AS title,
  SCORE(1) AS relevance
FROM "j_movies"
WHERE JSON_TEXTCONTAINS(
        data,
        '$.plot',
        'SYN(robot, movie_thes)',
        1
      )
ORDER BY SCORE(1) DESC
FETCH FIRST 10 ROWS ONLY;

/*
TITLE                                 RELEVANCE 
__________________________________ ____________ 
Terminator 2: Judgment Day                   24 
Robot Stories                                21 
The Iron Giant                               21 
Real Steel                                   21 
The Questor Tapes                            12 
Ghost in the Shell 2: Innocence              12 
The Terminator                               12 
Galaxina                                     12 
Guyver                                       12 
Bill & Ted's Bogus Journey                   12 

10 rows selected. 
*/