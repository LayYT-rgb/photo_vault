import 'package:flutter/material.dart';
import 'screens/gallery_screen.dart';

void main() {
  runApp(const PhotoVaultApp());
}

class PhotoVaultApp extends StatelessWidget {
  const PhotoVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Vault',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const GalleryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
