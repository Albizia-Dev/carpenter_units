// Copyright 2026 Nikolai Chupin.
// SPDX-License-Identifier: Apache-2.0

/// A typed layout unit understood by carpenter_units.
sealed class Unit {
  /// Creates a unit with the given numeric [value].
  const Unit(this.value);

  /// Numeric magnitude of this unit.
  final double value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType && other is Unit && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() {
    final suffix = switch (this) {
      Px() => 'px',
      Em() => 'em',
      Rem() => 'rem',
    };
    return '$value$suffix';
  }
}

/// An absolute logical-pixel value.
final class Px extends Unit {
  /// Creates an absolute logical-pixel value.
  const Px(super.value);
}

/// A value relative to the effective `em` of the current element.
final class Em extends Unit {
  /// Creates an `em` value.
  const Em(super.value);
}

/// A value relative to the root `rem` configured for the widget subtree.
final class Rem extends Unit {
  /// Creates a `rem` value.
  const Rem(super.value);
}

/// Numeric literals for typed units.
extension UnitLiterals on num {
  /// Treats this number as logical pixels.
  Px get px => Px(toDouble());

  /// Treats this number as an `em` multiplier.
  Em get em => Em(toDouble());

  /// Treats this number as a `rem` multiplier.
  Rem get rem => Rem(toDouble());
}
