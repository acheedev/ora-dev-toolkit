-- ORA_DEV_TOOLKIT Build Script
-- Installs all modules in dependency order
-- Run as the target schema owner

-- 1. dbms_assert (no dependencies — install first)
@src/dbms_assert/otk$assert_utils.pks
@src/dbms_assert/otk$assert_utils.pkb

-- 2. clob (no dependencies)
@src/clob/otk$clob.pks
@src/clob/otk$clob.pkb

-- 3. convert (no dependencies)
@src/convert/otk$convert.pks
@src/convert/otk$convert.pkb

-- 4. json (no dependencies)
@src/json/otk$json.pks
@src/json/otk$json.pkb

-- 5. rest (depends on clob)
@src/rest/otk$rest.pks
@src/rest/otk$rest.pkb

-- 6. ddl (depends on dbms_assert)
@src/ddl/otk$ddl.pks
@src/ddl/otk$ddl.pkb

-- 7. dynamic_sql (depends on dbms_assert)
@src/dynamic_sql/otk$ds_query_t_s.sql
@src/dynamic_sql/otk$ds_query_t_b.sql
@src/dynamic_sql/otk$dynamic_sql_builder.pks
@src/dynamic_sql/otk$dynamic_sql_builder.pkb

-- 8. ansible (depends on clob, json, rest)
@src/ansible/otk$ansible.pks
@src/ansible/otk$ansible.pkb

-- 9. logging — classic CLOB engine (no dependencies)
@src/logging/otk_error_log.sql
@src/logging/otk_error_log_biu.sql
@src/logging/otk$log.pks
@src/logging/otk$log.pkb

-- 10. logging — JSON‑native engine (Oracle 23ai+ only)
@src/logging/json_native/otk_error_log_json.sql
@src/logging/json_native/otk_error_log_json_biu.sql
@src/logging/json_native/otk$log_json.pks
@src/logging/json_native/otk$log_json.pkb
