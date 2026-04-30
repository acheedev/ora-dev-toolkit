CREATE OR REPLACE PACKAGE BODY otk$assert_utils IS

    FUNCTION simple_name(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.simple_sql_name(p_name);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20002,
                'Invalid identifier: "' || p_name || '". ' ||
                'Identifiers must be valid SQL names (alphanumeric, underscore, no spaces or special characters).'
            );
    END;

    FUNCTION object_name(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.sql_object_name(p_name);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Invalid object name: "' || p_name || '". ' ||
                'Expected format: [schema.]object_name. ' ||
                'Table must exist in the database.'
            );
    END;

    FUNCTION schema_name(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.schema_name(p_name);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20003,
                'Invalid schema name: "' || p_name || '". ' ||
                'Schema names must be valid SQL identifiers.'
            );
    END;

    FUNCTION literal(p_value VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.enquote_literal(REPLACE(p_value, '''', ''''''));
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20004,
                'Failed to quote literal value. The value may be too long or contain invalid characters.'
            );
    END;

    FUNCTION enquote(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.enquote_name(p_name);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(
                -20005,
                'Failed to quote identifier: "' || p_name || '". ' ||
                'The name may be too long or contain invalid characters.'
            );
    END;

END otk$assert_utils;
/
