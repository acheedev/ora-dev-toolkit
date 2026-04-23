CREATE OR REPLACE PACKAGE otk$log IS

    ----------------------------------------------------------------------
    -- Logging levels
    ----------------------------------------------------------------------
    c_level_error CONSTANT VARCHAR2(10) := 'ERROR';
    c_level_warn  CONSTANT VARCHAR2(10) := 'WARN';
    c_level_info  CONSTANT VARCHAR2(10) := 'INFO';
    c_level_debug CONSTANT VARCHAR2(10) := 'DEBUG';

    ----------------------------------------------------------------------
    -- Global log level (default = INFO)
    ----------------------------------------------------------------------
    PROCEDURE set_level(p_level IN VARCHAR2);
    FUNCTION  get_level RETURN VARCHAR2;

    ----------------------------------------------------------------------
    -- Context management (v3)
    ----------------------------------------------------------------------
    PROCEDURE context(p_key IN VARCHAR2, p_value IN VARCHAR2);
    PROCEDURE clear_context;

    -- JSON API
    PROCEDURE json(p_json IN CLOB);

    ----------------------------------------------------------------------
    -- Logging API
    ----------------------------------------------------------------------
    PROCEDURE error(p_message IN VARCHAR2 DEFAULT NULL);
    PROCEDURE warn (p_message IN VARCHAR2);
    PROCEDURE info (p_message IN VARCHAR2);
    PROCEDURE debug(p_message IN VARCHAR2);

    ----------------------------------------------------------------------
    -- Utilities
    ----------------------------------------------------------------------
    PROCEDURE purge(p_days IN NUMBER);
    FUNCTION  get_recent(p_limit IN NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION  search(p_keyword IN VARCHAR2) RETURN SYS_REFCURSOR;

END otk$log;
/
