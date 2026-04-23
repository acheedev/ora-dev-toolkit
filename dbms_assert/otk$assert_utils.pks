CREATE OR REPLACE PACKAGE otk$assert_utils IS

    -- Validate a simple identifier (column, table, index, constraint)
    FUNCTION simple_name(p_name VARCHAR2) RETURN VARCHAR2;

    -- Validate a schema-qualified SQL object name (table, view, index, etc.)
    FUNCTION object_name(p_name VARCHAR2) RETURN VARCHAR2;

    -- Validate a schema name only
    FUNCTION schema_name(p_name VARCHAR2) RETURN VARCHAR2;

    -- Safely quote a literal value
    FUNCTION literal(p_value VARCHAR2) RETURN VARCHAR2;

    -- Safely quote an identifier (case-sensitive or special chars)
    FUNCTION enquote(p_name VARCHAR2) RETURN VARCHAR2;

END otk$assert_utils;
/
