# ora_dev_toolkit

`ora_dev_toolkit` is a modular Oracle PL/SQL utility kit for teams that still live close to the database and want that work to feel safer, cleaner, and easier to repeat.

It collects the small pieces every Oracle project eventually needs: validated dynamic SQL, idempotent DDL helpers, safe conversions, CLOB utilities, JSON helpers, REST calls from PL/SQL, Ansible Tower/AWX automation, and stateless operational logging.

The design goal is simple: keep application PL/SQL focused on business logic, and move the sharp edges into small, documented, testable packages.

## What This Repo Gives You

- A consistent `otk$` namespace for reusable Oracle development utilities
- Defensive wrappers around risky surfaces such as dynamic SQL, DDL, identifiers, and REST payloads
- Small modules that can be installed independently or composed together
- Test scripts for each module, including a local mock REST/Ansible server
- Presentation-friendly examples that show how the pieces work together in real database automation flows

## The Big Picture

```text
Oracle schema
  |
  |-- otk$assert_utils        identifier and literal safety boundary
  |-- otk$ddl                 idempotent install/upgrade DDL
  |-- otk$dynamic_sql_builder fluent SELECT builder
  |-- otk$clob                CLOB conversion, chunking, search, line parsing
  |-- otk$convert             safe scalar conversions and BOOLEAN adapters
  |-- otk$json                JSON CLOB extraction, validation, merge, formatting
  |-- otk$rest                HTTPS client over UTL_HTTP
  |-- otk$ansible             Ansible Tower/AWX job lifecycle client
  |-- otk$log                 CLOB-backed stateless logger
  `-- otk$log_json            Oracle 23ai JSON-native stateless logger
```

The modules are intentionally boring in the best way: predictable names, narrow jobs, clear dependency order, and no hidden framework.

## Module Guide

| Module | Package / Objects | Oracle | Purpose |
| --- | --- | --- | --- |
| [`src/dbms_assert`](./src/dbms_assert/README.md) | `otk$assert_utils` | 12c+ | Wraps `DBMS_ASSERT` for simple names, object names, schema names, literals, and quoted identifiers. This is the injection boundary used by the rest of the toolkit. |
| [`src/ddl`](./src/ddl/README.md) | `otk$ddl` | 12c+ | Object existence checks, conditional drops, and DDL execution with useful failure context. Ideal for repeatable install and upgrade scripts. |
| [`src/dynamic_sql`](./src/dynamic_sql/README.md) | `otk$ds_query_t`, `otk$dynamic_sql_builder` | 12c+ | Fluent object API for building validated dynamic `SELECT` statements with collected bind values. |
| [`src/clob`](./src/clob/README.md) | `otk$clob` | 12c+ | CLOB length, conversion, concat, append, search, replacement, chunking, and line utilities. Removes routine `DBMS_LOB` boilerplate. |
| [`src/convert`](./src/convert/README.md) | `otk$convert` | 12c+ | Safe `NUMBER`, `DATE`, and `TIMESTAMP` conversions with defaults, plus `BOOLEAN` to `Y/N` and `TRUE/FALSE` adapters. |
| [`src/json`](./src/json/README.md) | `otk$json` | 19c+ | JSON-in-CLOB helpers for validation, scalar extraction, array traversal, object merge, and pretty formatting. |
| [`src/rest`](./src/rest/README.md) | `otk$rest` | 19c+ | HTTPS REST client around `UTL_HTTP` with wallet configuration, Basic/Bearer auth, JSON headers, CLOB request chunking, and response assembly. |
| [`src/ansible`](./src/ansible/README.md) | `otk$ansible` | 19c+ | Ansible Tower/AWX API v2 client for launch, poll, inspect, output, success checks, and cancellation. |
| [`src/logging`](./src/logging/README.md) | `otk$log`, `otk$log_json` | 12c+ / 23ai+ | Stateless logging engines with context, payloads, autonomous writes, purge, recent, and search helpers. |

## Installation

Run scripts as the target schema owner. The examples below assume you are launching SQL scripts from the repository root; use `@build.sql` instead of `@src/build.sql` if your SQL client is already in `src`.

### Quick Install

```sql
@src/build.sql
```

Important: the current build script installs the core modules plus the JSON-native logger under `src/logging/json_native`, and leaves the classic CLOB logger commented out. Use it as-is for Oracle 23ai environments. For Oracle 19c or earlier, install the classic logger manually and skip the JSON-native logger.

### Dependency Order

Use this order when installing modules manually:

```sql
-- 1. Identifier validation foundation
@src/dbms_assert/otk$assert_utils.pks
@src/dbms_assert/otk$assert_utils.pkb

