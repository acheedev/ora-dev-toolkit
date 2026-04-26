CREATE OR REPLACE PACKAGE otk$log IS

    ----------------------------------------------------------------------
    -- Logging levels
    ----------------------------------------------------------------------
    c_level_error CONSTANT VARCHAR2(10) := 'ERROR';
    c_level_warn  CONSTANT VARCHAR2(10) := 'WARN';
    c_level_info  CONSTANT VARCHAR2(10) := 'INFO';
    c_level_debug CONSTANT VARCHAR2(10) := 'DEBUG';

    ----------------------------------------------------------------------
    -- Stateless context helpers
    ----------------------------------------------------------------------
    FUNCTION ctx(p_key VARCHAR2, p_value VARCHAR2) RETURN CLOB;
    FUNCTION ctx_merge(p_ctx1 CLOB, p_ctx2 CLOB) RETURN CLOB;

    ----------------------------------------------------------------------
    -- Stateless logging API
    ----------------------------------------------------------------------
    PROCEDURE error(
        message IN VARCHAR2,
        context IN CLOB DEFAULT NULL,
        payload IN CLOB DEFAULT NULL
    );

    PROCEDURE warn(
        message IN VARCHAR2,
        context IN CLOB DEFAULT NULL,
        payload IN CLOB DEFAULT NULL
    );

    PROCEDURE info(
        message IN VARCHAR2,
        context IN CLOB DEFAULT NULL,
        payload IN CLOB DEFAULT NULL
    );

    PROCEDURE debug(
        message IN VARCHAR2,
        context IN CLOB DEFAULT NULL,
        payload IN CLOB DEFAULT NULL
    );

    ----------------------------------------------------------------------
    -- Utilities
    ----------------------------------------------------------------------
    PROCEDURE purge(p_days IN NUMBER);
    FUNCTION  get_recent(p_limit IN NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION  search(p_keyword IN VARCHAR2) RETURN SYS_REFCURSOR;

END otk$log;
/
