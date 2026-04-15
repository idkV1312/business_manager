import 'package:flutter/material.dart';

class PrimaryScaffold extends StatelessWidget {
  const PrimaryScaffold({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final Widget body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (action != null) Padding(padding: const EdgeInsets.only(right: 12), child: action),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: body,
        ),
      ),
    );
  }
}
