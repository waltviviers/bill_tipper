import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() => runApp(const BillTipperApp());

class BillTipperApp extends StatelessWidget {
  const BillTipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bill Tipper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF69F0AE),
          surface: Color(0xFF1A1A1A),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFF69F0AE),
          thumbColor: Colors.white,
          inactiveTrackColor: Colors.white24,
          overlayColor: const Color(0x2269F0AE),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0xFF69F0AE)
                : Colors.grey[600],
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0x6669F0AE)
                : Colors.white12,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF69F0AE), width: 2),
          ),
          filled: true,
          fillColor: Color(0xFF1A1A1A),
          labelStyle: TextStyle(color: Colors.white54),
          prefixStyle: TextStyle(color: Colors.white70, fontSize: 16),
          hintStyle: TextStyle(color: Colors.white24),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        dividerColor: Colors.white12,
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
  final _billController = TextEditingController();
  final _picker = ImagePicker();
  File? _lastPhoto;
  bool _isScanning = false;

  double _tipPercent = 10;
  bool _roundToR5 = true;
  int _splitCount = 1;

  @override
  void dispose() {
    _billController.dispose();
    super.dispose();
  }

  double _parseBill() =>
      double.tryParse(_billController.text.replaceAll(',', '.')) ?? 0.0;

  double get _totalWithTip {
    final bill = _parseBill();
    final withTip = bill + bill * (_tipPercent / 100.0);
    if (!_roundToR5) return withTip;
    final remainder = withTip % 5;
    return remainder == 0 ? withTip : withTip + (5 - remainder);
  }

  double get _perPerson => _totalWithTip / _splitCount;

  Future<void> _scanBillWithCamera() async {
    final XFile? shot =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (shot == null) return;

    setState(() {
      _isScanning = true;
      _lastPhoto = File(shot.path);
    });

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(shot.path),
      );
      final detected = _extractTotal(result.text);

      if (!mounted) return;
      if (detected != null) {
        _billController.text = detected.toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Scanned: R${detected.toStringAsFixed(2)}'),
          backgroundColor: const Color(0xFF1E1E1E),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't detect a total — enter it manually."),
          backgroundColor: Color(0xFF1E1E1E),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Scan failed: $e'),
          backgroundColor: Colors.red[900],
        ));
      }
    } finally {
      recognizer.close();
      if (mounted) setState(() => _isScanning = false);
    }
  }

  double? _extractTotal(String text) {
    // Matches amounts like 249.90 / 1 249,90 / 1234,90
    final numRx = RegExp(
      r'(\d{1,3}(?:[.,\s]\d{3})*[.,]\d{2}|\d+[.,]\d{2})',
    );

    // SA receipt keywords (English + Afrikaans)
    final kwRx = RegExp(
      r'\b(total|due|amount|owing|to pay|te betaal|subtotal|sub-total|totaal)\b',
      caseSensitive: false,
    );

    // First pass: prefer lines with total-related keywords
    double? keywordBest;
    for (final line in text.split('\n')) {
      if (!kwRx.hasMatch(line)) continue;
      for (final m in numRx.allMatches(line)) {
        final v = _parseAmount(m.group(0)!);
        if (v != null && (keywordBest == null || v > keywordBest)) {
          keywordBest = v;
        }
      }
    }
    if (keywordBest != null) return keywordBest;

    // Fallback: largest number on the receipt
    double? best;
    for (final m in numRx.allMatches(text)) {
      final v = _parseAmount(m.group(0)!);
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

  double? _parseAmount(String raw) {
    var s = raw.replaceAll(RegExp(r'\s'), '');
    // Handle SA comma-decimal: 249,90 → 249.90
    if (RegExp(r',\d{2}$').hasMatch(s)) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
    final v = double.tryParse(s);
    // Sanity check: ignore absurdly large numbers (e.g. loyalty card codes)
    return (v != null && v < 100000) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final bill = _parseBill();
    final tipValue = bill * (_tipPercent / 100.0);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Logo header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Image.asset('assets/bt_logo.png', height: 120, fit: BoxFit.contain),
            ),

            const SizedBox(height: 20),

            // Total card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    _splitCount > 1 ? 'PER PERSON' : 'TOTAL',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fmt(_perPerson),
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF69F0AE),
                      height: 1,
                      shadows: [
                        Shadow(color: Color(0xFF69F0AE), blurRadius: 24),
                        Shadow(color: Color(0xFF69F0AE), blurRadius: 48),
                        Shadow(color: Color(0x8069F0AE), blurRadius: 80),
                      ],
                    ),
                  ),
                  if (_splitCount > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Total bill: ${_fmt(_totalWithTip)}',
                      style: const TextStyle(color: Colors.white30, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Scan button + thumbnail
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _scanBillWithCamera,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                    label: Text(_isScanning ? 'Scanning…' : 'Scan bill'),
                  ),
                ),
                if (_lastPhoto != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _lastPhoto!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Bill input
            TextField(
              controller: _billController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 20, color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Bill amount',
                hintText: '0.00',
                prefixText: 'R ',
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 20),

            // Tip slider
            _LabelRow(
              label: 'Tip',
              trailing: Text(
                '${_tipPercent.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              child: Slider(
                min: 0,
                max: 30,
                divisions: 30,
                value: _tipPercent,
                label: '${_tipPercent.toStringAsFixed(0)}%',
                onChanged: (v) => setState(() => _tipPercent = v),
              ),
            ),

            const SizedBox(height: 4),

            // Split row
            _LabelRow(
              label: 'Split',
              trailing: Text(
                _splitCount == 1 ? '1 person' : '$_splitCount people',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed:
                        _splitCount > 1 ? () => setState(() => _splitCount--) : null,
                  ),
                  Text(
                    '$_splitCount',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _splitCount++),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Round toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Round up to nearest R5',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              value: _roundToR5,
              onChanged: (v) => setState(() => _roundToR5 = v),
            ),

            const Divider(height: 32),

            _MoneyRow(label: 'Bill', value: bill),
            _MoneyRow(label: 'Tip (${_tipPercent.toStringAsFixed(0)}%)', value: tipValue),

            const SizedBox(height: 24),

            // Footer
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://www.instagram.com/waltviviers/'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.instagram, size: 11, color: Colors.white24),
                  SizedBox(width: 5),
                  Text(
                    'created by @waltviviers',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v.isNaN || v.isInfinite ? 'R0.00' : 'R${v.toStringAsFixed(2)}';
}

class _LabelRow extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget trailing;

  const _LabelRow({
    required this.label,
    required this.child,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        Expanded(child: child),
        trailing,
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final double value;
  const _MoneyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15, color: Colors.white54)),
          ),
          Text(
            'R${value.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
