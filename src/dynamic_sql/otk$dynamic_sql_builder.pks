CREATE OR REPLACE PACKAGE otk$dynamic_sql_builder IS

    ----------------------------------------------------------------------
    -- Constructor: returns a fully initialized query object
    ----------------------------------------------------------------------
    FUNCTION new_query RETURN otk$ds_query_t;

END otk$dynamic_sql_builder;
/
