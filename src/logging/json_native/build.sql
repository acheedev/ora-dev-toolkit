-- JSON-native logging module build script
-- Run as the target schema owner on Oracle 23ai or later.

PROMPT Installing JSON-native logging module...
PROMPT Requires Oracle 23ai or later.

@@otk_error_log_json.sql
@@otk_error_log_json_biu.sql
@@otk$log_json.pks
@@otk$log_json.pkb
