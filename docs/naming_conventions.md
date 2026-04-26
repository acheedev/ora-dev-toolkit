
# **ora_dev_toolkit — Naming Convention Guide**

This document defines the official naming conventions for all modules, packages, files, and directories in the **ora_dev_toolkit** repository.
Consistency is the foundation of a maintainable toolkit, and this guide ensures every new utility fits cleanly into the project’s structure.

---

# **1. Global Namespace Prefix**

All PL/SQL packages in this toolkit **must** use the prefix:

```
otk$
```

This prefix:

- Creates a unique namespace
- Avoids collisions with Oracle‑supplied packages
- Makes toolkit modules instantly recognizable
- Groups all utilities under a single conceptual umbrella

Examples:

```
otk$assert_utils
otk$dynamic_sql
otk$ddl_tools
otk$metadata_tables
```

---

# **2. Directory Structure**

All modules live under `src/`. Each logical module has its own subdirectory:

```
src/
    <module>/
        otk$<module>_<component>.pks
        otk$<module>_<component>.pkb
        README.md
```

Examples:

```
src/
    dbms_assert/
        otk$assert_utils.pks
        otk$assert_utils.pkb
        README.md

    dynamic_sql/
        otk$dynamic_sql_builder.pks
        otk$dynamic_sql_builder.pkb
        README.md
```

---

# **3. Package File Naming**

Each package consists of two files:

```
otk$<module>_<component>.pks   -- package spec
otk$<module>_<component>.pkb   -- package body
```

### Rules:

- Always lowercase filenames
- Always use `.pks` for specs and `.pkb` for bodies
- Never include version numbers in filenames
- Keep names short but descriptive

Examples:

```
otk$assert_utils.pks
otk$assert_utils.pkb

otk$ddl_safe_exec.pks
otk$ddl_safe_exec.pkb
```

---

# **4. Package Naming Rules**

Inside the file, the PL/SQL package name must match the filename exactly:

```plsql
CREATE OR REPLACE PACKAGE otk$assert_utils IS
```

This ensures:

- Easy grepping
- Predictable navigation
- Zero ambiguity

---

# **5. Module Naming Guidelines**

Modules should be grouped by functional domain:

| Domain | Directory | Example Package |
|--------|-----------|-----------------|
| Assertion / validation | `dbms_assert/` | `otk$assert_utils` |
| Dynamic SQL | `dynamic_sql/` | `otk$dynamic_sql_builder` |
| DDL helpers | `ddl/` | `otk$ddl_safe_exec` |
| Metadata utilities | `metadata/` | `otk$metadata_tables` |
| Logging | `logging/` | `otk$logging_core` |
| Testing | `testing/` | `otk$testing_assertions` |

---

# **6. README Requirements**

Each module directory must contain a `README.md` with:

- Purpose of the module
- Usage examples
- Public API summary
- Notes or limitations
- Version history (optional)

This keeps the repo self‑documenting.

---

# **7. SQL Script Naming (non‑package files)**

If you later add scripts:

```
install.sql
uninstall.sql
test.sql
demo.sql
```

Keep them lowercase and descriptive.

---

# **8. Example: Full Module Layout**

```
src/
    dbms_assert/
        README.md
        otk$assert_utils.pks
        otk$assert_utils.pkb

    dynamic_sql/
        README.md
        otk$dynamic_sql_builder.pks
        otk$dynamic_sql_builder.pkb
```