-- 2. Independent utility modules
@src/clob/otk$clob.pks
@src/clob/otk$clob.pkb

@src/convert/otk$convert.pks
@src/convert/otk$convert.pkb

-- 3. JSON helpers, Oracle 19c+
@src/json/otk$json.pks
@src/json/otk$json.pkb

-- 4. REST client, Oracle 19c+, depends on otk$clob
@src/rest/otk$rest.pks
@src/rest/otk$rest.pkb

-- 5. DDL helpers, depends on otk$assert_utils
@src/ddl/otk$ddl.pks
@src/ddl/otk$ddl.pkb

-- 6. Dynamic SQL builder, depends on otk$assert_utils
@src/dynamic_sql/otk$ds_query_t_s.sql
@src/dynamic_sql/otk$ds_query_t_b.sql
@src/dynamic_sql/otk$dynamic_sql_builder.pks
@src/dynamic_sql/otk$dynamic_sql_builder.pkb

-- 7. Ansible client, depends on otk$clob, otk$json, otk$rest
@src/ansible/otk$ansible.pks
@src/ansible/otk$ansible.pkb
```

### Logging Options

Classic CLOB-backed logger:

```sql
@src/logging/otk_error_log.sql
@src/logging/otk_error_log_biu.sql
@src/logging/otk$log.pks
@src/logging/otk$log.pkb
```

Oracle 23ai JSON-native logger:

```sql
@src/logging/json_native/otk_error_log_json.sql
@src/logging/json_native/otk_error_log_json_biu.sql
@src/logging/json_native/otk$log_json.pks
@src/logging/json_native/otk$log_json.pkb
```

### Required Privileges

The installing schema generally needs:

- `CREATE PROCEDURE`
- `CREATE TYPE`
- `CREATE TABLE`, `CREATE INDEX`, `CREATE TRIGGER` for logging tables
- `EXECUTE ON DBMS_ASSERT`
- `EXECUTE ON DBMS_UTILITY` for logging stack/backtrace capture
- Network ACL privileges for outbound REST/Ansible calls
- Wallet access for HTTPS REST calls

See [`src/rest/setup/README.md`](./src/rest/setup/README.md) for ACL and wallet setup.

## Usage Examples

### Build Validated Dynamic SQL

```plsql
DECLARE
    l_sql   VARCHAR2(4000);
    l_binds SYS.ODCIVARCHAR2LIST;
BEGIN
    otk$dynamic_sql_builder.new_query
        .select_cols(SYS.ODCIVARCHAR2LIST('EMPLOYEE_ID', 'LAST_NAME'))
        .from_table('HR.EMPLOYEES')
        .where_clause('DEPARTMENT_ID = :b1', ANYDATA.ConvertNumber(50))
        .order_by('LAST_NAME')
        .fetch_first(10)
        .build(l_sql, l_binds);

    DBMS_OUTPUT.put_line(l_sql);
END;
/
```

Result:

```sql
SELECT EMPLOYEE_ID, LAST_NAME FROM HR.EMPLOYEES
WHERE DEPARTMENT_ID = :b1
ORDER BY LAST_NAME
FETCH FIRST 10 ROWS ONLY
```

### Make Upgrade Scripts Idempotent

```plsql
BEGIN
    IF NOT otk$ddl.column_exists('ORDER_HEADER', 'EXTERNAL_REF') THEN
        otk$ddl.exec_ddl(
            'ALTER TABLE order_header ADD (external_ref VARCHAR2(100))'
        );
    END IF;
