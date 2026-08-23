// Copyright 2026 Nikolai Chupin.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'unit.dart';

/// Configures the root `rem` value for a subtree.
///
/// Local `em` values are attached directly to Flutter [Element]s by
/// [UnitsHandle.set] and [UnitsHandle.reset]. No wrapper widget is required
/// for local overrides.
class UnitsRoot extends StatefulWidget {
  /// Creates a root unit scope.
  UnitsRoot({super.key, required this.rem, required this.child})
    : assert(rem.value > 0 && rem.value != double.infinity);

  /// The root `rem` size, expressed in logical pixels.
  final Px rem;

  /// The subtree that receives this root unit configuration.
  final Widget child;

  @override
  State<UnitsRoot> createState() => _UnitsRootState();
}

class _UnitsRootState extends State<UnitsRoot> {
  final _UnitsEngine _engine = _UnitsEngine();

  @override
  Widget build(BuildContext context) {
    return _UnitsScope(
      engine: _engine,
      rem: widget.rem.value,
      child: widget.child,
    );
  }
}

class _UnitsScope extends InheritedWidget {
  const _UnitsScope({
    required this.engine,
    required this.rem,
    required super.child,
  });

  final _UnitsEngine engine;
  final double rem;

  static _UnitsScope depend(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_UnitsScope>();
    if (scope == null) {
      throw FlutterError(
        'No UnitsRoot found above this BuildContext. '
        'Wrap the application or subtree in UnitsRoot(rem: 16.px, child: ...).',
      );
    }
    return scope;
  }

