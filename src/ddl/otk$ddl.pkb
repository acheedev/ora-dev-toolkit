CREATE OR REPLACE PACKAGE BODY otk$ddl IS

    ----------------------------------------------------------------------
    -- Private: resolve owner to current schema if not supplied
    ----------------------------------------------------------------------
    FUNCTION resolve_owner(p_owner IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN UPPER(NVL(p_owner, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')));
    END resolve_owner;


    ----------------------------------------------------------------------
    -- Generic existence check
    ----------------------------------------------------------------------
    FUNCTION object_exists(
        p_name  IN VARCHAR2,
        p_type  IN VARCHAR2,
        p_owner IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        l_count NUMBER;
        l_owner VARCHAR2(128);
    BEGIN
        l_owner := resolve_owner(p_owner);

        SELECT COUNT(*) INTO l_count
        FROM   all_objects
        WHERE  object_name = UPPER(p_name)
        AND    object_type = UPPER(p_type)
        AND    owner       = l_owner;
        RETURN l_count > 0;
    END object_exists;


    ----------------------------------------------------------------------
    -- Type-specific shortcuts
    ----------------------------------------------------------------------
    FUNCTION table_exists   (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    BEGIN RETURN object_exists(p_name, 'TABLE',    p_owner); END;

    FUNCTION view_exists    (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    BEGIN RETURN object_exists(p_name, 'VIEW',     p_owner); END;

    FUNCTION index_exists   (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    BEGIN RETURN object_exists(p_name, 'INDEX',    p_owner); END;

    FUNCTION sequence_exists(p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    BEGIN RETURN object_exists(p_name, 'SEQUENCE', p_owner); END;

    FUNCTION package_exists (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    BEGIN RETURN object_exists(p_name, 'PACKAGE',  p_owner); END;

    FUNCTION type_exists    (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    BEGIN RETURN object_exists(p_name, 'TYPE',     p_owner); END;

    FUNCTION trigger_exists (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    BEGIN RETURN object_exists(p_name, 'TRIGGER',  p_owner); END;


    ----------------------------------------------------------------------
    -- Column and constraint checks
    ----------------------------------------------------------------------
    FUNCTION column_exists(
        p_table  IN VARCHAR2,
        p_column IN VARCHAR2,
        p_owner  IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        l_count NUMBER;
        l_owner VARCHAR2(128);
    BEGIN
        l_owner := resolve_owner(p_owner);

        SELECT COUNT(*) INTO l_count
        FROM   all_tab_columns
        WHERE  table_name  = UPPER(p_table)
        AND    column_name = UPPER(p_column)
        AND    owner       = l_owner;
        RETURN l_count > 0;
    END column_exists;

    FUNCTION constraint_exists(
        p_constraint IN VARCHAR2,
        p_table      IN VARCHAR2 DEFAULT NULL,
        p_owner      IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        l_count NUMBER;
        l_owner VARCHAR2(128);
    BEGIN
        l_owner := resolve_owner(p_owner);

        SELECT COUNT(*) INTO l_count
        FROM   all_constraints
        WHERE  constraint_name = UPPER(p_constraint)
        AND    owner           = l_owner
        AND    (p_table IS NULL OR table_name = UPPER(p_table));
        RETURN l_count > 0;
    END constraint_exists;


    ----------------------------------------------------------------------
    -- Conditional drop
    ----------------------------------------------------------------------
    PROCEDURE drop_if_exists(
        p_name  IN VARCHAR2,
        p_type  IN VARCHAR2,
        p_owner IN VARCHAR2 DEFAULT NULL
    ) IS
        l_name  VARCHAR2(128) := otk$assert_utils.simple_name(p_name);
        l_ddl   VARCHAR2(500);
    BEGIN
        IF NOT object_exists(p_name, p_type, p_owner) THEN RETURN; END IF;

        l_ddl := 'DROP ' || UPPER(p_type) || ' ';

        IF p_owner IS NOT NULL THEN
            l_ddl := l_ddl || otk$assert_utils.schema_name(p_owner) || '.';
        END IF;

        l_ddl := l_ddl || l_name;

        EXECUTE IMMEDIATE l_ddl;
    END drop_if_exists;

    PROCEDURE drop_table_if_exists(
        p_name                IN VARCHAR2,
        p_cascade_constraints IN BOOLEAN  DEFAULT FALSE,
        p_owner               IN VARCHAR2 DEFAULT NULL
    ) IS
        l_name VARCHAR2(128) := otk$assert_utils.simple_name(p_name);
        l_ddl  VARCHAR2(500);
    BEGIN
        IF NOT table_exists(p_name, p_owner) THEN RETURN; END IF;

        l_ddl := 'DROP TABLE ';

        IF p_owner IS NOT NULL THEN
            l_ddl := l_ddl || otk$assert_utils.schema_name(p_owner) || '.';
        END IF;

        l_ddl := l_ddl || l_name;

        IF p_cascade_constraints THEN
            l_ddl := l_ddl || ' CASCADE CONSTRAINTS';
        END IF;

        EXECUTE IMMEDIATE l_ddl;
    END drop_table_if_exists;


    ----------------------------------------------------------------------
    -- DDL execution
    ----------------------------------------------------------------------
    PROCEDURE exec_ddl(p_ddl IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_ddl;
    EXCEPTION WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            SQLERRM || CHR(10) || 'DDL: ' || SUBSTR(p_ddl, 1, 500)
        );
    END exec_ddl;

    FUNCTION try_exec(p_ddl IN VARCHAR2, p_err OUT VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        EXECUTE IMMEDIATE p_ddl;
        p_err := NULL;
        RETURN TRUE;
    EXCEPTION WHEN OTHERS THEN
        p_err := SQLERRM;
        RETURN FALSE;
    END try_exec;


END otk$ddl;
/
