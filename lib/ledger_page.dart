import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/tracker_provider.dart';
import '../models/app_models.dart';

class LedgerPage extends StatefulWidget {
  final String initialLabel;
  const LedgerPage({super.key, required this.initialLabel});
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  String _selectedLabel = 'All';
  String _selectedTime = 'All';

  @override
  void initState() { super.initState(); _selectedLabel = widget.initialLabel; }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    final list = p.transactions.where((tx) {
      final cat = p.categories.firstWhere((c) => c.id == tx.categoryId);
      bool labelOk = (_selectedLabel == 'All') || (cat.name == _selectedLabel);
      DateTime date = DateTime.parse(tx.dateTimestamp);
      bool timeOk = (_selectedTime == 'All') || 
                   (_selectedTime == 'Monthly' && date.month == DateTime.now().month) ||
                   (_selectedTime == 'Yearly' && date.year == DateTime.now().year);
      return labelOk && timeOk;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ledger'), actions: [
        DropdownButton<String>(value: _selectedTime, items: ['All', 'Monthly', 'Yearly'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _selectedTime = v!))
      ]),
      body: ListView.builder(
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final tx = list[i];
          return Dismissible(
            key: Key(tx.id.toString()),
            confirmDismiss: (dir) async => await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Confirm Delete'), actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
            ])),
            onDismissed: (_) => p.deleteTransaction(tx.id!),
            background: Container(color: Colors.red, alignment: Alignment.centerRight, child: const Icon(Icons.delete, color: Colors.white)),
            child: ListTile(title: Text(DateFormat('dd MMM yyyy').format(DateTime.parse(tx.dateTimestamp))), subtitle: Text(tx.note), trailing: Text(p.formatLakh(tx.amount))),
          );
        },
      ),
    );
  }
}
