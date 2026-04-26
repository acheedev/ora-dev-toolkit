CREATE OR REPLACE PACKAGE otk$log_json IS

    c_level_error CONSTANT VARCHAR2(10) := 'ERROR';
    c_level_warn  CONSTANT VARCHAR2(10) := 'WARN';
    c_level_info  CONSTANT VARCHAR2(10) := 'INFO';
    c_level_debug CONSTANT VARCHAR2(10) := 'DEBUG';

    FUNCTION ctx(p_key VARCHAR2, p_value VARCHAR2) RETURN JSON;
    FUNCTION ctx_merge(p_ctx1 JSON, p_ctx2 JSON) RETURN JSON;

    PROCEDURE error(message IN VARCHAR2, context IN JSON DEFAULT NULL, payload IN JSON DEFAULT NULL);
    PROCEDURE warn (message IN VARCHAR2, context IN JSON DEFAULT NULL, payload IN JSON DEFAULT NULL);
    PROCEDURE info (message IN VARCHAR2, context IN JSON DEFAULT NULL, payload IN JSON DEFAULT NULL);
    PROCEDURE debug(message IN VARCHAR2, context IN JSON DEFAULT NULL, payload IN JSON DEFAULT NULL);

    PROCEDURE purge(p_days IN NUMBER);
    FUNCTION  get_recent(p_limit IN NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION  search(p_keyword IN VARCHAR2) RETURN SYS_REFCURSOR;

END otk$log_json;
/
