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
  String _selectedTimeframe = 'All';

  @override
  void initState() {
    super.initState();
    _selectedLabel = widget.initialLabel;
  }

  List<AppTransaction> _filterTransactions(List<AppTransaction> list, List<AppCategory> cats) {
    DateTime now = DateTime.now();
    return list.where((tx) {
      // 1. Label Filter
      final cat = cats.firstWhere((c) => c.id == tx.categoryId);
      bool labelMatch = (_selectedLabel == 'All') ? true : (cat.name == _selectedLabel);
      
      // 2. Timeframe Filter
      DateTime txDate = DateTime.parse(tx.dateTimestamp);
      bool timeMatch = true;
      if (_selectedTimeframe == 'Weekly') {
        timeMatch = txDate.isAfter(now.subtract(const Duration(days: 7)));
      } else if (_selectedTimeframe == 'Monthly') {
        timeMatch = (txDate.year == now.year && txDate.month == now.month);
      } else if (_selectedTimeframe == 'Yearly') {
        timeMatch = (txDate.year == now.year);
      }
      
      return labelMatch && timeMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final filteredList = _filterTransactions(provider.transactions, provider.categories);
    double total = filteredList.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Ledger'), backgroundColor: Colors.white),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedLabel,
                    items: ['All', ...provider.categories.map((c) => c.name).toSet()].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _selectedLabel = v!),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedTimeframe,
                    items: ['All', 'Weekly', 'Monthly', 'Yearly'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _selectedTimeframe = v!),
                  ),
                ),
              ],
            ),
          ),
          
          // Summary Header
          Container(
            padding: const EdgeInsets.all(20), width: double.infinity, color: Colors.blueAccent.withOpacity(0.05),
            child: Column(children: [
              Text('Total for $_selectedLabel ($_selectedTimeframe)', style: const TextStyle(color: Colors.grey)),
              Text('${provider.formatLakh(total)} Ks', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent))
            ]),
          ),

          // Transaction List with Safety Delete
          Expanded(
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final tx = filteredList[index];
                return Dismissible(
                  key: Key('ledger-${tx.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    // Swipe လုပ်လိုက်လျှင် Confirm Dialog တက်လာမည် (မှားဖျက်မိခြင်းမှ ကာကွယ်ရန်)
                    return await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm Delete'),
                        content: const Text('Are you sure you want to delete this record?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(ctx, true), 
                            child: const Text('DELETE', style: TextStyle(color: Colors.white))
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    provider.deleteTransaction(tx.id!);
                    _showUndoSnackBar(context, provider);
                  },
                  background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Text('CONFIRM DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(DateFormat('dd').format(DateTime.parse(tx.dateTimestamp)))),
                    title: Text(DateFormat('dd MMM yyyy').format(DateTime.parse(tx.dateTimestamp))),
                    subtitle: Text(tx.note.isEmpty ? 'No Note' : tx.note),
                    trailing: Text(provider.formatLakh(tx.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showUndoSnackBar(BuildContext context, TrackerProvider provider) {
    ScaffoldMessenger.of(context).clearSnackBars(); // အဟောင်းကိုဖျက်
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Record deleted'),
        duration: const Duration(seconds: 3), // ၃ စက္ကန့်အတွင်း အလိုလိုပျောက်မည်
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'UNDO', onPressed: () { /* Undo Logic can be added if needed */ }),
      )
    );
  }
}
