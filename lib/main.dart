import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const BillTipperApp());

class BillTipperApp extends StatelessWidget {
  const BillTipperApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bill Tipper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const BillHomePage(),
    );
  }
}

class BillHomePage extends StatefulWidget {
  const BillHomePage({super.key});
  @override
  State<BillHomePage> createState() => _BillHomePageState();
}

class _BillHomePageState extends State<BillHomePage> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  File? _imageFile;
  String _rawText = '';
  double? _detectedTotal;
  double _tipPercent = 0.12; // 12% default (SA restaurants often 10–12.5+)
  int _split = 1;
  bool _roundUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _error = null;
    });
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 85);
      if (x == null) return;
      final file = File(x.path);
      setState(() {
        _imageFile = file;
        _busy = true;
        _detectedTotal = null;
        _rawText = '';
      });

      final input = InputImage.fromFile(file);
      final result = await _recognizer.processImage(input);
      final text = result.text;
      final detected = _extractLikelyTotal(text);

      setState(() {
        _rawText = text;
        _detectedTotal = detected;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Something went sideways: $e';
      });
    }
  }

  // --- OCR parsing heuristics ---
  // 1) Try lines containing TOTAL-like keywords.
  // 2) If none, choose the largest plausible amount (but ignore cartoonish outliers).
  // 3) Prefer amounts with .00/.cents and those near VAT/gratuity contexts.
  double? _extractLikelyTotal(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Normalize “R 123,45” → 123.45; also handle 1 234.56 and 1,234.56
    double? parseAmount(String raw) {
      var s = raw.replaceAll('R', '').replaceAll('ZAR', '').trim();
      // Remove spaces in numbers like "1 234.56"
      s = s.replaceAll(RegExp(r'(?<=\d)\s(?=\d)'), '');
      // If there are both comma and dot, assume comma is thousands, dot is decimal.
      if (s.contains(',') && s.contains('.')) {
        s = s.replaceAll(',', '');
      } else if (s.contains(',') && !s.contains('.')) {
        // Chances are comma is decimal (e.g., 123,45). Convert to dot.
        s = s.replaceAll('.', ''); // in weird cases where dots are thousands
        s = s.replaceAll(',', '.');
      }
      s = s.replaceAll(RegExp(r'[^0-9\.]'), '');
      if (s.isEmpty) return null;
      try {
        return double.parse(s);
      } catch (_) {
        return null;
      }
    }

    final amountRegex = RegExp(
        r'(R?\s?\d{1,3}([ ,]\d{3})*(\.\d{2})?|R?\s?\d+\.\d{2}|R?\s?\d{1,3}(,\d{2}))',
        caseSensitive: false);

    final keywordRegex = RegExp(
        r'\b(total|amount\s*due|balance\s*(due)?|grand\s*total|to\s*pay)\b',
        caseSensitive: false);

    final candidates = <double>[];

    // 1) Keyword-driven search
    for (final line in lines) {
      if (keywordRegex.hasMatch(line)) {
        for (final m in amountRegex.allMatches(line)) {
          final amt = parseAmount(m.group(0)!);
          if (amt != null) candidates.add(amt);
        }
      }
    }
    if (candidates.isNotEmpty) {
      // choose the max among keyword lines (often the grand total)
      final best = candidates.maxOrNull;
      if (best != null && best > 0) return best;
    }

    // 2) Look at amounts across whole text
    final allAmts = <double>[];
    for (final line in lines) {
      for (final m in amountRegex.allMatches(line)) {
        final amt = parseAmount(m.group(0)!);
        if (amt != null) allAmts.add(amt);
      }
    }
    if (allAmts.isEmpty) return null;

    // Heuristic: pick something in the top decile but below absurd outliers
    allAmts.sort();
    final p90Index = max(0, (allAmts.length * 0.9).floor() - 1);
    final p90 = allAmts[p90Index];
    // Guardrail: if p90 is huge (> R 50k), maybe it’s a phone/email misparse. In that case pick next lower band.
    if (p90 > 50000 && allAmts.length > 2) {
      return allAmts[allAmts.length - 3];
    }
    return p90;
  }

  double get _baseTotal => _detectedTotal ?? 0.0;
  double get _tipAmount => _roundUp ? _roundedTipAmount() : _baseTotal * _tipPercent;
  double _roundedTipAmount() {
    // Round up total+tip to nearest R5 and back-compute tip.
    final raw = _baseTotal * (1 + _tipPercent);
    final rounded = (raw / 5.0).ceil() * 5.0;
    return max(0.0, rounded - _baseTotal);
  }

  double get _grandTotal => _baseTotal + _tipAmount;
  double get _perPerson => _split <= 0 ? _grandTotal : _grandTotal / _split;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormatLike('R');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Tipper'),
        actions: [
          IconButton(
            tooltip: 'Pick from gallery',
            onPressed: _busy ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
          ),
          IconButton(
            tooltip: 'Use camera',
            onPressed: _busy ? null : () => _pick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_imageFile!, height: 220, fit: BoxFit.cover),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: const Center(
                child: Text('Snap a bill to begin'),
              ),
            ),
          const SizedBox(height: 16),
          if (_busy)
            const LinearProgressIndicator(minHeight: 4),
          const SizedBox(height: 16),

          // Detected total row
          Row(
            children: [
              Expanded(
                child: Text(
                  'Detected total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _detectedTotal == null ? '—' : currency.fmt(_baseTotal),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          if (_rawText.isNotEmpty && _detectedTotal == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Couldn’t confidently find a total. Try a clearer shot or adjust lighting.',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ),

          const SizedBox(height: 12),
          // Manual override
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Manual total (optional)',
                    prefixText: 'R ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final val = double.tryParse(v.replaceAll(',', '.'));
                    setState(() {
                      if (val != null && val > 0) {
                        _detectedTotal = val;
                      }
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Text('Tip', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [0.1, 0.12, 0.15].map((p) {
              final selected = (p - _tipPercent).abs() < 0.001;
              return ChoiceChip(
                label: Text('${(p * 100).toStringAsFixed(0)}%'),
                selected: selected,
                onSelected: (_) => setState(() => _tipPercent = p),
              );
            }).toList(),
          ),
          Slider(
            value: _tipPercent,
            min: 0.0,
            max: 0.25,
            divisions: 25,
            label: '${(_tipPercent * 100).toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _tipPercent = v),
          ),
          Row(
            children: [
              Switch(
                value: _roundUp,
                onChanged: (v) => setState(() => _roundUp = v),
              ),
              const Text('Round up to nearest R5')
            ],
          ),

          const SizedBox(height: 8),
          Text('Split', style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _split.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_split',
                  onChanged: (v) => setState(() => _split = v.round()),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '$_split',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          _TotalsCard(
            base: _baseTotal,
            tip: _tipAmount,
            grand: _grandTotal,
            perPerson: _perPerson,
            currency: currency,
            split: _split,
          ),

          const SizedBox(height: 24),
          if (_rawText.isNotEmpty)
            ExpansionTile(
              title: const Text('OCR text (debug)'),
              initiallyExpanded: false,
              children: [
                SelectableText(_rawText, style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 12),
              ],
            ),
        ],
      ),
    );
  }
}

// Display card for totals
class _TotalsCard extends StatelessWidget {
  final double base, tip, grand, perPerson;
  final NumberFormatLike currency;
  final int split;
  const _TotalsCard({
    required this.base,
    required this.tip,
    required this.grand,
    required this.perPerson,
    required this.currency,
    required this.split,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Bill total', currency.fmt(base), text),
            const SizedBox(height: 8),
            _row('Tip', currency.fmt(tip), text),
            const Divider(height: 24),
            _row('Grand total', currency.fmt(grand), text, isBold: true),
            const SizedBox(height: 8),
            _row('Per person ($split)', currency.fmt(perPerson), text),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, TextTheme text, {bool isBold = false}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: isBold ? text.titleMedium : text.bodyLarge)),
        Text(value, style: isBold ? text.titleMedium : text.bodyLarge),
      ],
    );
  }
}

/// Minimal currency helper (no intl package dependency)
class NumberFormatLike {
  final String prefix;
  NumberFormatLike(this.prefix);
  String fmt(double n) {
    final s = n.toStringAsFixed(2);
    // Simple thousands separator
    final parts = s.split('.');
    final whole = parts[0];
    final decimals = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      final idx = whole.length - 1 - i;
      buf.write(whole[idx]);
      if (i % 3 == 2 && idx != 0) buf.write(',');
    }
    final withCommas = buf.toString().split('').reversed.join();
    return '$prefix $withCommas.$decimals';
  }
}
