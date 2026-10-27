# Generated documentation

Nothing here is hand-written. Regenerate with:

```bash
cmake --build build/host-debug --target st_qml_catalog   # QmlCatalog.md
doxygen docs/Doxyfile                                    # docs/html/
```

`QmlCatalog.md` is committed so the component list is reviewable in a pull
request — a new control showing up in a diff is a prompt to ask whether it
belongs in `Controls` or `Components`.
