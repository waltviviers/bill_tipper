import 'package:flutter/material.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() {
  runApp(BillTipperApp());
}

class BillTipperApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bill Tipper',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Color(0xFF121212),
        colorScheme: ColorScheme.dark(
          primary: Colors.teal,
          secondary: Colors.tealAccent,
        ),
      ),
      home: BillSplitter(),
    );
  }
}

class BillSplitter extends StatefulWidget {
  @override
  _BillSplitterState createState() => _BillSplitterState();
}

class _BillSplitterState extends State<BillSplitter> {
  final TextEditingController _billController = TextEditingController();
  double _tipPercentage = 0.10; // Default 10%
  int _splitCount = 1;
  double _billAmount = 0.0;

  final ImagePicker _picker = ImagePicker();
  XFile? _billImage;

  void _calculateBill() {
    setState(() {
      _billAmount = double.tryParse(_billController.text) ?? 0.0;
    });
  }

  // Rounds number UP to nearest 5
  double _roundUpToNearestFive(double value) {
    return (value % 5 == 0) ? value : (5 * ((value / 5).ceil()));
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    setState(() {
      _billImage = photo;
    });
  }

  @override
  Widget build(BuildContext context) {
    double tipAmount = _billAmount * _tipPercentage;
    double total = _billAmount + tipAmount;
    double roundedTotal = _roundUpToNearestFive(total);
    double perPerson = roundedTotal / _splitCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bill Tipper'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/bt_logo.png',
                height: 120, // made bigger
              ),
              SizedBox(height: 16),

              // Highlighted rounded total under logo
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Final Total: ${roundedTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Bill input
              TextField(
                controller: _billController,
                decoration: InputDecoration(
                  labelText: 'Bill total',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _calculateBill(),
              ),
              SizedBox(height: 20),

              // Tip percentage
              Text('Tip %'),
              Wrap(
                spacing: 10,
                children: [10, 12, 15, 18, 20].map((percent) {
                  return ChoiceChip(
                    label: Text('$percent%'),
                    selected: _tipPercentage == percent / 100,
                    onSelected: (_) {
                      setState(() {
                        _tipPercentage = percent / 100;
                      });
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 20),

              // Split
              Text('Split'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () {
                      setState(() {
                        if (_splitCount > 1) _splitCount--;
                      });
                    },
                  ),
                  Text('$_splitCount'),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        _splitCount++;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Results
              Text('Results'),
              Card(
                child: ListTile(
                  title: Text('Bill'),
                  trailing: Text('${_billAmount.toStringAsFixed(2)}'),
                ),
              ),
              Card(
                child: ListTile(
                  title: Text('Tip (${(_tipPercentage * 100).toInt()}%)'),
                  trailing: Text('${tipAmount.toStringAsFixed(2)}'),
                ),
              ),
              Card(
                child: ListTile(
                  title: Text('Non-Rounded Total'),
                  trailing: Text('${total.toStringAsFixed(2)}'),
                ),
              ),
              Card(
                color: Colors.teal.withOpacity(0.2),
                child: ListTile(
                  title: Text(
                    'Rounded Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    '${roundedTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.tealAccent),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  title: Text('Per Person'),
                  trailing: Text('${perPerson.toStringAsFixed(2)}'),
                ),
              ),
              SizedBox(height: 20),

              // Camera button
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: Icon(Icons.camera_alt),
                label: Text('Take Photo of Bill'),
              ),
              if (_billImage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.file(
                    File(_billImage!.path),
                    height: 200,
                  ),
                ),
              SizedBox(height: 20),

              // Reset button
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _billController.clear();
                    _billAmount = 0.0;
                    _tipPercentage = 0.10; // reset to 10%
                    _splitCount = 1;
                    _billImage = null;
                  });
                },
                child: Text('Reset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}