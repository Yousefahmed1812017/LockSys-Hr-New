-- Mobile attendance, step 1: how each employee may check in from the app.
-- Two new columns on HR_EMPLOYEES (the APP_ prefix marks columns used by the mobile
-- app). 1 = allowed, 0 = not allowed. Existing rows get 0, so nothing changes until
-- someone turns a method on. Safe to run twice. Run in the ERP schema (GSPLUS).
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    PROCEDURE ADD_COLUMN (p_column IN VARCHAR2, p_comment IN VARCHAR2) IS
        l NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'HR_EMPLOYEES' AND COLUMN_NAME = p_column;
        IF l = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE HR_EMPLOYEES ADD (' || p_column || ' NUMBER(1,0) DEFAULT 0 NOT NULL)';
        END IF;
        SELECT COUNT(*) INTO l FROM USER_CONSTRAINTS WHERE CONSTRAINT_NAME = 'CHK_HR_EMPLOYEES_' || p_column;
        IF l = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE HR_EMPLOYEES ADD CONSTRAINT CHK_HR_EMPLOYEES_' || p_column
                              || ' CHECK (' || p_column || ' IN (0, 1))';
        END IF;
        EXECUTE IMMEDIATE 'COMMENT ON COLUMN HR_EMPLOYEES.' || p_column || ' IS ''' || p_comment || '''';
    END;
BEGIN
    ADD_COLUMN('APP_CHECKIN_BY_LOCATION', 'Mobile app: the employee may check in by location (1 = yes, 0 = no)');
    ADD_COLUMN('APP_CHECKIN_BY_FACE',     'Mobile app: the employee may check in by face fingerprint (1 = yes, 0 = no)');
END;
/

SELECT COLUMN_NAME, DATA_TYPE, DATA_PRECISION, NULLABLE, DATA_DEFAULT
  FROM USER_TAB_COLUMNS
 WHERE TABLE_NAME = 'HR_EMPLOYEES' AND COLUMN_NAME LIKE 'APP\_CHECKIN%' ESCAPE '\'
 ORDER BY COLUMN_NAME;
