import 'package:flutter/material.dart';

class CustomerHistoryScreen extends StatelessWidget {
  const CustomerHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer History / பழைய வாடிக்கையாளர்கள்')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5, // Mock data
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('Customer ${index + 1}'),
              subtitle: const Text('+91 9876543210'),
              trailing: const Text('Last: ₹40', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                // Reuse last order logic
              },
            ),
          );
        },
      ),
    );
  }
}
