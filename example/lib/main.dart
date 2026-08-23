import 'package:carpenter_units/carpenter_units.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const UnitsExampleApp());
}

class UnitsExampleApp extends StatefulWidget {
  const UnitsExampleApp({super.key});

  @override
  State<UnitsExampleApp> createState() => _UnitsExampleAppState();
}

class _UnitsExampleAppState extends State<UnitsExampleApp> {
  double _rem = 16;

  @override
  Widget build(BuildContext context) {
    return UnitsRoot(
      rem: _rem.px,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.dark,
        ),
        home: _DemoPage(
          rem: _rem,
          onRemChanged: (value) {
            setState(() {
              _rem = value;
            });
          },
        ),
      ),
    );
  }
}

class _DemoPage extends StatelessWidget {
  const _DemoPage({required this.rem, required this.onRemChanged});

  final double rem;
  final ValueChanged<double> onRemChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedEm = context.units(1.em);

    return Scaffold(
      appBar: AppBar(title: const Text('carpenter_units example')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _NumberField(
            label: 'Root rem',
            suffix: 'px',
            value: rem,
            onChanged: onRemChanged,
          ),
          const SizedBox(height: 16),
          Text(
            'Root: 1em = ${_format(resolvedEm)}px',
            style: TextStyle(fontSize: resolvedEm),
          ),
          const SizedBox(height: 32),
          const _LevelOne(),
        ],
      ),
    );
  }
}

class _LevelOne extends StatefulWidget {
  const _LevelOne();

  @override
  State<_LevelOne> createState() => _LevelOneState();
}

class _LevelOneState extends State<_LevelOne> {
  double _em = 1.25;

  @override
  Widget build(BuildContext context) {
    context.units.set(_em.em);

    final resolvedEm = context.units(1.em);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumberField(
          label: 'Level 1 em',
          suffix: '× parent em',
          value: _em,
          onChanged: (value) {
            setState(() {
              _em = value;
            });
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Level 1: 1em = ${_format(resolvedEm)}px',
          style: TextStyle(fontSize: resolvedEm),
        ),
        const SizedBox(height: 32),

        // Намеренно const.
        // Изменение Level 1 должно всё равно протечь сюда
        // через наш cascade engine.
        const _LevelTwo(),
      ],
    );
  }
}

class _LevelTwo extends StatefulWidget {
  const _LevelTwo();

  @override
  State<_LevelTwo> createState() => _LevelTwoState();
}

class _LevelTwoState extends State<_LevelTwo> {
  double _em = 0.8;

  @override
  Widget build(BuildContext context) {
    context.units.set(_em.em);

    final resolvedEm = context.units(1.em);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumberField(
          label: 'Level 2 em',
          suffix: '× parent em',
          value: _em,
          onChanged: (value) {
            setState(() {
              _em = value;
            });
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Level 2: 1em = ${_format(resolvedEm)}px',
          style: TextStyle(fontSize: resolvedEm),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.suffix,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String suffix;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (raw) {
        final normalized = raw.replaceAll(',', '.');
        final parsed = double.tryParse(normalized);

        if (parsed == null || !parsed.isFinite || parsed <= 0) {
          return;
        }

        onChanged(parsed);
      },
    );
  }
}

String _format(double value) {
  final rounded = value.roundToDouble();

  if (value == rounded) {
    return rounded.toInt().toString();
  }

  return value.toStringAsFixed(2);
}
