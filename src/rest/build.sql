-- REST module build script
-- Run as the target schema owner.
--
-- Prerequisite:
--   @src/clob/build.sql

PROMPT Installing rest module...
PROMPT Prerequisite: otk$clob must already be installed.

@@otk$rest.pks
@@otk$rest.pkb
