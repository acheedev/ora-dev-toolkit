SET SERVEROUTPUT ON
DECLARE
    l_pass PLS_INTEGER := 0;
    l_fail PLS_INTEGER := 0;

    l_num  NUMBER;
    l_date DATE;
    l_ts   TIMESTAMP;
    l_str  VARCHAR2(100);
    l_bool BOOLEAN;

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
    DBMS_OUTPUT.put_line('=== TEST: otk$convert ===');
    DBMS_OUTPUT.put_line('');

    --------------------------------------------------------------------------
    -- to_number
    --------------------------------------------------------------------------
    ok('to_number: integer string',         otk$convert.to_number('42')        = 42);
    ok('to_number: decimal string',         otk$convert.to_number('3.14')      = 3.14);
    ok('to_number: negative',               otk$convert.to_number('-100')      = -100);
    ok('to_number: NULL returns default',   otk$convert.to_number(NULL, 0)     = 0);
    ok('to_number: NULL no default = NULL', otk$convert.to_number(NULL)        IS NULL);
    ok('to_number: bad input returns default', otk$convert.to_number('abc', -1) = -1);
    ok('to_number: bad input no default = NULL', otk$convert.to_number('abc') IS NULL);

    --------------------------------------------------------------------------
    -- to_date
    --------------------------------------------------------------------------
    l_date := otk$convert.to_date('2026-04-25');
    ok('to_date: default format',           l_date = DATE '2026-04-25');

    l_date := otk$convert.to_date('25/04/2026', 'DD/MM/YYYY');
    ok('to_date: custom format',            l_date = DATE '2026-04-25');

    ok('to_date: NULL returns default',
        otk$convert.to_date(NULL, 'YYYY-MM-DD', DATE '2000-01-01') = DATE '2000-01-01');
    ok('to_date: NULL no default = NULL',   otk$convert.to_date(NULL) IS NULL);
    ok('to_date: bad input returns default',
        otk$convert.to_date('not-a-date', 'YYYY-MM-DD', DATE '1900-01-01') = DATE '1900-01-01');
    ok('to_date: bad input no default = NULL', otk$convert.to_date('not-a-date') IS NULL);

    --------------------------------------------------------------------------
    -- to_timestamp
    --------------------------------------------------------------------------
    l_ts := otk$convert.to_timestamp('2026-04-25 14:30:00');
    ok('to_timestamp: default format',      l_ts = TIMESTAMP '2026-04-25 14:30:00');

    l_ts := otk$convert.to_timestamp('25-APR-2026 14:30:00', 'DD-MON-YYYY HH24:MI:SS');
    ok('to_timestamp: custom format',       l_ts = TIMESTAMP '2026-04-25 14:30:00');

    ok('to_timestamp: NULL returns default',
        otk$convert.to_timestamp(NULL, 'YYYY-MM-DD HH24:MI:SS',
            TIMESTAMP '2000-01-01 00:00:00') = TIMESTAMP '2000-01-01 00:00:00');
    ok('to_timestamp: bad input = NULL',    otk$convert.to_timestamp('garbage') IS NULL);

    --------------------------------------------------------------------------
    -- to_bool: truthy inputs
    --------------------------------------------------------------------------
    ok('to_bool: Y',     otk$convert.to_bool('Y')     = TRUE);
    ok('to_bool: y',     otk$convert.to_bool('y')     = TRUE);
    ok('to_bool: YES',   otk$convert.to_bool('YES')   = TRUE);
    ok('to_bool: yes',   otk$convert.to_bool('yes')   = TRUE);
    ok('to_bool: TRUE',  otk$convert.to_bool('TRUE')  = TRUE);
    ok('to_bool: true',  otk$convert.to_bool('true')  = TRUE);
    ok('to_bool: 1',     otk$convert.to_bool('1')     = TRUE);

    --------------------------------------------------------------------------
    -- to_bool: falsy inputs
    --------------------------------------------------------------------------
    ok('to_bool: N',     otk$convert.to_bool('N')     = FALSE);
    ok('to_bool: n',     otk$convert.to_bool('n')     = FALSE);
    ok('to_bool: NO',    otk$convert.to_bool('NO')    = FALSE);
    ok('to_bool: FALSE', otk$convert.to_bool('FALSE') = FALSE);
    ok('to_bool: false', otk$convert.to_bool('false') = FALSE);
    ok('to_bool: 0',     otk$convert.to_bool('0')     = FALSE);

    --------------------------------------------------------------------------
    -- to_bool: null / unknown inputs
    --------------------------------------------------------------------------
    ok('to_bool: NULL = NULL',    otk$convert.to_bool(NULL)    IS NULL);
    ok('to_bool: garbage = NULL', otk$convert.to_bool('MAYBE') IS NULL);
    ok('to_bool: 2 = NULL',       otk$convert.to_bool('2')     IS NULL);

    --------------------------------------------------------------------------
    -- to_yn
    --------------------------------------------------------------------------
    ok('to_yn: TRUE  = Y',    otk$convert.to_yn(TRUE)  = 'Y');
    ok('to_yn: FALSE = N',    otk$convert.to_yn(FALSE) = 'N');
    ok('to_yn: NULL  = NULL', otk$convert.to_yn(NULL)  IS NULL);

    -- Round-trip
    ok('to_yn/to_bool round-trip TRUE',
        otk$convert.to_bool(otk$convert.to_yn(TRUE))  = TRUE);
    ok('to_yn/to_bool round-trip FALSE',
        otk$convert.to_bool(otk$convert.to_yn(FALSE)) = FALSE);

    --------------------------------------------------------------------------
    -- to_tf
    --------------------------------------------------------------------------
    ok('to_tf: TRUE  = TRUE',  otk$convert.to_tf(TRUE)  = 'TRUE');
    ok('to_tf: FALSE = FALSE', otk$convert.to_tf(FALSE) = 'FALSE');
    ok('to_tf: NULL  = NULL',  otk$convert.to_tf(NULL)  IS NULL);

    -- Round-trip
    ok('to_tf/to_bool round-trip TRUE',
        otk$convert.to_bool(otk$convert.to_tf(TRUE))  = TRUE);
    ok('to_tf/to_bool round-trip FALSE',
        otk$convert.to_bool(otk$convert.to_tf(FALSE)) = FALSE);

    --------------------------------------------------------------------------
    -- nvl_str / nvl_num / nvl_date
    --------------------------------------------------------------------------
    ok('nvl_str: non-null returns val',     otk$convert.nvl_str('x', 'default') = 'x');
    ok('nvl_str: null returns default',     otk$convert.nvl_str(NULL, 'default') = 'default');

    ok('nvl_num: non-null returns val',     otk$convert.nvl_num(42, 0)   = 42);
    ok('nvl_num: null returns default',     otk$convert.nvl_num(NULL, 0) = 0);

    ok('nvl_date: non-null returns val',
        otk$convert.nvl_date(DATE '2026-01-01', DATE '2000-01-01') = DATE '2026-01-01');
    ok('nvl_date: null returns default',
        otk$convert.nvl_date(NULL, DATE '2000-01-01') = DATE '2000-01-01');

    -- Typical chaining pattern
    ok('chaining: nvl_num wrapping to_number',
        otk$convert.nvl_num(otk$convert.to_number('bad'), 0) = 0);

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
