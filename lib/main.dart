import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.teal,
        ),
        scaffoldBackgroundColor: Color(0xFF000000),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
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
  double _tipPercent = 10.0; // ← default tip is now 10%
  int _split = 1;

  // Photo of the bill (captured with the camera)
  final ImagePicker _picker = ImagePicker();
  XFile? _billPhoto;

  double get _bill => double.tryParse(_billController.text) ?? 0.0;
  double get _tip => _bill * _tipPercent / 100;
  double get _total => _bill + _tip;
  double get _perPerson => _split == 0 ? 0 : _total / _split;

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() => _billPhoto = photo);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open camera: $e')),
      );
    }
  }

  void _reset() {
    setState(() {
      _billController.clear();
      _tipPercent = 10.0;
      _split = 1;
      _billPhoto = null;
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
        actions: [
          IconButton(
            tooltip: 'Take photo of bill',
            icon: const Icon(Icons.photo_camera),
            onPressed: _takePhoto,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _takePhoto,
        icon: const Icon(Icons.photo_camera),
        label: const Text('Take photo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optional photo preview
            if (_billPhoto != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_billPhoto!.path),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text("Bill total", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            TextField(
              controller: _billController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: "Enter amount",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            const Text("Tip %", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Slider(
              value: _tipPercent,
              min: 0,
              max: 35,
              divisions: 35,
              label: "${_tipPercent.round()}%",
              onChanged: (v) => setState(() => _tipPercent = v),
            ),

            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [10, 12, 15, 18, 20].map((p) {
                final selected = _tipPercent.round() == p;
                return ChoiceChip(
                  label: Text("$p%"),
                  selected: selected,
                  onSelected: (_) => setState(() => _tipPercent = p.toDouble()),
                );
              }).toList()
                ..add(
                  ChoiceChip(
                    label: const Text("Custom"),
                    selected: ![10, 12, 15, 18, 20].contains(_tipPercent.round()),
                    onSelected: (_) {},
                  ),
                ),
            ),

            const SizedBox(height: 24),
            const Text("Split", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => setState(() => _split = (_split > 1) ? _split - 1 : 1),
                ),
                Text("$_split", style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _split = _split + 1),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            _row("Bill", _bill),
            _row("Tip (${_tipPercent.round()}%)", _tip),
            _row("Total", _total),
            _row("Per person", _perPerson),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text("Reset"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(_fmt(value), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2);
}