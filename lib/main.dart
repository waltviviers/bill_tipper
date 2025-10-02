return MaterialApp(
  title: 'Bill Tipper',
  debugShowCheckedModeBanner: false,

  // (optional) light theme — kept for completeness
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    useMaterial3: true,
  ),

  // Dark theme we’ll actually use
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),

  // Force dark mode
  themeMode: ThemeMode.dark,

  home: const BillHomePage(),
);