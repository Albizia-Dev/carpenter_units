# carpenter_units

Cascading `px`, `em`, and `rem` units for Flutter.

The package keeps local `em` declarations on Flutter elements, so a local
change does not require inserting an `InheritedWidget` or wrapper widget at
every override point.

> `0.1.x` is an experimental API. The element-local cascade is intentionally
> low-level and may change before `1.0.0`.

## Usage

Configure `rem` once near the application root:

```dart
runApp(
  UnitsRoot(
    rem: 16.px,
    child: const App(),
  ),
);
```

Resolve units from any descendant `BuildContext`:

```dart
context.units(12.px); // 12
context.units(1.rem); // 16
context.units(1.em);  // 16 by default
```

Set a local `em` on the current element:

```dart
@override
Widget build(BuildContext context) {
  context.units.set(14.px);

  return const Child();
}
```

`Child` and its descendants now inherit `14px` as `1em`:

```dart
final oneEm = context.units(1.em); // 14
```

Relative overrides use the inherited parent `em`:

```dart
context.units.set(1.25.em);
```

If the inherited parent `em` is `16px`, the new local `em` is `20px`.

Reset the local cascade to the root `rem`:

```dart
context.units.reset();
```

`set()` and `reset()` are persistent mutations attached to the current Flutter
`Element`. A declaration remains active until that same element receives a new
`set()` or `reset()` call.

## Cascade rules

- no local declaration -> inherit parent `em`, falling back to root `rem`
- `set(14.px)` -> local `em = 14px`
- `set(1.25.rem)` -> local `em = root rem * 1.25`
- `set(1.25.em)` -> local `em = parent em * 1.25`
- `reset()` -> local `em = root rem`

## License

Apache License 2.0. See [LICENSE](LICENSE).
