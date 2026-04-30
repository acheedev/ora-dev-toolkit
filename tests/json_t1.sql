SET SERVEROUTPUT ON
DECLARE
    l_pass PLS_INTEGER := 0;
    l_fail PLS_INTEGER := 0;

    l_json CLOB := '{
        "order_id"   : 1001,
        "status"     : "PENDING",
        "order_date" : "2026-04-25",
        "total"      : 2547.50,
        "active"     : true,
        "cancelled"  : false,
        "notes"      : null,
        "customer"   : { "name": "Acme Corp", "tier": "GOLD" },
        "items"      : [
            { "sku": "WDG-001", "qty": 10, "price": 99.99  },
            { "sku": "WDG-002", "qty": 5,  "price": 249.95 },
            { "sku": "WDG-003", "qty": 2,  "price": 499.00 }
        ],
        "tags"       : ["urgent", "fragile", "insured"]
    }';

    l_bad_json  CLOB := '{ not valid json }';
    l_clob      CLOB;
    l_str       VARCHAR2(4000);
    l_num       NUMBER;
    l_date      DATE;
    l_bool      BOOLEAN;

    PROCEDURE ok(p_label VARCHAR2, p_cond BOOLEAN) IS
    BEGIN
        IF p_cond THEN
            DBMS_OUTPUT.put_line('  PASS  ' || p_label);
            l_pass := l_pass + 1;
        ELSE
            DBMS_OUTPUT.put_line('  FAIL  ' || p_label);
            l_fail := l_fail + 1;
        END IF;
    END ok;

