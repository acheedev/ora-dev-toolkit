CREATE OR REPLACE TYPE BODY otk$ds_query_t AS

    ----------------------------------------------------------------------
    -- Add SELECT columns
    ----------------------------------------------------------------------
    MEMBER FUNCTION select_cols(p_cols IN SYS.ODCIVARCHAR2LIST)
        RETURN otk$ds_query_t
    IS
        l_self otk$ds_query_t := SELF;
    BEGIN
        IF p_cols IS NOT NULL THEN
            FOR i IN 1 .. p_cols.COUNT LOOP
                l_self.select_list.EXTEND;
                l_self.select_list(l_self.select_list.COUNT) :=
                    otk$assert_utils.simple_name(p_cols(i));
            END LOOP;
        END IF;

        RETURN l_self;
    END select_cols;


    ----------------------------------------------------------------------
    -- Set FROM table
    ----------------------------------------------------------------------
    MEMBER FUNCTION from_table(p_table IN VARCHAR2)
        RETURN otk$ds_query_t
    IS
        l_self otk$ds_query_t := SELF;
    BEGIN
        l_self.table_name := otk$assert_utils.object_name(p_table);
        RETURN l_self;
    END from_table;


    ----------------------------------------------------------------------
    -- Add WHERE clause + optional bind
    ----------------------------------------------------------------------
    MEMBER FUNCTION where_clause(
        p_condition IN VARCHAR2,
        p_bind      IN ANYDATA
    ) RETURN otk$ds_query_t
    IS
        l_self otk$ds_query_t := SELF;
    BEGIN
        IF p_condition IS NOT NULL THEN
            l_self.where_clauses.EXTEND;
            l_self.where_clauses(l_self.where_clauses.COUNT) := p_condition;
        END IF;

        IF p_bind IS NOT NULL THEN
            l_self.bind_values.EXTEND;
            l_self.bind_values(l_self.bind_values.COUNT) :=
                ANYDATA.AccessVarchar2(p_bind);
        END IF;

        RETURN l_self;
    END where_clause;


    ----------------------------------------------------------------------
    -- ORDER BY
    ----------------------------------------------------------------------
    MEMBER FUNCTION order_by(p_col IN VARCHAR2)
        RETURN otk$ds_query_t
    IS
        l_self otk$ds_query_t := SELF;
    BEGIN
        l_self.order_by_clause := otk$assert_utils.simple_name(p_col);
        RETURN l_self;
    END order_by;


    ----------------------------------------------------------------------
    -- FETCH FIRST n ROWS ONLY
    ----------------------------------------------------------------------
    MEMBER FUNCTION fetch_first(p_rows INTEGER)
        RETURN otk$ds_query_t
    IS
        l_self otk$ds_query_t := SELF;
    BEGIN
        l_self.fetch_rows := p_rows;
        RETURN l_self;
    END fetch_first;


    ----------------------------------------------------------------------
    -- Build final SQL + bind array
    ----------------------------------------------------------------------
    MEMBER PROCEDURE build(
        p_sql   OUT VARCHAR2,
        p_binds OUT SYS.ODCIVARCHAR2LIST
    )
    IS
        l_sql VARCHAR2(32767);
    BEGIN
        ------------------------------------------------------------------
        -- SELECT clause
        ------------------------------------------------------------------
        l_sql := 'SELECT ';

        IF SELF.select_list.COUNT = 0 THEN
            l_sql := l_sql || '*';
        ELSE
            FOR i IN 1 .. SELF.select_list.COUNT LOOP
                IF i > 1 THEN l_sql := l_sql || ', '; END IF;
                l_sql := l_sql || SELF.select_list(i);
            END LOOP;
        END IF;

        ------------------------------------------------------------------
        -- FROM clause
        ------------------------------------------------------------------
        l_sql := l_sql || ' FROM ' || SELF.table_name;

        ------------------------------------------------------------------
        -- WHERE clauses
        ------------------------------------------------------------------
        IF SELF.where_clauses.COUNT > 0 THEN
            l_sql := l_sql || ' WHERE ';
            FOR i IN 1 .. SELF.where_clauses.COUNT LOOP
                IF i > 1 THEN l_sql := l_sql || ' AND '; END IF;
                l_sql := l_sql || SELF.where_clauses(i);
            END LOOP;
        END IF;

        ------------------------------------------------------------------
        -- ORDER BY
        ------------------------------------------------------------------
        IF SELF.order_by_clause IS NOT NULL THEN
            l_sql := l_sql || ' ORDER BY ' || SELF.order_by_clause;
        END IF;

        ------------------------------------------------------------------
        -- FETCH FIRST
        ------------------------------------------------------------------
        IF SELF.fetch_rows IS NOT NULL THEN
            l_sql := l_sql || ' FETCH FIRST ' || SELF.fetch_rows || ' ROWS ONLY';
        END IF;

        ------------------------------------------------------------------
        -- Output
        ------------------------------------------------------------------
        p_sql := l_sql;
        p_binds := SELF.bind_values;

    END build;

END;
/
