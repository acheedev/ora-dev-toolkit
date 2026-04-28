# AI Scorecard - S2 4/28

| Module | Score | Reason |
|:---|:---:|:---|
| `src/ansible` | 10 | Full Tower/AWX job lifecycle in PL/SQL — launch, poll, inspect, cancel, status constants, timeout handling. This doesn't exist anywhere else as a packaged solution. Direct lineage from OnePoint. Anyone running Oracle + Ansible automation needs exactly this. |
| `src/rest` | 10 | UTL_HTTP is genuinely painful — wallet config, CLOB chunking, response assembly, auth headers, 23ai compatibility fix. The `check_connectivity` diagnostic function alone is worth it — it walks through every failure layer (wallet → ACL → SSL → HTTP) and tells you exactly what's broken. That saves hours. |
| `src/dynamic_sql` | 9 | Fluent SELECT builder with validated identifiers and collected bind variables. Eliminates the string concatenation pattern where SQL injection lives in most PL/SQL codebases. Object type approach is clean — method chaining on `otk$ds_query_t` reads naturally. |
| `src/ddl` | 9 | Idempotent upgrade scripts are a solved problem here. The `try_exec` vs `exec_ddl` distinction is exactly right — stop execution on install failures, branch on conditional upgrade logic. The error output appending the actual DDL that failed is a small thing that saves real time in deployment debugging. |
| `src/logging` | 8 | Stateless design is the right call — no session bleed in connection pools, APEX, ORDS. Autonomous transactions surviving caller rollbacks is critical for ETL and batch work. Having both CLOB (12c+) and JSON-native (23ai+) engines in parallel is forward-thinking. |
| `src/json` | 8 | The before/after in the README says it all — `JSON_VALUE` inline calls with error handling vs a one-liner. Multiply that across a REST response handler with 10 fields and it's significant. Array iteration helpers and `merge_obj` via JSON_MERGEPATCH are the standout pieces. |
| `src/dbms_assert` | 7 | The security foundation everything else depends on. DBMS_ASSERT is underused because most developers don't know it well — wrapping it with intention-revealing names lowers the barrier. Scores a 7 because the module itself is thin; its value is as infrastructure for the others. |
| `src/clob` | 7 | The chunking utilities for UTL_HTTP are what push this above average — that's a real pattern every REST-from-Oracle implementation needs. `append` with `NOCOPY` for large CLOB construction and `split_lines` handling both LF and CRLF are the other standouts. More useful than it looks at first. |
| `src/convert` | 6 | Eliminates the `BEGIN / TO_NUMBER / EXCEPTION WHEN OTHERS / END` boilerplate that litters most PL/SQL. The Boolean adapters — `to_yn`, `to_tf`, `to_bool` — are legitimately useful for Oracle-to-REST interop where boolean representations vary. Solid but the narrowest scope in the toolkit. |

---
