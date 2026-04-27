-- Ansible module build script
-- Run as the target schema owner.
--
-- Prerequisites:
--   @src/clob/build.sql
--   @src/json/build.sql
--   @src/rest/build.sql

PROMPT Installing ansible module...
PROMPT Prerequisites: otk$clob, otk$json, and otk$rest must already be installed.

@@otk$ansible.pks
@@otk$ansible.pkb
