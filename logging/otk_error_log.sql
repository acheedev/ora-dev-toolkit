CREATE TABLE otk_error_log (
    log_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    log_timestamp   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    log_level       VARCHAR2(10) NOT NULL,
    created_by      VARCHAR2(255),
    context_data    CLOB,               -- JSON context
    json_payload    CLOB,               -- JSON payload (request/response/etc.)
    message         VARCHAR2(4000),     -- user-defined message
    sqlerrm_text    VARCHAR2(4000),     -- SQLERRM (only for ERROR)
    error_stack     CLOB,               -- DBMS_UTILITY.format_error_stack
    error_backtrace CLOB                -- DBMS_UTILITY.format_error_backtrace
);