  static _UnitsScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_UnitsScope>();
    if (scope == null) {
      throw FlutterError(
        'No UnitsRoot found above this BuildContext. '
        'Wrap the application or subtree in UnitsRoot(rem: 16.px, child: ...).',
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(_UnitsScope oldWidget) =>
      rem != oldWidget.rem || engine != oldWidget.engine;
}

/// Adds `context.units(...)`, `context.units.set(...)`, and
/// `context.units.reset()`.
extension UnitsBuildContext on BuildContext {
  /// Resolves units and manages the local `em` declaration for this element.
  UnitsHandle get units => UnitsHandle._(this);
}

/// Resolves typed units and mutates the local `em` declaration of an element.
///
/// A declaration is persistent for the lifetime of that [Element] until it is
/// replaced by another [set] or by [reset].
final class UnitsHandle {
  const UnitsHandle._(this._context);

  final BuildContext _context;

  /// Resolves [unit] to Flutter logical pixels.
  ///
  /// `px` is absolute, `rem` is relative to [UnitsRoot.rem], and `em` is
  /// relative to the effective local cascade value.
  double call(Unit unit) {
    if (unit is Px) {
      return unit.value;
    }

    final scope = _UnitsScope.depend(_context);

    if (unit is Rem) {
      return unit.value * scope.rem;
    }

    return scope.engine.resolveEm(_elementOf(_context), scope.rem) * unit.value;
  }

  /// Sets the effective `em` declaration on this exact Flutter element.
  ///
  /// The declaration is inherited by descendants until another descendant
  /// calls [set] or [reset]. If [value] is an [Em], it is resolved against the
  /// inherited parent `em`, not against itself.
  void set(Unit value) {
    final scope = _UnitsScope.read(_context);
    scope.engine.set(_elementOf(_context), value);
  }

  /// Resets the effective `em` on this exact Flutter element to root `rem`.
  ///
  /// This is a cascade barrier: descendants inherit the root `rem` from this
  /// point even if an ancestor has a different local `em`.
  void reset() {
    final scope = _UnitsScope.read(_context);
    scope.engine.reset(_elementOf(_context));
  }
}

Element _elementOf(BuildContext context) {
  if (context is Element) {
    return context;
  }
  throw FlutterError(
    'carpenter_units requires a Flutter BuildContext backed by an Element.',
  );
}

sealed class _EmDeclaration {
  const _EmDeclaration();
}

final class _SetDeclaration extends _EmDeclaration {
  const _SetDeclaration(this.unit);

  final Unit unit;

  @override
  bool operator ==(Object other) =>
      other is _SetDeclaration && other.unit == unit;

  @override
  int get hashCode => unit.hashCode;
}

final class _ResetDeclaration extends _EmDeclaration {
  const _ResetDeclaration();

  @override
  bool operator ==(Object other) => other is _ResetDeclaration;

  @override
  int get hashCode => 0;
}

final class _ResolvedEm {
  const _ResolvedEm({required this.rem, required this.em});

  final double rem;
  final double em;
}

final class _NodeState {
  _EmDeclaration? declaration;
  _ResolvedEm? cache;
  bool registeredConsumer = false;
  bool rebuildScheduled = false;
  final List<WeakReference<Element>> dependents = <WeakReference<Element>>[];
}

final class _UnitsEngine {
  final Expando<_NodeState> _nodes = Expando<_NodeState>('carpenter_units');
  final List<WeakReference<Element>> _consumers = <WeakReference<Element>>[];

  _NodeState _node(Element element) => _nodes[element] ??= _NodeState();

  double resolveEm(Element consumer, double rem) {
    final consumerState = _node(consumer);
    _registerConsumer(consumer, consumerState);

    final cached = consumerState.cache;
    if (cached != null && cached.rem == rem) {
      return cached.em;
    }

    var multiplier = 1.0;
    double? base;
    final dependencies = <Element>[];

    bool readDeclaration(Element element) {
      final declaration = _nodes[element]?.declaration;
      if (declaration == null) {
        return true;
      }

      dependencies.add(element);

      if (declaration is _ResetDeclaration) {
        base = rem;
        return false;
      }

      final unit = (declaration as _SetDeclaration).unit;
      if (unit is Px) {
        base = unit.value;
        return false;
      }
      if (unit is Rem) {
        base = unit.value * rem;
        return false;
      }

      multiplier *= unit.value;
      return true;
    }

    var keepWalking = readDeclaration(consumer);
    if (keepWalking) {
      consumer.visitAncestorElements((ancestor) {
        keepWalking = readDeclaration(ancestor);
        return keepWalking;
      });
    }

    final em = (base ?? rem) * multiplier;

    for (final owner in dependencies) {
      if (!identical(owner, consumer)) {
        _registerDependent(owner, consumer);
      }
    }

    consumerState.cache = _ResolvedEm(rem: rem, em: em);
    return em;
  }

  void set(Element element, Unit value) {
    _replaceDeclaration(element, _SetDeclaration(value));
  }

  void reset(Element element) {
    _replaceDeclaration(element, const _ResetDeclaration());
  }

  void _replaceDeclaration(Element owner, _EmDeclaration next) {
    final state = _node(owner);
    final previous = state.declaration;

    if (previous == next) {
      return;
    }

    state.declaration = next;
    state.cache = null;

    if (previous == null) {
      // A new cascade node can affect consumers that previously had no reason
      // to know this element existed. This scan happens once per declaring
      // element, not on every resolution.
      _invalidateExistingConsumersBelow(owner);
    } else {
      // Existing declaration owners already know the consumers whose `em`
      // resolution passes through them.
      _invalidateRegisteredDependents(owner, state);
    }

    // If set/reset is called from an event handler rather than from build(),
    // the declaring element may itself render values derived from `em`.
    // During its own build it is already dirty, so this is a no-op.
    _markForRebuild(owner, owner, state);
  }

  void _registerConsumer(Element consumer, _NodeState state) {
    if (state.registeredConsumer) {
      return;
    }
    state.registeredConsumer = true;
    _consumers.add(WeakReference<Element>(consumer));
  }

  void _registerDependent(Element owner, Element consumer) {
    final state = _node(owner);

    for (var i = state.dependents.length - 1; i >= 0; i--) {
      final existing = state.dependents[i].target;
      if (existing == null || !existing.mounted) {
        state.dependents.removeAt(i);
        continue;
      }
      if (identical(existing, consumer)) {
        return;
      }
    }

    state.dependents.add(WeakReference<Element>(consumer));
  }

  void _invalidateRegisteredDependents(Element owner, _NodeState state) {
    for (var i = state.dependents.length - 1; i >= 0; i--) {
      final dependent = state.dependents[i].target;
      if (dependent == null || !dependent.mounted) {
        state.dependents.removeAt(i);
        continue;
      }

      if (!_isDescendantOf(dependent, owner)) {
        // The element may have moved via GlobalKey. Drop the stale relation;
        // the next resolution will register the new chain.
        state.dependents.removeAt(i);
        continue;
      }

      final dependentState = _nodes[dependent];
      if (dependentState != null) {
        dependentState.cache = null;
      }
      _markForRebuild(owner, dependent, dependentState);
    }
  }

  void _invalidateExistingConsumersBelow(Element owner) {
    for (var i = _consumers.length - 1; i >= 0; i--) {
      final consumer = _consumers[i].target;
      if (consumer == null || !consumer.mounted) {
        _consumers.removeAt(i);
        continue;
      }

      if (identical(consumer, owner)) {
        final state = _nodes[consumer];
        if (state != null) {
          state.cache = null;
        }
        continue;
      }

      if (!_isDescendantOf(consumer, owner)) {
        continue;
      }

      final state = _nodes[consumer];
      if (state != null) {
        state.cache = null;
      }
      _markForRebuild(owner, consumer, state);
    }
  }

  bool _isDescendantOf(Element element, Element ancestor) {
    if (identical(element, ancestor)) {
      return true;
    }

    if (element.owner != ancestor.owner || element.depth <= ancestor.depth) {
      return false;
    }

    var found = false;
    try {
      element.visitAncestorElements((candidate) {
        if (identical(candidate, ancestor)) {
          found = true;
          return false;
        }
        return true;
      });
    } on FlutterError {
      // A weakly-held element can be in the middle of deactivation. Treat that
      // relation as stale and let a later resolution register it again.
      return false;
    }
    return found;
  }

  void _markForRebuild(Element owner, Element target, _NodeState? targetState) {
    if (!target.mounted || target.dirty) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;

    // During the declaring element's own build it is legal to dirty a
    // descendant. In other persistent-callback situations we defer to avoid
    // violating Flutter's build lock.
    if (owner.dirty || phase != SchedulerPhase.persistentCallbacks) {
      target.markNeedsBuild();
      return;
    }

    final state = targetState ?? _node(target);
    if (state.rebuildScheduled) {
      return;
    }
    state.rebuildScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      state.rebuildScheduled = false;
      if (target.mounted && !target.dirty) {
        target.markNeedsBuild();
      }
    });
  }
}
