-- ORA_DEV_TOOLKIT Build Script
-- Installs all modules in dependency order.
-- Run as the target schema owner.

-- 1. dbms_assert (no dependencies; install first)
@@dbms_assert/build.sql

-- 2. clob (no dependencies)
@@clob/build.sql

-- 3. convert (no dependencies)
@@convert/build.sql

-- 4. json (no dependencies)
@@json/build.sql

-- 5. rest (depends on clob)
@@rest/build.sql

-- 6. ddl (depends on dbms_assert)
@@ddl/build.sql

-- 7. dynamic_sql (depends on dbms_assert)
@@dynamic_sql/build.sql

-- 8. ansible (depends on clob, json, rest)
@@ansible/build.sql

-- 9. logging - classic CLOB engine (no dependencies)
--@@logging/build.sql

-- 10. logging - JSON-native engine (Oracle 23ai+ only)
@@logging/json_native/build.sql
