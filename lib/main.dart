import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for a simpler calculator layout (optional).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const BillTipperApp());
}

class BillTipperApp extends StatelessWidget {
  const BillTipperApp({super.key});

  static const Color _bg = Color(0xFF111111); // matches your logo background

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00C2A8),
        brightness: Brightness.dark,
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF1A1A1A),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return MaterialApp(
      title: 'Bill Tipper',
      debugShowCheckedModeBanner: false,
      theme: base,
      home: const TipCalculatorScreen(),
    );
  }
}

class TipCalculatorScreen extends StatefulWidget {
  const TipCalculatorScreen({super.key});

  @override
  State<TipCalculatorScreen> createState() => _TipCalculatorScreenState();
}

class _TipCalculatorScreenState extends State<TipCalculatorScreen> {
  final _billCtrl = TextEditingController();
  double _tipPercent = 15;
  int _split = 1;

  final List<int> _quickPercents = const [10, 12, 15, 18, 20];

  double get _bill {
    final v = double.tryParse(_billCtrl.text.replaceAll(',', '.')) ?? 0.0;
    return v < 0 ? 0 : v;
  }

  double get _tipAmount => _bill * _tipPercent / 100.0;
  double get _total => _bill + _tipAmount;
  double get _perPerson => _split <= 0 ? _total : _total / _split;

  @override
  void dispose() {
    _billCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/bt_logo.png',
          height: 28,
          fit: BoxFit.contain,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // BILL INPUT
            Text('Bill total', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _billCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?,?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                hintText: 'Enter amount',
                prefixText: '\$ ',
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 20),

            // QUICK TIP BUTTONS
            Text('Tip %', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickPercents.map((p) {
                final selected = _tipPercent.round() == p;
                return ChoiceChip(
                  label: Text('$p%'),
                  selected: selected,
                  onSelected: (_) => setState(() => _tipPercent = p.toDouble()),
                );
              }).toList()
                ..add(
                  ChoiceChip(
                    label: const Text('Custom'),
                    selected: !_quickPercents
                        .map((e) => e.toDouble())
                        .contains(_tipPercent),
                    onSelected: (_) {
                      // selecting "Custom" just keeps current slider value
                      setState(() {});
                    },
                  ),
                ),
            ),

            // CUSTOM SLIDER
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('0%'),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 35,
                    divisions: 35,
                    value: _tipPercent.clamp(0, 35),
                    label: '${_tipPercent.toStringAsFixed(0)}%',
                    onChanged: (v) => setState(() => _tipPercent = v),
                  ),
                ),
                const Text('35%'),
              ],
            ),

            const SizedBox(height: 16),

            // SPLIT
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Split',
                    style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    IconButton(
                      onPressed: _split > 1
                          ? () => setState(() => _split--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_split'),
                    IconButton(
                      onPressed: () => setState(() => _split++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // RESULTS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _line('Bill', _fmt(_bill)),
                      const SizedBox(height: 6),
                      _line('Tip (${_pStr()})', _fmt(_tipAmount)),
                      const Divider(height: 20),
                      _line('Total', _fmt(_total),
                          valueStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          )),
                      if (_split > 1) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _line(
                            'Per person ($_split)',
                            _fmt(_perPerson),
                            valueStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ACTIONS
            FilledButton.tonalIcon(
              onPressed: () {
                setState(() {
                  _billCtrl.clear();
                  _tipPercent = 15;
                  _split = 1;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }

  String _pStr() => '${_tipPercent.toStringAsFixed(0)}%';

  Widget _line(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );
  }

  String _fmt(double v) {
    // Simple money formatter — adjust to your locale as needed.
    return '\$${v.toStringAsFixed(2)}';
    // For advanced locale formatting, consider intl package later.
  }
}