CREATE OR REPLACE PACKAGE BODY otk$assert_utils IS

    FUNCTION simple_name(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.simple_sql_name(p_name);
    END;

    FUNCTION object_name(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.sql_object_name(p_name);
    END;

    FUNCTION schema_name(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.schema_name(p_name);
    END;

    FUNCTION literal(p_value VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.enquote_literal(p_value);
    END;

    FUNCTION enquote(p_name VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN dbms_assert.enquote_name(p_name);
    END;

END otk$assert_utils;
/
