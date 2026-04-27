-- ORA_DEV_TOOLKIT Build Script
-- Installs all modules in dependency order
-- Run as the target schema owner

-- 1. dbms_assert (no dependencies — install first)
@@dbms_assert/otk$assert_utils.pks
@@dbms_assert/otk$assert_utils.pkb

-- 2. clob (no dependencies)
@@clob/otk$clob.pks
@@clob/otk$clob.pkb

-- 3. convert (no dependencies)
@@convert/otk$convert.pks
@@convert/otk$convert.pkb

-- 4. json (no dependencies)
@@json/otk$json.pks
@@json/otk$json.pkb

-- 5. rest (depends on clob)
@@rest/otk$rest.pks
@@rest/otk$rest.pkb

-- 6. ddl (depends on dbms_assert)
@@ddl/otk$ddl.pks 
@@ddl/otk$ddl.pkb

-- 7. dynamic_sql (depends on dbms_assert)
@@dynamic_sql/otk$ds_query_t_s.sql
@@dynamic_sql/otk$ds_query_t_b.sql
@@dynamic_sql/otk$dynamic_sql_builder.pks
@@dynamic_sql/otk$dynamic_sql_builder.pkb

-- 8. ansible (depends on clob, json, rest)
@@ansible/otk$ansible.pks
@@ansible/otk$ansible.pkb

-- 9. logging — classic CLOB engine (no dependencies)
@@logging/otk_error_log.sql
@@logging/otk_error_log_biu.sql
@@logging/otk$log.pks
@@logging/otk$log.pkb

-- 10. logging — JSON‑native engine (Oracle 23ai+ only)
@@logging/json_native/otk_error_log_json.sql
@@logging/json_native/otk_error_log_json_biu.sql
@@logging/json_native/otk$log_json.pks
@@logging/json_native/otk$log_json.pkb
