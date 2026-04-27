CREATE OR REPLACE TYPE otk$ds_query_t AS OBJECT (
     select_list     SYS.ODCIVARCHAR2LIST,
     table_name      VARCHAR2(4000),
     where_clauses   SYS.ODCIVARCHAR2LIST,
     bind_values     SYS.ODCIVARCHAR2LIST,
     order_by_clause VARCHAR2(4000),
     fetch_rows      INTEGER,

     MEMBER FUNCTION select_cols(p_cols SYS.ODCIVARCHAR2LIST) RETURN otk$ds_query_t,
     MEMBER FUNCTION from_table(p_table VARCHAR2) RETURN otk$ds_query_t,
     MEMBER FUNCTION where_clause(p_condition VARCHAR2, p_bind ANYDATA DEFAULT NULL) RETURN otk$ds_query_t,
     MEMBER FUNCTION order_by(p_col VARCHAR2) RETURN otk$ds_query_t,
     MEMBER FUNCTION fetch_first(p_rows INTEGER) RETURN otk$ds_query_t,

     MEMBER PROCEDURE build(p_sql OUT VARCHAR2, p_binds OUT SYS.ODCIVARCHAR2LIST)
 );
 /
