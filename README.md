
# ora_dev_toolkit

The **ora_dev_toolkit** is a modular collection of Oracle PL/SQL utilities designed to make everyday development safer, cleaner, and more productive.
Every module follows a consistent naming convention, uses the `otk$` package prefix, and lives in its own functional namespace.

This toolkit is built to grow over time — each module is self‑contained, documented, and focused on solving a specific problem in Oracle development.

---

## Modules

### **dbms_assert/**
Utilities for safe identifier and literal validation using Oracle’s `DBMS_ASSERT` package.

➡️ [View the dbms_assert module](./dbms_assert/README.md)

More modules will be added as the toolkit evolves, including:

- Dynamic SQL helpers
- Metadata utilities
- DDL safety wrappers
- Logging and diagnostics
- Test harnesses

---

## Naming Conventions

All packages in this repository follow the `otk$` prefix and a consistent directory/file structure.
See the full guide here:

➡️ [docs/naming_conventions.md](./docs/naming_conventions.md)

---

## Goals

- Provide reusable, production‑quality PL/SQL utilities
- Standardize safe dynamic SQL patterns
- Reduce boilerplate and repeated code across projects
- Serve as a personal and team‑wide Oracle development toolkit
- Encourage modular, discoverable, well‑documented utilities

---

## Contributing

Each module directory contains:

- A `README.md` describing the module
- A package spec (`.pks`)
- A package body (`.pkb`)

Follow the naming conventions and structure when adding new utilities.
