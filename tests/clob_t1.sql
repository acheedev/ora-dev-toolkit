SET SERVEROUTPUT ON
DECLARE
    l_pass PLS_INTEGER := 0;
    l_fail PLS_INTEGER := 0;

    -- Multi-line test content with CRLF and LF mixed
    l_text  CLOB := 'Module  : order_sync' || CHR(13) || CHR(10) ||
                    'Version : 2.1.0'       || CHR(10) ||
                    'Status  : ACTIVE'      || CHR(10) ||
                    ''                      || CHR(10) ||
                    'Order 1001 processed successfully.' || CHR(10) ||
                    'Order 1002 failed: product not found.' || CHR(10) ||
                    'Order 1003 processed successfully.' || CHR(10) ||
                    'Order 1004 failed: insufficient inventory.' || CHR(10) ||
                    ''                      || CHR(10) ||
                    'Total processed: 4';

    l_clob   CLOB;
    l_vc2    VARCHAR2(32767);
    l_num    NUMBER;
    l_bool   BOOLEAN;
    l_lines  SYS.ODCIVARCHAR2LIST;

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
    DBMS_OUTPUT.put_line('=== TEST: otk$clob ===');
    DBMS_OUTPUT.put_line('');

    --------------------------------------------------------------------------
    -- is_empty
    --------------------------------------------------------------------------
    ok('is_empty: NULL',          otk$clob.is_empty(NULL)         = TRUE);
    ok('is_empty: empty CLOB',    otk$clob.is_empty(EMPTY_CLOB()) = TRUE);
    ok('is_empty: non-empty',     otk$clob.is_empty(l_text)       = FALSE);

    --------------------------------------------------------------------------
    -- clob_len
    --------------------------------------------------------------------------
    ok('clob_len: NULL returns 0',    otk$clob.clob_len(NULL)   = 0);
    ok('clob_len: non-null > 0',      otk$clob.clob_len(l_text) > 0);
    ok('clob_len: matches GETLENGTH', otk$clob.clob_len(l_text) = DBMS_LOB.GETLENGTH(l_text));

    --------------------------------------------------------------------------
    -- to_vc2
    --------------------------------------------------------------------------
    l_vc2 := otk$clob.to_vc2(l_text);
    ok('to_vc2: returns content',      l_vc2 IS NOT NULL);
    ok('to_vc2: no truncation marker', INSTR(l_vc2, '[TRUNCATED]') = 0);

    -- Force truncation
    l_vc2 := otk$clob.to_vc2(l_text, 30);
    ok('to_vc2: truncated length <= 30',      LENGTH(l_vc2) <= 30);
    ok('to_vc2: truncation marker present',   INSTR(l_vc2, '[TRUNCATED]') > 0);

    ok('to_vc2: NULL returns NULL', otk$clob.to_vc2(NULL) IS NULL);

    --------------------------------------------------------------------------
    -- from_vc2
    --------------------------------------------------------------------------
    l_clob := otk$clob.from_vc2('hello world');
    ok('from_vc2: returns CLOB',       l_clob IS NOT NULL);
    ok('from_vc2: content preserved',  otk$clob.to_vc2(l_clob) = 'hello world');

    --------------------------------------------------------------------------
    -- find_pos
    --------------------------------------------------------------------------
    ok('find_pos: found at position > 0',   otk$clob.find_pos(l_text, 'order_sync') > 0);
    ok('find_pos: not found returns 0',     otk$clob.find_pos(l_text, 'MISSING_XYZ') = 0);
    ok('find_pos: second occurrence',
        otk$clob.find_pos(l_text, 'processed', 2) >
        otk$clob.find_pos(l_text, 'processed', 1));
    ok('find_pos: NULL clob returns 0',     otk$clob.find_pos(NULL, 'x') = 0);
    ok('find_pos: NULL search returns 0',   otk$clob.find_pos(l_text, NULL) = 0);

    --------------------------------------------------------------------------
    -- contains
    --------------------------------------------------------------------------
    ok('contains: present string',   otk$clob.contains(l_text, 'order_sync') = TRUE);
    ok('contains: absent string',    otk$clob.contains(l_text, 'MISSING')    = FALSE);

    --------------------------------------------------------------------------
    -- starts_with / ends_with
    --------------------------------------------------------------------------
    ok('starts_with: correct prefix',  otk$clob.starts_with(l_text, 'Module') = TRUE);
    ok('starts_with: wrong prefix',    otk$clob.starts_with(l_text, 'Version') = FALSE);
    ok('starts_with: NULL clob',       otk$clob.starts_with(NULL,   'Module') = FALSE);

    ok('ends_with: correct suffix',    otk$clob.ends_with(l_text, 'processed: 4') = TRUE);
    ok('ends_with: wrong suffix',      otk$clob.ends_with(l_text, 'Module')       = FALSE);
    ok('ends_with: NULL clob',         otk$clob.ends_with(NULL, 'x')              = FALSE);

    --------------------------------------------------------------------------
    -- replace_str
    --------------------------------------------------------------------------
    l_clob := otk$clob.replace_str(l_text, 'ACTIVE', 'INACTIVE');
    ok('replace_str: replacement applied',   otk$clob.contains(l_clob, 'INACTIVE') = TRUE);
    ok('replace_str: old value gone',        otk$clob.contains(l_clob, 'ACTIVE')   = FALSE);

    l_clob := otk$clob.replace_str(l_text, 'MISSING', 'X');
    ok('replace_str: no match = unchanged',  otk$clob.clob_len(l_clob) = otk$clob.clob_len(l_text));

    ok('replace_str: NULL clob = NULL',      otk$clob.replace_str(NULL, 'x', 'y') IS NULL);

    --------------------------------------------------------------------------
    -- trim_clob
    --------------------------------------------------------------------------
    l_clob := otk$clob.trim_clob(TO_CLOB('   hello world   '));
    ok('trim_clob: leading spaces removed',  otk$clob.starts_with(l_clob, 'hello') = TRUE);
    ok('trim_clob: trailing spaces removed', otk$clob.ends_with  (l_clob, 'world') = TRUE);

    l_clob := otk$clob.trim_clob(TO_CLOB('   '));
    ok('trim_clob: all-whitespace = empty',  otk$clob.is_empty(l_clob) = TRUE);

    ok('trim_clob: NULL = NULL',             otk$clob.trim_clob(NULL) IS NULL);

    --------------------------------------------------------------------------
    -- concat_clob
    --------------------------------------------------------------------------
    l_clob := otk$clob.concat_clob(TO_CLOB('hello '), TO_CLOB('world'));
    ok('concat_clob: content joined',        otk$clob.to_vc2(l_clob) = 'hello world');
    ok('concat_clob: NULL left = right',     otk$clob.to_vc2(otk$clob.concat_clob(NULL, TO_CLOB('x'))) = 'x');
    ok('concat_clob: NULL right = left',     otk$clob.to_vc2(otk$clob.concat_clob(TO_CLOB('x'), NULL)) = 'x');

    --------------------------------------------------------------------------
    -- append
    --------------------------------------------------------------------------
    l_clob := NULL;
    otk$clob.append(l_clob, TO_CLOB('first'));
    otk$clob.append(l_clob, TO_CLOB(' second'));
    ok('append: initialises NULL target',    otk$clob.to_vc2(l_clob) = 'first second');
    otk$clob.append(l_clob, NULL);
    ok('append: NULL src is no-op',          otk$clob.to_vc2(l_clob) = 'first second');

    --------------------------------------------------------------------------
    -- chunk_count / chunk
    --------------------------------------------------------------------------
    -- Build a known-length CLOB: 100 'x' chars
    l_clob := TO_CLOB(RPAD('x', 100, 'x'));
    ok('chunk_count: 100 chars / 30 = 4',    otk$clob.chunk_count(l_clob, 30) = 4);
    ok('chunk_count: NULL = 0',              otk$clob.chunk_count(NULL)        = 0);

    ok('chunk: first chunk length = 30',     LENGTH(otk$clob.chunk(l_clob, 1, 30)) = 30);
    ok('chunk: last chunk length = 10',      LENGTH(otk$clob.chunk(l_clob, 4, 30)) = 10);
    ok('chunk: beyond end = NULL',           otk$clob.chunk(l_clob, 5, 30)         IS NULL);

    -- Verify chunks reassemble to original
    l_vc2 := otk$clob.chunk(l_clob, 1, 30) ||
              otk$clob.chunk(l_clob, 2, 30) ||
              otk$clob.chunk(l_clob, 3, 30) ||
              otk$clob.chunk(l_clob, 4, 30);
    ok('chunk: reassembled = original',      l_vc2 = RPAD('x', 100, 'x'));

    --------------------------------------------------------------------------
    -- split_lines
    --------------------------------------------------------------------------
    l_lines := otk$clob.split_lines(l_text);
    ok('split_lines: correct line count',    l_lines.COUNT = 10);
    ok('split_lines: first line content',    l_lines(1) = 'Module  : order_sync');
    ok('split_lines: empty line preserved',  l_lines(4) = '');
    ok('split_lines: last line no newline',  l_lines(10) = 'Total processed: 4');
    ok('split_lines: CRLF stripped to LF',  INSTR(l_lines(1), CHR(13)) = 0);
    ok('split_lines: NULL = empty list',     otk$clob.split_lines(NULL).COUNT = 0);

    --------------------------------------------------------------------------
    -- line_count / get_line
    --------------------------------------------------------------------------
    ok('line_count: matches split_lines',    otk$clob.line_count(l_text) = l_lines.COUNT);
    ok('line_count: NULL = 0',               otk$clob.line_count(NULL) = 0);

    ok('get_line: line 2 content',           otk$clob.get_line(l_text, 2) = 'Version : 2.1.0');
    ok('get_line: out of range = NULL',      otk$clob.get_line(l_text, 99) IS NULL);

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
