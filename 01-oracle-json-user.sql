 

/* Run this script as Admin  user. 
 This script will create a new user json_text with the required privileges to run the other scripts in this repository. 
 It will also enable ORDS for the user (optional), just in case you want to use the Oracle API for MongoDB to access the JSON collection.
The user will be created with a password of DB23ee###12345. You can change this password in the script if you wish.
*/

DROP USER IF EXISTS json_text CASCADE;
CREATE USER json_text IDENTIFIED BY DB23ee###12345;
ALTER USER json_text QUOTA UNLIMITED ON DATA;

 
GRANT CONNECT, RESOURCE, SODA_APP, DB_DEVELOPER_ROLE TO json_text;
GRANT EXECUTE ON DBMS_CLOUD TO json_text;
GRANT READ, WRITE ON DIRECTORY data_pump_dir TO json_text;

-- Grants Required for Oracle Text indexes  
GRANT CTXAPP TO json_text;
GRANT EXECUTE ON CTXSYS.CTX_QUERY TO json_text;
GRANT EXECUTE ON CTXSYS.CTX_DDL   TO json_text;
GRANT EXECUTE ON CTXSYS.CTX_THES  TO json_text; 


--   Enable ORDS (Optional)
BEGIN
  ords_admin.enable_schema(
    p_enabled             => TRUE,
    p_schema              => 'json_text',
    p_url_mapping_pattern => 'json_text'
  );
  COMMIT;
END;
/

