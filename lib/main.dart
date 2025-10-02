import 'package:flutter/material.dart';

void main() {
  runApp(const BillTipperApp());
}

class BillTipperApp extends StatelessWidget {
  const BillTipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bill Tipper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          centerTitle: true,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/bt_logo.png',
          height: 40, // adjust to fit nicely
        ),
      ),
      body: const Center(
        child: Text(
          'Welcome to Bill Tipper!',
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
      ),
    );
  }
}