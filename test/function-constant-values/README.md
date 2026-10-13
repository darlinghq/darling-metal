Guest test: `MTLFunctionConstantValues` stores values by index or name (bytes copied at set
time, size from the `MTLDataType`), overwrites, ranges, `-reset` and `-copy`, and raises
`NSInvalidArgumentException` for NULL values, nil names, overflowing ranges and non-scalar/vector types.

There is no public getter, so the test reads the implementation's `_byIndex` / `_byName` ivars.
Build with the Darling tree's AppKit compile flags, linking Foundation and the Metal framework, and run
in a guest on a private runtime and prefix (same harness as `../render-pass-depth-attachment`):

```sh
python3 build-probe.py test/function-constant-values/client.mm "$OUT/client" "$METAL"
env DARLING_ENABLE_METAL=1 DPREFIX="$PREFIX" DARLING_INSTALL_PREFIX="$RUNTIME/image/usr/local" "$RUNTIME/darling" shell env DARLING_ENABLE_METAL=1 "/Volumes/SystemRoot$OUT/client"
```

`-DNEGATIVE` inverts every expectation; that run must fail. Against a Metal built from a tree
without this class (the `MTL_UNSUPPORTED_CLASS` stub) the first set call aborts.

Left out: `-newFunctionWithName:constantValues:error:` does not exist on `MTLLibrary` and is not added
here. It needs mslc support for `[[function_constant]]`; until then declaring it would mean
ignoring the values.
