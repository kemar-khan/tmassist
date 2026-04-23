// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/in_memory_store.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => InMemoryStore(),
      child: const App(),
    ),
  );
}