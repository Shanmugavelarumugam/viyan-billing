import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DrawerPlaceholderScreen extends ConsumerWidget {
  final String title;
  const DrawerPlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/billing');
            }
          },
        ),
      ),
      body: Center(
        child: Text(
          '$title Content',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
