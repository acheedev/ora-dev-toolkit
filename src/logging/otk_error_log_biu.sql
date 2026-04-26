CREATE OR REPLACE TRIGGER otk_error_log_biu
BEFORE INSERT OR UPDATE ON otk_error_log
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :new.log_timestamp := SYSTIMESTAMP;
        :new.created_by    := SYS_CONTEXT('USERENV','SESSION_USER');
    END IF;
END;
/
