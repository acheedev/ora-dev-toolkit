CREATE OR REPLACE PACKAGE BODY otk$dynamic_sql_builder IS

    FUNCTION new_query RETURN otk$ds_query_t IS
    BEGIN
        RETURN otk$ds_query_t(
            select_list     => SYS.ODCIVARCHAR2LIST(),
            table_name      => NULL,
            where_clauses   => SYS.ODCIVARCHAR2LIST(),
            bind_values     => SYS.ODCIVARCHAR2LIST(),
            order_by_clause => NULL,
            fetch_rows      => NULL
        );
    END new_query;

END otk$dynamic_sql_builder;
/
