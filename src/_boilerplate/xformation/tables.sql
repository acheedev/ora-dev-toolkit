-- ORDS REST handler inserts here
CREATE TABLE stg_customer_events (
    stg_id        NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id      VARCHAR2(100)  NOT NULL,
    customer_id   NUMBER         NOT NULL,
    event_type    VARCHAR2(50),
    event_payload CLOB,
    event_ts_raw  VARCHAR2(50),   -- raw ISO string from API
    region_code   VARCHAR2(10),
    load_status   VARCHAR2(20)   DEFAULT 'PENDING'
                                 CONSTRAINT chk_stg_status
                                 CHECK (load_status IN ('PENDING','PROCESSING','COMPLETE','ERROR')),
    retry_count   NUMBER         DEFAULT 0,
    error_msg     VARCHAR2(4000),
    created_at    TIMESTAMP      DEFAULT SYSTIMESTAMP,
    processed_at  TIMESTAMP
);

-- This index is the difference between 2 seconds and 2 hours on a million rows
CREATE INDEX idx_stg_status_id ON stg_customer_events (load_status, stg_id);

-- Target table
CREATE TABLE customer_events (
    event_id      VARCHAR2(100)  PRIMARY KEY,
    customer_id   NUMBER         NOT NULL,
    event_type    VARCHAR2(50),
    event_payload CLOB,
    event_ts      TIMESTAMP,
    region_code   VARCHAR2(10),
    region_group  VARCHAR2(20),  -- derived
    processed_at  TIMESTAMP      DEFAULT SYSTIMESTAMP
);

-- Batch audit trail
CREATE TABLE etl_run_log (
    log_id        NUMBER         GENERATED ALWAYS AS IDENTITY,
    run_id        VARCHAR2(50),
    batch_num     NUMBER,
    rows_ok       NUMBER,
    rows_failed   NUMBER,
    batch_start   TIMESTAMP,
    batch_end     TIMESTAMP,
    status        VARCHAR2(20)
);
