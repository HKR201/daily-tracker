import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/tracker_provider.dart';
import 'widgets/add_tx_sheet.dart';
import 'ledger_page.dart';
import 'services/drive_service.dart';

void main() { runApp(MultiProvider(providers: [ChangeNotifierProvider(create: (_) => TrackerProvider())], child: const DailyTrackerApp())); }

class DailyTrackerApp extends StatelessWidget {
  const DailyTrackerApp({super.key});
  @override
  Widget build(BuildContext context) { return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(useMaterial3: true), home: const MainScreen()); }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;
  final _tabs = [const DailyHubScreen(), const VaultScreen()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _tabs[_idx], bottomNavigationBar: NavigationBar(selectedIndex: _idx, onDestinationSelected: (i) => setState(() => _idx = i), destinations: const [NavigationDestination(icon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.account_tree), label: 'Vault')]));
  }
}

class DailyHubScreen extends StatelessWidget {
  const DailyHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Hub')),
      body: Column(children: [
        const SizedBox(height: 20),
        Text('Current Balance', style: const TextStyle(color: Colors.grey)),
        Text(p.formatLakh(p.totalBalance), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        Text('Monthly Expenses: -${NumberFormat('#,###').format(p.currentMonthExpense)} Ks', style: const TextStyle(color: Colors.red)),
        Expanded(child: ListView.builder(itemCount: p.transactions.length, itemBuilder: (ctx, i) {
          final tx = p.transactions[i];
          return Dismissible(
            key: Key('hub-${tx.id}'),
            confirmDismiss: (dir) async => await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Delete?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes'))])),
            onDismissed: (_) => p.deleteTransaction(tx.id!),
            child: ListTile(title: Text(tx.note), trailing: Text(p.formatLakh(tx.amount))),
          );
        }))
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (c) => AddTxSheet(txType: 'Expense', title: 'Add Expense')), child: const Icon(Icons.remove)),
    );
  }
}

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with TickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Vault'), bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'Monthly'), Tab(text: 'Yearly'), Tab(text: 'Overview'), Tab(text: 'More')])),
      body: TabBarView(controller: _tab, children: [_buildAccordion(p, 'Monthly'), _buildAccordion(p, 'Yearly'), const Center(child: Text('Overview')), const SettingsView()]),
    );
  }

  Widget _buildAccordion(TrackerProvider p, String period) {
    final inSum = p.getSummaryByTypeAndCategory(period, 'In');
    final outSum = p.getSummaryByTypeAndCategory(period, 'Out');
    return ListView(padding: const EdgeInsets.all(15), children: [
      _buildAssetBox(p),
      ExpansionTile(title: const Text('Total In'), children: inSum.entries.map((e) => ListTile(title: Text(e.key), trailing: Text(p.formatLakh(e.value)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LedgerPage(initialLabel: e.key))))).toList()),
      ExpansionTile(title: const Text('Total Out'), children: outSum.entries.map((e) => ListTile(title: Text(e.key), trailing: Text(p.formatLakh(e.value)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LedgerPage(initialLabel: e.key))))).toList()),
    ]);
  }

  Widget _buildAssetBox(TrackerProvider p) {
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Column(children: [
      const Text('Total Assets'), Text(p.formatLakh(p.totalAssets), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: p.wallets.map((w) => Column(children: [Text(w.name), Text(p.formatLakh(w.amount))])).toList())
    ]));
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      SwitchListTile(title: const Text('Lakh Format'), value: p.isLakhEnabled, onChanged: (v) => p.toggleLakh(v)),
      ListTile(leading: const Icon(Icons.cloud_upload), title: const Text('Backup'), onTap: () => GoogleDriveService().backupDatabase()),
    ]);
  }
}
