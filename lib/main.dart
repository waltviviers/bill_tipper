import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() => runApp(const BillTipperApp());

class BillTipperApp extends StatefulWidget {
  const BillTipperApp({super.key});
  @override
  State<BillTipperApp> createState() => _BillTipperAppState();
}

class _BillTipperAppState extends State<BillTipperApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _accent = const Color(0xFF69F0AE);

  ThemeData _makeTheme(Brightness b) {
    final isDark = b == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: isDark ? Colors.black : Colors.white,
      colorScheme: base.colorScheme.copyWith(
        primary: _accent,
        secondary: _accent,
        surface: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _accent,
        thumbColor: isDark ? Colors.white : Colors.black,
        inactiveTrackColor: isDark ? Colors.white24 : Colors.black26,
        overlayColor: _accent.withOpacity(0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? _accent
              : (isDark ? Colors.grey[600] : Colors.grey[400]),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? _accent.withOpacity(0.4)
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8),
          foregroundColor: isDark ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _accent, width: 2),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        prefixStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black70, fontSize: 16),
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white70 : Colors.black54),
      dividerColor: isDark ? Colors.white12 : Colors.black12,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bill Tipper',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _makeTheme(Brightness.light),
      darkTheme: _makeTheme(Brightness.dark),
      home: BillTipperHome(
        themeMode: _themeMode,
        accent: _accent,
        onThemeModeChanged: (m) => setState(() => _themeMode = m),
        onAccentChanged: (c) => setState(() => _accent = c),
      ),
    );
  }
}

class BillTipperHome extends StatefulWidget {
  final ThemeMode themeMode;
  final Color accent;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Color> onAccentChanged;

  const BillTipperHome({
    super.key,
    required this.themeMode,
    required this.accent,
    required this.onThemeModeChanged,
    required this.onAccentChanged,
  });

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
    return bill + bill * (_tipPercent / 100.0);
  }

  double get _perPerson {
    final share = _totalWithTip / _splitCount;
    if (!_roundToR5) return share;
    final remainder = share % 5;
    return remainder == 0 ? share : share + (5 - remainder);
  }

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
          backgroundColor: Theme.of(context).colorScheme.surface,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Couldn't detect a total — enter it manually."),
          backgroundColor: Theme.of(context).colorScheme.surface,
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
    final numRx = RegExp(r'(\d{1,3}(?:[.,\s]\d{3})*[.,]\d{2}|\d+[.,]\d{2})');
    final kwRx = RegExp(
      r'\b(total|due|amount|owing|to pay|te betaal|subtotal|sub-total|totaal)\b',
      caseSensitive: false,
    );
    double? keywordBest;
    for (final line in text.split('\n')) {
      if (!kwRx.hasMatch(line)) continue;
      for (final m in numRx.allMatches(line)) {
        final v = _parseAmount(m.group(0)!);
        if (v != null && (keywordBest == null || v > keywordBest)) keywordBest = v;
      }
    }
    if (keywordBest != null) return keywordBest;
    double? best;
    for (final m in numRx.allMatches(text)) {
      final v = _parseAmount(m.group(0)!);
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

  double? _parseAmount(String raw) {
    var s = raw.replaceAll(RegExp(r'\s'), '');
    if (RegExp(r',\d{2}$').hasMatch(s)) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
    final v = double.tryParse(s);
    return (v != null && v < 100000) ? v : null;
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SettingsSheet(
        isDark: widget.themeMode == ThemeMode.dark,
        accent: widget.accent,
        onThemeToggle: (dark) {
          widget.onThemeModeChanged(dark ? ThemeMode.dark : ThemeMode.light);
          Navigator.pop(context);
        },
        onColorPicked: (c) {
          widget.onAccentChanged(c);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bill = _parseBill();
    final tipValue = bill * (_tipPercent / 100.0);
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Logo + settings button
            SizedBox(
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    color: Colors.black,
                    child: Image.asset('assets/bt_logo.png', height: 96, fit: BoxFit.contain),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: Icon(
                        Icons.palette_outlined,
                        size: 22,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      onPressed: _showSettings,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Total card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    _splitCount > 1 ? 'PER PERSON' : 'TOTAL',
                    style: TextStyle(
                      color: onSurface.withOpacity(0.38),
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fmt(_perPerson),
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      height: 1,
                      shadows: [
                        Shadow(color: accent, blurRadius: 24),
                        Shadow(color: accent, blurRadius: 48),
                        Shadow(color: accent.withOpacity(0.5), blurRadius: 80),
                      ],
                    ),
                  ),
                  if (_splitCount > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Total bill: ${_fmt(_totalWithTip)}',
                      style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 13),
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
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onSurface.withOpacity(0.5),
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
                    child: Image.file(_lastPhoto!, width: 52, height: 52, fit: BoxFit.cover),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Bill input
            TextField(
              controller: _billController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 20, color: onSurface),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _splitCount > 1 ? () => setState(() => _splitCount--) : null,
                  ),
                  Text('$_splitCount',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
              title: Text(
                'Round up to nearest R5',
                style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 13),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.instagram,
                      size: 11, color: onSurface.withOpacity(0.4)),
                  const SizedBox(width: 5),
                  Text(
                    'created by @waltviviers',
                    style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 11),
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

class _SettingsSheet extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final ValueChanged<bool> onThemeToggle;
  final ValueChanged<Color> onColorPicked;

  const _SettingsSheet({
    required this.isDark,
    required this.accent,
    required this.onThemeToggle,
    required this.onColorPicked,
  });

  static const _presets = [
    Color(0xFF69F0AE),
    Color(0xFF1DE9B6),
    Color(0xFF00E5FF),
    Color(0xFF448AFF),
    Color(0xFF7C4DFF),
    Color(0xFFE040FB),
    Color(0xFFFF4081),
    Color(0xFFFF5252),
    Color(0xFFFF6D00),
    Color(0xFFFFD740),
    Color(0xFFEEFF41),
    Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Settings',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: onSurface)),
          const SizedBox(height: 20),
          // Theme toggle
          Row(
            children: [
              Icon(Icons.light_mode_outlined,
                  size: 18, color: onSurface.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text('Light',
                  style:
                      TextStyle(color: onSurface.withOpacity(0.7), fontSize: 14)),
              const Spacer(),
              Switch(value: isDark, onChanged: onThemeToggle),
              const Spacer(),
              Text('Dark',
                  style:
                      TextStyle(color: onSurface.withOpacity(0.7), fontSize: 14)),
              const SizedBox(width: 8),
              Icon(Icons.dark_mode_outlined,
                  size: 18, color: onSurface.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Accent colour',
              style:
                  TextStyle(color: onSurface.withOpacity(0.7), fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presets
                .map((c) => GestureDetector(
                      onTap: () => onColorPicked(c),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent == c ? onSurface : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: accent == c
                              ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 10)]
                              : null,
                        ),
                        child: accent == c
                            ? Icon(
                                Icons.check,
                                size: 20,
                                color: ThemeData.estimateBrightnessForColor(c) ==
                                        Brightness.light
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget trailing;
  const _LabelRow(
      {required this.label, required this.child, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                  fontSize: 12)),
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15, color: onSurface.withOpacity(0.54))),
          ),
          Text(
            'R${value.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: onSurface.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}
