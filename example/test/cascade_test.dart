import 'package:carpenter_units/carpenter_units.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(rem, 16);
    expect(em, 16);
  });

  testWidgets('set px changes local em and descendants', (tester) async {
    double? local;
    double? child;

    await tester.pumpWidget(
      UnitsRoot(
        rem: 16.px,
        child: Builder(
          builder: (context) {
            context.units.set(14.px);

            local = context.units(1.em);

            return Builder(
              builder: (context) {
                child = context.units(1.em);

                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );

    expect(local, 14);
    expect(child, 14);
  });

  testWidgets('nested em resolves against parent em', (tester) async {
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

                    return const SizedBox.shrink();
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

  testWidgets('reset returns em to root rem', (tester) async {
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

                value = context.units(1.em);

                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );

    expect(value, 16);
  });

  testWidgets('sibling branches do not leak em', (tester) async {
    double? left;
    double? right;

    await tester.pumpWidget(
      UnitsRoot(
        rem: 16.px,
        child: Row(
          children: [
            Builder(
              builder: (context) {
                context.units.set(14.px);
                left = context.units(1.em);

                return const SizedBox.shrink();
              },
            ),
            Builder(
              builder: (context) {
                right = context.units(1.em);

                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );

    expect(left, 14);
    expect(right, 16);
  });

  testWidgets('changing root rem updates em fallback', (tester) async {
    double? value;

    Widget build(double rem) {
      return UnitsRoot(
        rem: rem.px,
        child: Builder(
          builder: (context) {
            value = context.units(1.em);

            return const SizedBox.shrink();
          },
        ),
      );
    }

    await tester.pumpWidget(build(16));
    expect(value, 16);

    await tester.pumpWidget(build(20));
    expect(value, 20);
  });
}
