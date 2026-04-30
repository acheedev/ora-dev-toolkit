CREATE OR REPLACE PACKAGE otk$ddl AUTHID CURRENT_USER IS

    ----------------------------------------------------------------------
    -- Compatible with Oracle 12c and later.
    -- Invoker-rights so DDL runs with the privileges of the calling user.
    -- Depends on: otk$assert_utils (identifier validation for DDL execution)
    ----------------------------------------------------------------------

    ----------------------------------------------------------------------
    -- Generic existence check
    -- p_type matches ALL_OBJECTS.OBJECT_TYPE (e.g. 'TABLE','VIEW','PACKAGE BODY')
    -- p_owner defaults to the current schema when NULL
    ----------------------------------------------------------------------
    FUNCTION object_exists(p_name  IN VARCHAR2,
                           p_type  IN VARCHAR2,
                           p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;

    ----------------------------------------------------------------------
    -- Type-specific shortcuts (all delegate to object_exists)
    ----------------------------------------------------------------------
    FUNCTION table_exists   (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
    FUNCTION view_exists    (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
    FUNCTION index_exists   (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
    FUNCTION sequence_exists(p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
    FUNCTION package_exists (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
    FUNCTION type_exists    (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
    FUNCTION trigger_exists (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;

    ----------------------------------------------------------------------
    -- Column and constraint checks
    ----------------------------------------------------------------------
    FUNCTION column_exists(p_table  IN VARCHAR2,
                           p_column IN VARCHAR2,
                           p_owner  IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;

    -- p_table is optional — omit to search all tables in the schema
    FUNCTION constraint_exists(p_constraint IN VARCHAR2,
                               p_table      IN VARCHAR2 DEFAULT NULL,
                               p_owner      IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;

    ----------------------------------------------------------------------
    -- Conditional drop
    -- Silently no-ops if the object does not exist.
    -- Object names are validated via otk$assert_utils before DDL is built.
    ----------------------------------------------------------------------
    PROCEDURE drop_if_exists(p_name  IN VARCHAR2,
                             p_type  IN VARCHAR2,
                             p_owner IN VARCHAR2 DEFAULT NULL);

    PROCEDURE drop_table_if_exists(p_name                IN VARCHAR2,
                                   p_cascade_constraints IN BOOLEAN  DEFAULT FALSE,
                                   p_owner               IN VARCHAR2 DEFAULT NULL);

    ----------------------------------------------------------------------
    -- DDL execution
    -- exec_ddl: raises on failure; appends the DDL text to the error message
    --           so the caller knows exactly what failed.
    -- try_exec: never raises; returns TRUE on success, FALSE on failure
    --           with the error text in p_err.
    ----------------------------------------------------------------------
    PROCEDURE exec_ddl(p_ddl IN VARCHAR2);
    FUNCTION  try_exec(p_ddl IN VARCHAR2, p_err OUT VARCHAR2) RETURN BOOLEAN;

END otk$ddl;
/
