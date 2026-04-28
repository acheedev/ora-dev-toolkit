-- DDL module build script
-- Run as the target schema owner.
--
-- Prerequisite:
--   @src/dbms_assert/build.sql

PROMPT Installing ddl module...
PROMPT Prerequisite: otk$assert_utils must already be installed.

@@otk$ddl.pks
@@otk$ddl.pkb
