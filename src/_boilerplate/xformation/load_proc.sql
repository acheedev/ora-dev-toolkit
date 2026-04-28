CREATE OR REPLACE PROCEDURE process_customer_events (
    p_batch_size  IN PLS_INTEGER DEFAULT 1000,
    p_max_retries IN PLS_INTEGER DEFAULT 3,
    p_run_id      IN VARCHAR2    DEFAULT NULL
)
AS
    -- -------------------------------------------------------
    -- Types
    -- -------------------------------------------------------
    TYPE t_id_list  IS TABLE OF stg_customer_events.stg_id%TYPE;
    TYPE t_stg_list IS TABLE OF stg_customer_events%ROWTYPE;

    l_ids         t_id_list;
    l_rows        t_stg_list;

    -- -------------------------------------------------------
    -- Run tracking
    -- -------------------------------------------------------
    l_run_id      VARCHAR2(50);
    l_batch_num   PLS_INTEGER := 0;
    l_total_ok    PLS_INTEGER := 0;
    l_total_fail  PLS_INTEGER := 0;
    l_batch_ok    PLS_INTEGER;
    l_batch_fail  PLS_INTEGER;
    l_batch_start TIMESTAMP;

    -- -------------------------------------------------------
    -- Per-row working vars
    -- -------------------------------------------------------
    l_event_ts    TIMESTAMP;
    l_region_grp  VARCHAR2(20);
    l_succeeded   BOOLEAN;
    l_sleep_secs  NUMBER;

