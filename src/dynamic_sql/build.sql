-- Dynamic SQL module build script
-- Run as the target schema owner.
--
-- Prerequisite:
--   @src/dbms_assert/build.sql

PROMPT Installing dynamic_sql module...
PROMPT Prerequisite: otk$assert_utils must already be installed.

@@otk$ds_query_t_s.sql
@@otk$ds_query_t_b.sql
@@otk$dynamic_sql_builder.pks
@@otk$dynamic_sql_builder.pkb
