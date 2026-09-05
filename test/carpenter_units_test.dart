// Copyright 2026 Nikolai Chupin.
// SPDX-License-Identifier: Apache-2.0

import 'package:carpenter_units/carpenter_units.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unit literals preserve type and value', () {
    expect(12.px, const Px(12));
    expect(1.25.em, const Em(1.25));
    expect(.875.rem, const Rem(.875));
  });

  testWidgets('em falls back to rem', (tester) async {
    double? em;
    double? rem;

    await tester.pumpWidget(
      UnitsRoot(
        rem: 16.px,
        child: Builder(
          builder: (context) {
            em = context.units(1.em);
            rem = context.units(1.rem);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(em, 16);
    expect(rem, 16);
  });

  testWidgets('set px cascades to descendants', (tester) async {
    double? value;

    await tester.pumpWidget(
      UnitsRoot(
        rem: 16.px,
        child: Builder(
          builder: (context) {
            context.units.set(14.px);
            return Builder(
              builder: (context) {
                value = context.units(1.em);
                return const SizedBox();
              },
            );
          },
        ),
      ),
    );

    expect(value, 14);
  });

  testWidgets('relative em set uses parent em', (tester) async {
    double? value;

    await tester.pumpWidget(
      UnitsRoot(
        rem: 16.px,
        child: Builder(
          builder: (context) {
            context.units.set(14.px);
            return Builder(
              builder: (context) {
                context.units.set(1.25.em);
                return Builder(
                  builder: (context) {
                    value = context.units(1.em);
                    return const SizedBox();
                  },
                );
              },
            );
          },
        ),
      ),
    );

    expect(value, 17.5);
  });

  testWidgets('reset creates a rem barrier', (tester) async {
    double? value;

    await tester.pumpWidget(
      UnitsRoot(
        rem: 16.px,
        child: Builder(
          builder: (context) {
            context.units.set(14.px);
            return Builder(
              builder: (context) {
                context.units.reset();
                return Builder(
                  builder: (context) {
                    value = context.units(1.em);
                    return const SizedBox();
                  },
                );
              },
            );
          },
        ),
      ),
    );

    expect(value, 16);
  });

  testWidgets('changing root rem recalculates relative em', (tester) async {
    double? value;

    Widget tree(double rem) {
      return UnitsRoot(
        rem: rem.px,
        child: Builder(
          builder: (context) {
            context.units.set(1.25.em);
            return Builder(
              builder: (context) {
                value = context.units(1.em);
                return const SizedBox();
              },
            );
          },
        ),
      );
    }

    await tester.pumpWidget(tree(16));
    expect(value, 20);

    await tester.pumpWidget(tree(20));
    expect(value, 25);
  });

  testWidgets(
    'imperative set rebuilds an existing descendant without setState',
    (tester) async {
      final key = GlobalKey<_ImperativeHostState>();

      await tester.pumpWidget(
        UnitsRoot(
          rem: 16.px,
          child: _ImperativeHost(key: key),
        ),
      );

      expect(find.text('16.0'), findsOneWidget);

      key.currentState!.setLocalEm(14.px);
      await tester.pump();

      expect(find.text('14.0'), findsOneWidget);
    },
  );

  testWidgets('new declaration invalidates an existing const consumer', (
    tester,
  ) async {
    final key = GlobalKey<_HostState>();

    await tester.pumpWidget(
      UnitsRoot(
        rem: 16.px,
        child: _Host(key: key),
      ),
    );

    expect(find.text('16.0'), findsOneWidget);

    key.currentState!.setLocalEm(14.px);
    await tester.pump();

    expect(find.text('14.0'), findsOneWidget);
  });

  testWidgets('consumer churn preserves later cascade invalidation', (
    tester,
  ) async {
    final key = GlobalKey<_ChurnHostState>();

    await tester.pumpWidget(
      UnitsRoot(rem: 16.px, child: _ChurnHost(key: key, count: 400)),
    );
    expect(find.text('16.0'), findsOneWidget);

    key.currentState!.replaceConsumers(0);
    await tester.pump();

    key.currentState!.replaceConsumers(200);
    await tester.pump();

    key.currentState!.setLocalEm(14.px);
    await tester.pump();

    expect(find.text('14.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Unit? _localEm;

  void setLocalEm(Unit value) {
    setState(() {
      _localEm = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localEm = _localEm;
    if (localEm != null) {
      context.units.set(localEm);
    }
    return const _ConstConsumer();
  }
}

class _ConstConsumer extends StatelessWidget {
  const _ConstConsumer();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text('${context.units(1.em)}'),
    );
  }
}

class _ImperativeHost extends StatefulWidget {
  const _ImperativeHost({super.key});

  @override
  State<_ImperativeHost> createState() => _ImperativeHostState();
}

class _ImperativeHostState extends State<_ImperativeHost> {
  void setLocalEm(Unit value) {
    context.units.set(value);
  }

  @override
  Widget build(BuildContext context) {
    return const _ConstConsumer();
  }
}

class _ChurnHost extends StatefulWidget {
  const _ChurnHost({super.key, required this.count});

  final int count;

  @override
  State<_ChurnHost> createState() => _ChurnHostState();
}

class _ChurnHostState extends State<_ChurnHost> {
  late int _count = widget.count;
  var _generation = 0;

  void replaceConsumers(int count) {
    setState(() {
      _count = count;
      _generation += 1;
    });
  }

  void setLocalEm(Unit value) {
    context.units.set(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ConstConsumer(),
        for (var index = 0; index < _count; index++)
          _UnitProbe(key: ValueKey('$_generation-$index')),
      ],
    );
  }
}

class _UnitProbe extends StatelessWidget {
  const _UnitProbe({super.key});

  @override
  Widget build(BuildContext context) {
    context.units(1.em);
    return const SizedBox.shrink();
  }
}