BEGIN
    l_run_id := NVL(p_run_id, 'ETL_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDD_HH24MISS_FF3'));
    DBMS_OUTPUT.PUT_LINE('Run started: ' || l_run_id);

    -- =========================================================
    -- OUTER LOOP: keeps pulling batches until staging is empty
    -- =========================================================
    LOOP
        l_batch_num   := l_batch_num + 1;
        l_batch_ok    := 0;
        l_batch_fail  := 0;
        l_batch_start := SYSTIMESTAMP;

        -- ---------------------------------------------------
        -- Step 1: Grab a batch of PENDING row IDs and lock them.
        -- SKIP LOCKED = a second parallel session won't block,
        -- it just skips rows already locked by this session.
        -- ---------------------------------------------------
        SELECT stg_id
        BULK COLLECT INTO l_ids
        FROM stg_customer_events
        WHERE load_status = 'PENDING'
        ORDER BY stg_id
        FETCH FIRST p_batch_size ROWS ONLY
        FOR UPDATE SKIP LOCKED;

        EXIT WHEN l_ids.COUNT = 0;  -- nothing left, we're done

        -- ---------------------------------------------------
        -- Step 2: Fence the batch immediately.
        -- Mark PROCESSING + commit so ORDS can keep inserting
        -- new PENDING rows without fighting us for locks.
        -- ---------------------------------------------------
        FORALL i IN 1 .. l_ids.COUNT
            UPDATE stg_customer_events
            SET    load_status = 'PROCESSING'
            WHERE  stg_id = l_ids(i);

        COMMIT;  -- release locks; rows now owned by this run

        -- ---------------------------------------------------
        -- Step 3: Fetch full row data for this batch
        -- ---------------------------------------------------
        SELECT *
        BULK COLLECT INTO l_rows
        FROM stg_customer_events
        WHERE stg_id IN (SELECT column_value FROM TABLE(l_ids))
        ORDER BY stg_id;

        -- =====================================================
        -- INNER LOOP: process each row with retry + backoff
        -- =====================================================
        FOR i IN 1 .. l_rows.COUNT LOOP

            l_succeeded  := FALSE;
            l_sleep_secs := 1;  -- reset backoff seed per row

            FOR attempt IN 1 .. p_max_retries LOOP

                SAVEPOINT sp_before_row;  -- row-level rollback fence

                BEGIN

                    -- ----------------------------------------
                    -- TRANSFORMATIONS
                    -- ----------------------------------------

                    -- 1. Parse raw ISO timestamp; fall back gracefully
                    BEGIN
                        l_event_ts := TO_TIMESTAMP(
                            TRIM(l_rows(i).event_ts_raw),
                            'YYYY-MM-DD"T"HH24:MI:SS'
                        );
                    EXCEPTION
                        WHEN OTHERS THEN
                            l_event_ts := SYSTIMESTAMP;
                    END;

                    -- 2. Derive region group from code
                    l_region_grp := CASE
                        WHEN l_rows(i).region_code IN ('US','CA','MX') THEN 'NORTH_AMERICA'
                        WHEN l_rows(i).region_code IN ('UK','DE','FR','ES') THEN 'EMEA'
                        WHEN l_rows(i).region_code IN ('JP','CN','AU','IN') THEN 'APAC'
                        ELSE 'OTHER'
                    END;

                    -- ----------------------------------------
                    -- UPSERT into target
                    -- ----------------------------------------
                    MERGE INTO customer_events tgt
                    USING (
                        SELECT
                            l_rows(i).event_id                    AS event_id,
                            l_rows(i).customer_id                 AS customer_id,
                            TRIM(UPPER(l_rows(i).event_type))     AS event_type,
                            l_rows(i).event_payload               AS event_payload,
                            l_event_ts                            AS event_ts,
                            UPPER(TRIM(l_rows(i).region_code))    AS region_code,
                            l_region_grp                          AS region_group
                        FROM DUAL
                    ) src ON (tgt.event_id = src.event_id)
                    WHEN MATCHED THEN
                        UPDATE SET
                            tgt.event_type    = src.event_type,
                            tgt.event_payload = src.event_payload,
                            tgt.event_ts      = src.event_ts,
                            tgt.region_code   = src.region_code,
                            tgt.region_group  = src.region_group,
                            tgt.processed_at  = SYSTIMESTAMP
                    WHEN NOT MATCHED THEN
                        INSERT (event_id, customer_id, event_type, event_payload,
                                event_ts, region_code, region_group, processed_at)
                        VALUES (src.event_id, src.customer_id, src.event_type, src.event_payload,
                                src.event_ts, src.region_code, src.region_group, SYSTIMESTAMP);

                    -- Mark this staging row done
                    UPDATE stg_customer_events
                    SET    load_status   = 'COMPLETE',
                           processed_at = SYSTIMESTAMP
                    WHERE  stg_id = l_rows(i).stg_id;

                    l_batch_ok  := l_batch_ok + 1;
                    l_succeeded := TRUE;
                    EXIT;  -- leave the retry loop, row is done

                EXCEPTION
                    WHEN OTHERS THEN
                        ROLLBACK TO sp_before_row;
                        -- deadlock or lock timeout — maybe worth one retry, no sleep
                        IF SQLCODE = -60 OR SQLCODE = -54 THEN
                            -- one immediate retry, no backoff
                            NULL;
                        ELSE
                            -- data error, constraint, whatever — just fail it
                            UPDATE stg_customer_events
                            SET load_status = 'ERROR',
                                error_msg   = SUBSTR(SQLERRM, 1, 4000)
                            WHERE stg_id = l_rows(i).stg_id;
                        END IF;
                END;

            END LOOP;  -- retry loop

        END LOOP;  -- row loop

        -- ---------------------------------------------------
        -- Step 4: Commit the batch.
        -- COMPLETE rows are in target. ERROR rows are flagged.
        -- ---------------------------------------------------
        INSERT INTO etl_run_log (run_id, batch_num, rows_ok, rows_failed,
                                  batch_start, batch_end, status)
        VALUES (l_run_id, l_batch_num, l_batch_ok, l_batch_fail,
                l_batch_start, SYSTIMESTAMP,
                CASE WHEN l_batch_fail > 0 THEN 'PARTIAL' ELSE 'OK' END);

        COMMIT;

        l_total_ok   := l_total_ok   + l_batch_ok;
        l_total_fail := l_total_fail + l_batch_fail;

        DBMS_OUTPUT.PUT_LINE(
            'Batch ' || l_batch_num || ': ok=' || l_batch_ok || ' fail=' || l_batch_fail
        );

        IF l_batch_fail > (l_rows.COUNT * 0.2) THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Failure rate exceeded 20% in batch ' || l_batch_num || ' — aborting run');
        END IF

    END LOOP;  -- batch loop

    DBMS_OUTPUT.PUT_LINE(
        'Run complete: ' || l_run_id
        || ' | batches=' || l_batch_num
        || ' | total_ok=' || l_total_ok
        || ' | total_fail=' || l_total_fail
    );

EXCEPTION
    WHEN OTHERS THEN
        -- Fatal, unrecoverable — roll back whatever's in flight and re-raise
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('FATAL: ' || l_run_id || ' | ' || SQLERRM);
        RAISE;

END process_customer_events;
/