END;
/
```

### Parse REST JSON Without Boilerplate

```plsql
DECLARE
    l_job_json CLOB;
    l_status   VARCHAR2(30);
    l_elapsed  NUMBER;
BEGIN
    l_job_json := otk$ansible.get_job(12345);
    l_status   := otk$json.get_str(l_job_json, '$.status');
    l_elapsed  := otk$json.get_num(l_job_json, '$.elapsed');
END;
/
```

### Call an API From PL/SQL

```plsql
DECLARE
    l_resp otk$rest.t_response;
BEGIN
    otk$rest.configure(
        p_wallet_path => 'file:/opt/oracle/wallets/rest'
    );

    l_resp := otk$rest.post(
        p_url    => 'https://api.example.com/v1/jobs',
        p_body   => JSON_OBJECT('env' VALUE 'prod' RETURNING CLOB),
        p_bearer => 'token-value'
    );

    IF NOT otk$rest.is_success(l_resp) THEN
        otk$log.error(
            message => 'API call failed',
            context => otk$log.ctx('status', TO_CHAR(l_resp.status_code)),
            payload => l_resp.body
        );
    END IF;
END;
/
```

### Launch and Monitor Ansible Tower/AWX Jobs

```plsql
DECLARE
    l_job_id NUMBER;
    l_status VARCHAR2(20);
BEGIN
    otk$ansible.configure(
        p_base_url        => 'https://ansible-tower.company.com',
        p_bearer          => 'oauth-token',
        p_job_timeout_sec => 300,
        p_job_poll_sec    => 10
    );

    l_job_id := otk$ansible.launch_job(
        p_template_id => 42,
        p_extra_vars  => '{"env":"prod","version":"2.1.0"}'
    );

    l_status := otk$ansible.wait_for_job(l_job_id);

    IF l_status <> otk$ansible.c_status_successful THEN
        otk$log.error(
            message => 'Ansible job failed',
            context => otk$log.ctx('job_id', TO_CHAR(l_job_id)),
            payload => otk$ansible.get_job(l_job_id)
        );
    END IF;
END;
/
```

## Testing

Install the modules first, then run the SQL test scripts from SQL*Plus, SQLcl, SQL Developer, or another Oracle client:

```sql
@tests/assert_utils_t1.sql
@tests/clob_t1.sql
@tests/convert_t1.sql
@tests/json_t1.sql
@tests/ddl_t1.sql
@tests/dynamic_sql_builder_t1.sql
@tests/test_log.sql
@tests/test_log_json.sql       -- Oracle 23ai+ only
```

REST and Ansible tests use a local Python mock server:

```powershell
cd tests/mock_server
pip install -r requirements.txt
python mock_server.py
```

Grant the test ACL once as a DBA:

```sql
@tests/mock_server/setup_test_acl.sql MY_SCHEMA 8765
```

Then run:

```sql
@tests/rest_t1.sql
@tests/ansible_t1.sql
```

Each test script prints a pass/fail summary.

## Repository Structure

```text
src/
    build.sql              master build script
    ansible/               Ansible Tower/AWX client
    clob/                  CLOB helpers
    convert/               safe conversion helpers
    dbms_assert/           DBMS_ASSERT wrappers
    ddl/                   DDL and metadata helpers
    dynamic_sql/           fluent SELECT builder
    json/                  JSON CLOB helpers
    logging/               CLOB and JSON-native loggers
    rest/                  HTTPS REST client and setup scripts
docs/
    naming_conventions.md  project naming rules
    review_v1.md           peer review and correction notes
tests/
    *_t1.sql               module test scripts
    mock_server/           local REST/AWX simulator
```

## Design Notes

- `otk$assert_utils` is the security foundation for identifier validation.
- Modules avoid hidden state except where session configuration is natural, such as REST wallet settings and Ansible base URL/auth.
- Log writes use autonomous transactions so operational breadcrumbs survive caller rollbacks.
- The REST and Ansible modules make the database an active participant in automation, useful for controlled deployment, orchestration, and integration workflows.
- The package/file naming convention is documented in [`docs/naming_conventions.md`](./docs/naming_conventions.md).
