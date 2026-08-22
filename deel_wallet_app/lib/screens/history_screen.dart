import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Historique')),
        body: FutureBuilder(
          future: Repo.transactions(),
          builder: (_, snap) => ListView(
            padding: const EdgeInsets.all(16),
            children: (snap.data ?? [])
                .map((t) => ListTile(
                      leading: CircleAvatar(child: Text(t.initials)),
                      title: Text(t.name),
                      subtitle: Text(
                          '${t.note} • ${t.date.day}/${t.date.month}/${t.date.year}'),
                      trailing: Text(
                        money(t.amount.abs()),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: t.amount >= 0 ? brandGreen : Colors.black87),
                      ),
                    ))
                .toList(),
          ),
        ),
      );
}
