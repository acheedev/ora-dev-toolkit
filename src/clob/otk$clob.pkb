CREATE OR REPLACE PACKAGE BODY otk$clob IS

    c_truncation_marker CONSTANT VARCHAR2(15) := ' ...[TRUNCATED]';


    ----------------------------------------------------------------------
    -- Inspection
    ----------------------------------------------------------------------
    FUNCTION is_empty(p_clob IN CLOB) RETURN BOOLEAN IS
    BEGIN
        RETURN p_clob IS NULL OR DBMS_LOB.GETLENGTH(p_clob) = 0;
    END is_empty;

    FUNCTION clob_len(p_clob IN CLOB) RETURN NUMBER IS
    BEGIN
        IF p_clob IS NULL THEN RETURN 0; END IF;
        RETURN DBMS_LOB.GETLENGTH(p_clob);
    END clob_len;


    ----------------------------------------------------------------------
    -- Conversion
    ----------------------------------------------------------------------
    FUNCTION to_vc2(p_clob IN CLOB, p_max_len IN PLS_INTEGER DEFAULT 32767) RETURN VARCHAR2 IS
        l_len NUMBER;
    BEGIN
        IF p_clob IS NULL THEN RETURN NULL; END IF;
        l_len := DBMS_LOB.GETLENGTH(p_clob);
        IF l_len <= p_max_len THEN
            RETURN DBMS_LOB.SUBSTR(p_clob, p_max_len, 1);
        END IF;
        RETURN DBMS_LOB.SUBSTR(p_clob, p_max_len - LENGTH(c_truncation_marker), 1)
               || c_truncation_marker;
    END to_vc2;

    FUNCTION from_vc2(p_str IN VARCHAR2) RETURN CLOB IS
    BEGIN
        RETURN TO_CLOB(p_str);
    END from_vc2;


    ----------------------------------------------------------------------
    -- Search
    ----------------------------------------------------------------------
    FUNCTION find_pos(
        p_clob       IN CLOB,
        p_search     IN VARCHAR2,
        p_occurrence IN PLS_INTEGER DEFAULT 1
    ) RETURN NUMBER IS
    BEGIN
        IF p_clob IS NULL OR p_search IS NULL THEN RETURN 0; END IF;
        RETURN DBMS_LOB.INSTR(p_clob, p_search, 1, p_occurrence);
    END find_pos;

    FUNCTION contains(p_clob IN CLOB, p_search IN VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        RETURN find_pos(p_clob, p_search) > 0;
    END contains;

    FUNCTION starts_with(p_clob IN CLOB, p_prefix IN VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        IF p_clob IS NULL OR p_prefix IS NULL THEN RETURN FALSE; END IF;
        RETURN DBMS_LOB.SUBSTR(p_clob, LENGTH(p_prefix), 1) = p_prefix;
    END starts_with;

    FUNCTION ends_with(p_clob IN CLOB, p_suffix IN VARCHAR2) RETURN BOOLEAN IS
        l_len    NUMBER;
        l_suflen NUMBER;
    BEGIN
        IF p_clob IS NULL OR p_suffix IS NULL THEN RETURN FALSE; END IF;
        l_len    := DBMS_LOB.GETLENGTH(p_clob);
        l_suflen := LENGTH(p_suffix);
        IF l_len < l_suflen THEN RETURN FALSE; END IF;
        RETURN DBMS_LOB.SUBSTR(p_clob, l_suflen, l_len - l_suflen + 1) = p_suffix;
    END ends_with;


    ----------------------------------------------------------------------
    -- Modification
    ----------------------------------------------------------------------
    FUNCTION replace_str(
        p_clob    IN CLOB,
        p_search  IN VARCHAR2,
        p_replace IN VARCHAR2
    ) RETURN CLOB IS
    BEGIN
        IF p_clob IS NULL OR p_search IS NULL THEN RETURN p_clob; END IF;
        -- REPLACE() accepts CLOB arguments and returns CLOB
        RETURN REPLACE(p_clob, p_search, NVL(p_replace, ''));
    END replace_str;

    FUNCTION trim_clob(p_clob IN CLOB) RETURN CLOB IS
        l_len   NUMBER;
        l_start NUMBER := 1;
        l_end   NUMBER;
        l_char  VARCHAR2(1);
    BEGIN
        IF p_clob IS NULL THEN RETURN NULL; END IF;
        l_len := DBMS_LOB.GETLENGTH(p_clob);
        IF l_len = 0 THEN RETURN p_clob; END IF;

        -- Advance past leading whitespace
        WHILE l_start <= l_len LOOP
            l_char := DBMS_LOB.SUBSTR(p_clob, 1, l_start);
            EXIT WHEN l_char NOT IN (' ', CHR(9), CHR(10), CHR(13));
            l_start := l_start + 1;
        END LOOP;

        IF l_start > l_len THEN RETURN EMPTY_CLOB(); END IF;

        -- Retreat past trailing whitespace
        l_end := l_len;
        WHILE l_end >= l_start LOOP
            l_char := DBMS_LOB.SUBSTR(p_clob, 1, l_end);
            EXIT WHEN l_char NOT IN (' ', CHR(9), CHR(10), CHR(13));
            l_end := l_end - 1;
        END LOOP;

        RETURN DBMS_LOB.SUBSTR(p_clob, l_end - l_start + 1, l_start);
    END trim_clob;


    ----------------------------------------------------------------------
    -- Concatenation
    ----------------------------------------------------------------------
    FUNCTION concat_clob(p_clob1 IN CLOB, p_clob2 IN CLOB) RETURN CLOB IS
        l_result CLOB;
    BEGIN
        IF p_clob1 IS NULL THEN RETURN p_clob2; END IF;
        IF p_clob2 IS NULL THEN RETURN p_clob1; END IF;
        DBMS_LOB.CREATETEMPORARY(l_result, TRUE);
        DBMS_LOB.APPEND(l_result, p_clob1);
        DBMS_LOB.APPEND(l_result, p_clob2);
        RETURN l_result;
    END concat_clob;

    PROCEDURE append(p_target IN OUT NOCOPY CLOB, p_src IN CLOB) IS
    BEGIN
        IF p_src IS NULL THEN RETURN; END IF;
        IF p_target IS NULL THEN
            DBMS_LOB.CREATETEMPORARY(p_target, TRUE);
        END IF;
        DBMS_LOB.APPEND(p_target, p_src);
    END append;


    ----------------------------------------------------------------------
    -- Chunking
    ----------------------------------------------------------------------
    FUNCTION chunk_count(p_clob IN CLOB, p_size IN PLS_INTEGER DEFAULT 32767) RETURN NUMBER IS
        l_len NUMBER;
    BEGIN
        IF p_clob IS NULL THEN RETURN 0; END IF;
        l_len := DBMS_LOB.GETLENGTH(p_clob);
        IF l_len = 0 THEN RETURN 0; END IF;
        RETURN CEIL(l_len / p_size);
    END chunk_count;

    FUNCTION chunk(
        p_clob      IN CLOB,
        p_chunk_num IN PLS_INTEGER,
        p_size      IN PLS_INTEGER DEFAULT 32767
    ) RETURN VARCHAR2 IS
        l_len    NUMBER;
        l_offset NUMBER;
        l_amount NUMBER;
    BEGIN
        IF p_clob IS NULL THEN RETURN NULL; END IF;
        l_len    := DBMS_LOB.GETLENGTH(p_clob);
        l_offset := (p_chunk_num - 1) * p_size + 1;
        IF l_offset > l_len THEN RETURN NULL; END IF;
        l_amount := LEAST(p_size, l_len - l_offset + 1);
        RETURN DBMS_LOB.SUBSTR(p_clob, l_amount, l_offset);
    END chunk;


    ----------------------------------------------------------------------
    -- Line utilities
    ----------------------------------------------------------------------
    FUNCTION split_lines(p_clob IN CLOB) RETURN SYS.ODCIVARCHAR2LIST IS
        l_result  SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
        l_len     NUMBER;
        l_pos     NUMBER := 1;
        l_nl_pos  NUMBER;
        l_line    VARCHAR2(4000);
        l_amount  NUMBER;
    BEGIN
        IF p_clob IS NULL THEN RETURN l_result; END IF;
        l_len := DBMS_LOB.GETLENGTH(p_clob);
        IF l_len = 0 THEN RETURN l_result; END IF;

        LOOP
            l_nl_pos := DBMS_LOB.INSTR(p_clob, CHR(10), l_pos);

            IF l_nl_pos = 0 THEN
                -- Last line — no trailing newline
                l_amount := LEAST(4000, l_len - l_pos + 1);
                l_line   := DBMS_LOB.SUBSTR(p_clob, l_amount, l_pos);
                l_result.EXTEND;
                l_result(l_result.COUNT) := RTRIM(l_line, CHR(13));
                EXIT;
            ELSE
                -- Extract up to (not including) the newline
                l_amount := l_nl_pos - l_pos;
                IF l_amount = 0 THEN
                    l_line := '';                   -- blank line (consecutive newlines)
                ELSE
                    l_line := DBMS_LOB.SUBSTR(p_clob, LEAST(4000, l_amount), l_pos);
                    l_line := RTRIM(l_line, CHR(13));   -- strip CR from CRLF
                END IF;
                l_result.EXTEND;
                l_result(l_result.COUNT) := l_line;
                l_pos := l_nl_pos + 1;
            END IF;

            EXIT WHEN l_pos > l_len;
        END LOOP;

        RETURN l_result;
    END split_lines;

    FUNCTION line_count(p_clob IN CLOB) RETURN NUMBER IS
    BEGIN
        IF p_clob IS NULL THEN RETURN 0; END IF;
        RETURN split_lines(p_clob).COUNT;
    END line_count;

    FUNCTION get_line(p_clob IN CLOB, p_line_num IN PLS_INTEGER) RETURN VARCHAR2 IS
        l_lines SYS.ODCIVARCHAR2LIST;
    BEGIN
        l_lines := split_lines(p_clob);
        IF p_line_num BETWEEN 1 AND l_lines.COUNT THEN
            RETURN l_lines(p_line_num);
        END IF;
        RETURN NULL;
    END get_line;


END otk$clob;
/
