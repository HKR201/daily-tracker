import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/tracker_provider.dart';
import '../models/app_models.dart';

class LedgerPage extends StatelessWidget {
  final String title;
  final String filterCategory; // နှိပ်လိုက်တဲ့ Label နာမည်

  const LedgerPage({super.key, required this.title, required this.filterCategory});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    // Label အလိုက် Filter စစ်ထုတ်ခြင်း
    final filteredList = provider.transactions.where((tx) {
      final cat = provider.categories.firstWhere((c) => c.id == tx.categoryId);
      return cat.name == filterCategory;
    }).toList();

    double total = filteredList.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('$filterCategory Ledger'),
        actions: [IconButton(icon: const Icon(Icons.filter_list), onPressed: () {})],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: Colors.white,
            child: Column(
              children: [
                Text('Total for $filterCategory', style: const TextStyle(color: Colors.grey)),
                Text('${provider.formatLakh(total)} Ks', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final tx = filteredList[index];
                return Dismissible(
                  key: Key(tx.id.toString()),
                  direction: DismissDirection.endToStart, // ညာမှဘယ်သို့ဆွဲလျှင်ဖျက်မည်
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    provider.deleteTransaction(tx.id!);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction Deleted'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating));
                  },
                  child: ListTile(
                    leading: CircleAvatar(child: Text(DateFormat('dd').format(DateTime.parse(tx.dateTimestamp)))),
                    title: Text(DateFormat('MMMM yyyy').format(DateTime.parse(tx.dateTimestamp))),
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
}
