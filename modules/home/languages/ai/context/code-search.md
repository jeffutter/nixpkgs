# Code search

`zg` (zvec-grep) is installed with its index daemon running as a login
service. Pick the tool by what you know:

- A name (identifier, string, error text): grep or `rg`.
- A code shape (every default export, every call with a given argument): the
  `ast-grep` skill.
- A behaviour you can describe but cannot name: the `zg` skill. Use it before
  guessing grep terms, and read the range it points to before citing it.

The `zg` skill also covers creating a repo's index and excluding generated
code from it.
