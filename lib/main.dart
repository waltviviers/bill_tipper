import 'package:flutter/material.dart';

void main() {
  runApp(const BillTipperApp());
}

class BillTipperApp extends StatelessWidget {
  const BillTipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bill Tipper',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.teal,
        ),
        scaffoldBackgroundColor: const Color(0xFF000000), // same as logo bg
      ),
      home: const BillTipperHome(),
    );
  }
}

class BillTipperHome extends StatefulWidget {
  const BillTipperHome({super.key});

  @override
  State<BillTipperHome> createState() => _BillTipperHomeState();
}

class _BillTipperHomeState extends State<BillTipperHome> {
  final TextEditingController _billController = TextEditingController();
  double _tipPercent = 15.0;
  int _split = 1;

  double get _bill =>
      double.tryParse(_billController.text) ?? 0.0;

  double get _tip => _bill * _tipPercent / 100;
  double get _total => _bill + _tip;
  double get _perPerson => _total / _split;

  void _reset() {
    setState(() {
      _billController.clear();
      _tipPercent = 15.0;
      _split = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: Image.asset(
          'assets/bt_logo.png',
          height: 32,
          fit: BoxFit.contain,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Bill total", style: TextStyle(fontSize: 18)),
            TextField(
              controller: _billController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter amount",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            const Text("Tip %", style: TextStyle(fontSize: 18)),
            Slider(
              value: _tipPercent,
              min: 0,
              max: 35,
              divisions: 35,
              label: "${_tipPercent.round()}%",
              onChanged: (v) => setState(() => _tipPercent = v),
            ),
            const SizedBox(height: 20),
            const Text("Split", style: TextStyle(fontSize: 18)),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () =>
                      setState(() => _split = (_split > 1) ? _split - 1 : 1),
                ),
                Text("$_split", style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      setState(() => _split = _split + 1),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            Text("Bill: ${_fmt(_bill)}"),
            Text("Tip (${_tipPercent.round()}%): ${_fmt(_tip)}"),
            Text("Total: ${_fmt(_total)}"),
            Text("Per person: ${_fmt(_perPerson)}"),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Reset"),
                onPressed: _reset,
              ),
            )
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2);
}