BEGIN
    DBMS_OUTPUT.put_line('=== TEST: otk$json ===');
    DBMS_OUTPUT.put_line('');

    --------------------------------------------------------------------------
    -- is_valid
    --------------------------------------------------------------------------
    ok('is_valid: well-formed JSON',   otk$json.is_valid(l_json)     = TRUE);
    ok('is_valid: malformed JSON',     otk$json.is_valid(l_bad_json) = FALSE);
    ok('is_valid: NULL returns false', otk$json.is_valid(NULL)       = FALSE);

    --------------------------------------------------------------------------
    -- get_str
    --------------------------------------------------------------------------
    ok('get_str: top-level string',    otk$json.get_str(l_json, '$.status')         = 'PENDING');
    ok('get_str: nested string',       otk$json.get_str(l_json, '$.customer.name')  = 'Acme Corp');
    ok('get_str: missing path = NULL', otk$json.get_str(l_json, '$.does_not_exist') IS NULL);
    ok('get_str: null value = NULL',   otk$json.get_str(l_json, '$.notes')          IS NULL);

    --------------------------------------------------------------------------
    -- get_num
    --------------------------------------------------------------------------
    ok('get_num: integer',             otk$json.get_num(l_json, '$.order_id') = 1001);
    ok('get_num: decimal',             otk$json.get_num(l_json, '$.total')    = 2547.50);
    ok('get_num: missing = NULL',      otk$json.get_num(l_json, '$.missing')  IS NULL);

    --------------------------------------------------------------------------
    -- get_date
    --------------------------------------------------------------------------
    l_date := otk$json.get_date(l_json, '$.order_date');
    ok('get_date: default format',     l_date = DATE '2026-04-25');
    ok('get_date: missing = NULL',     otk$json.get_date(l_json, '$.missing') IS NULL);

    --------------------------------------------------------------------------
    -- get_bool / get_bool_yn
    --------------------------------------------------------------------------
    ok('get_bool: true value',         otk$json.get_bool(l_json, '$.active')    = TRUE);
    ok('get_bool: false value',        otk$json.get_bool(l_json, '$.cancelled') = FALSE);
    ok('get_bool: missing = NULL',     otk$json.get_bool(l_json, '$.missing')   IS NULL);
    ok('get_bool_yn: true = Y',        otk$json.get_bool_yn(l_json, '$.active')    = 'Y');
    ok('get_bool_yn: false = N',       otk$json.get_bool_yn(l_json, '$.cancelled') = 'N');
    ok('get_bool_yn: missing = NULL',  otk$json.get_bool_yn(l_json, '$.missing')   IS NULL);

    --------------------------------------------------------------------------
    -- get_obj / get_arr
    --------------------------------------------------------------------------
    l_clob := otk$json.get_obj(l_json, '$.customer');
    ok('get_obj: returns non-null CLOB',       l_clob IS NOT NULL);
    ok('get_obj: nested key accessible',       otk$json.get_str(l_clob, '$.tier') = 'GOLD');
    ok('get_obj: missing path = NULL',         otk$json.get_obj(l_json, '$.missing') IS NULL);

    l_clob := otk$json.get_arr(l_json, '$.items');
    ok('get_arr: returns non-null CLOB',       l_clob IS NOT NULL);
    ok('get_arr: missing path = NULL',         otk$json.get_arr(l_json, '$.missing') IS NULL);

    --------------------------------------------------------------------------
    -- path_exists
    --------------------------------------------------------------------------
    ok('path_exists: present key',     otk$json.path_exists(l_json, '$.order_id')      = TRUE);
    ok('path_exists: nested key',      otk$json.path_exists(l_json, '$.customer.name') = TRUE);
    ok('path_exists: missing key',     otk$json.path_exists(l_json, '$.missing')       = FALSE);
    ok('path_exists: null value key',  otk$json.path_exists(l_json, '$.notes')         = TRUE);

    --------------------------------------------------------------------------
    -- arr_count
    --------------------------------------------------------------------------
    ok('arr_count: items array',       otk$json.arr_count(l_json, '$.items') = 3);
    ok('arr_count: tags array',        otk$json.arr_count(l_json, '$.tags')  = 3);
    ok('arr_count: missing path=NULL', otk$json.arr_count(l_json, '$.missing') IS NULL);
    ok('arr_count: root array',
        otk$json.arr_count('["a","b","c"]') = 3);

    --------------------------------------------------------------------------
    -- arr_element
    --------------------------------------------------------------------------
    -- Object elements
    l_clob := otk$json.arr_element(l_json, 1, '$.items');
    ok('arr_element: first object element',    otk$json.get_str(l_clob, '$.sku') = 'WDG-001');

    l_clob := otk$json.arr_element(l_json, 3, '$.items');
    ok('arr_element: last object element',     otk$json.get_num(l_clob, '$.price') = 499.00);

    -- Scalar elements
    l_clob := otk$json.arr_element(l_json, 2, '$.tags');
    ok('arr_element: scalar element',          TRIM('"' FROM l_clob) = 'fragile');
    ok('arr_element: out of bounds = NULL',
        otk$json.arr_element(l_json, 99, '$.items') IS NULL);

    --------------------------------------------------------------------------
    -- build_obj
    --------------------------------------------------------------------------
    l_clob := otk$json.build_obj('status', 'SHIPPED');
    ok('build_obj: key present',    otk$json.get_str(l_clob, '$.status') = 'SHIPPED');
    ok('build_obj: valid JSON',     otk$json.is_valid(l_clob)            = TRUE);

    --------------------------------------------------------------------------
    -- merge_obj
    --------------------------------------------------------------------------
    l_clob := otk$json.merge_obj(
        otk$json.build_obj('status', 'PENDING'),
        otk$json.build_obj('status', 'SHIPPED')
    );
    ok('merge_obj: overlay wins on conflict',  otk$json.get_str(l_clob, '$.status') = 'SHIPPED');

    l_clob := otk$json.merge_obj(
        '{"a":"1","b":"2"}',
        '{"c":"3"}'
    );
    ok('merge_obj: distinct keys both present',
        otk$json.path_exists(l_clob, '$.a') = TRUE AND
        otk$json.path_exists(l_clob, '$.c') = TRUE);

    ok('merge_obj: NULL base returns overlay',
        otk$json.merge_obj(NULL, '{"x":"1"}') = '{"x":"1"}');
    ok('merge_obj: NULL overlay returns base',
        otk$json.merge_obj('{"x":"1"}', NULL) = '{"x":"1"}');

    --------------------------------------------------------------------------
    -- pretty
    --------------------------------------------------------------------------
    l_clob := otk$json.pretty('{"a":1,"b":2}');
    ok('pretty: output is longer than input',  DBMS_LOB.GETLENGTH(l_clob) > LENGTH('{"a":1,"b":2}'));
    ok('pretty: still valid JSON',             otk$json.is_valid(l_clob) = TRUE);

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
