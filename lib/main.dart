import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() => runApp(const BillTipperApp());

class BillTipperApp extends StatelessWidget {
  const BillTipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bill Tipper',
      theme: ThemeData.dark(),
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
  final _billController = TextEditingController();
  final _picker = ImagePicker();
  File? _lastPhoto;

  double _tipPercent = 10; // default 10%
  bool _roundToR5 = true; // default enabled
  double _totalWithTip = 0;

  @override
  void dispose() {
    _billController.dispose();
    super.dispose();
  }

  double _parseBill() =>
      double.tryParse(_billController.text.replaceAll(',', '.')) ?? 0.0;

  double _computeTotal(double bill, double percent) =>
      bill + bill * (percent / 100.0);

  double _roundUpToNearest5(double value) {
    if (!_roundToR5) return value;
    final remainder = value % 5;
    return remainder == 0 ? value : (value + (5 - remainder));
  }

  void _recalculate() {
    final bill = _parseBill();
    final total = _computeTotal(bill, _tipPercent);
    _totalWithTip = _roundUpToNearest5(total);
    setState(() {});
  }

  Future<void> _scanBillWithCamera() async {
    final XFile? shot =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (shot == null) return;

    _lastPhoto = File(shot.path);
    final inputImage = InputImage.fromFile(_lastPhoto!);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final result = await recognizer.processImage(inputImage);
      final text = result.text;

      final regex = RegExp(r'(?<!\d)(\d{1,3}(?:[ .,\u00A0]\d{3})*|\d+)(?:[.,]\d{2})?');
      double? best;

      for (final m in regex.allMatches(text)) {
        var normalized = m.group(0)!;
        normalized = normalized.replaceAll(RegExp(r'[ \u00A0]'), '');
        if (RegExp(r',\d{2}$').hasMatch(normalized) &&
            normalized.contains(',')) {
          normalized = normalized.replaceAll('.', '');
          normalized = normalized.replaceAll(',', '.');
        } else {
          normalized = normalized.replaceAll(',', '');
        }

        final v = double.tryParse(normalized);
        if (v != null) {
          if (best == null || v > best) best = v;
        }
      }

      if (best != null) {
        _billController.text = best!.toStringAsFixed(2);
        _recalculate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scanned amount: ${best!.toStringAsFixed(2)}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t detect a total. Try again.')),
          );
        }
      }
    } finally {
      recognizer.close();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = _parseBill();
    final tipValue = bill * (_tipPercent / 100.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Tipper'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Bill ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              RotatedBox(quarterTurns: 1, child: Icon(Icons.person, size: 28)),
              Text(' Tipper', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            ],
          ),

          const SizedBox(height: 12),

          // Total owed right under logo
          Center(
            child: Text(
              _formatCurrency(_totalWithTip),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.greenAccent,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Scan button + preview
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _scanBillWithCamera,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Scan bill'),
              ),
              const SizedBox(width: 12),
              if (_lastPhoto != null)
                SizedBox(
                  width: 64,
                  height: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_lastPhoto!, fit: BoxFit.cover),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Manual bill entry
          TextField(
            controller: _billController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Bill amount (optional)',
              hintText: 'e.g. 249.90',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _recalculate(),
          ),

          const SizedBox(height: 20),

          // Tip slider
          Row(
            children: [
              const Text('Tip %'),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 30,
                  divisions: 30,
                  value: _tipPercent,
                  label: '${_tipPercent.toStringAsFixed(0)}%',
                  onChanged: (v) {
                    setState(() => _tipPercent = v);
                    _recalculate();
                  },
                ),
              ),
              SizedBox(
                width: 48,
                child: Text('${_tipPercent.toStringAsFixed(0)}%'),
              ),
            ],
          ),

          // Round to 5 toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Round up to nearest R5'),
            value: _roundToR5,
            onChanged: (v) {
              setState(() => _roundToR5 = v);
              _recalculate();
            },
          ),

          const Divider(),
          _MoneyRow(label: 'Bill', value: bill),
          _MoneyRow(label: 'Tip', value: tipValue),
        ],
      ),
    );
  }

  String _formatCurrency(double v) {
    return v.isNaN || v.isInfinite ? '0.00' : v.toStringAsFixed(2);
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasize;
  const _MoneyRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)
        : const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value.toStringAsFixed(2),
            style: style,
          ),
        ],
      ),
    );
  }
}