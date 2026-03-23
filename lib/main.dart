import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/tracker_provider.dart';
import 'widgets/add_tx_sheet.dart';
import 'models/app_models.dart';
import 'services/drive_service.dart';
import 'ledger_page.dart'; // Ledger Page ကို ချိတ်ဆက်ခြင်း

void main() {
  runApp(MultiProvider(providers: [ChangeNotifierProvider(create: (_) => TrackerProvider())], child: const DailyTrackerApp()));
}

class DailyTrackerApp extends StatelessWidget {
  const DailyTrackerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Daily Tracker', debugShowCheckedModeBanner: false, theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, background: const Color(0xFFF5F7FA)), useMaterial3: true), home: const MainScreen());
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [const DailyHubScreen(), const VaultScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: 'Vault'),
        ],
      ),
    );
  }
}

// --- DAILY HUB ---
class DailyHubScreen extends StatelessWidget {
  const DailyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('The Daily Hub', style: TextStyle(fontWeight: FontWeight.bold))),
      body: provider.isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          const SizedBox(height: 20),
          const Text('Current Balance', style: TextStyle(color: Colors.grey)),
          Text(provider.formatLakh(provider.totalBalance), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: provider.totalBalance < 0 ? Colors.redAccent : Colors.blueAccent)),
          Text('Monthly Expenses: -${NumberFormat('#,###').format(provider.currentMonthExpense)} Ks', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: provider.transactions.length,
              itemBuilder: (context, index) {
                final tx = provider.transactions[index];
                bool isExp = ['Expense', 'HomeTransfer', 'BankDeposit', 'HusbandDeposit'].contains(tx.type);
                final cat = provider.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => AppCategory(name: 'Unknown', iconData: 0, type: ''));

                return Dismissible(
                  key: Key('hub-${tx.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (dir) async {
                    return await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm'), content: const Text('Delete this record?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE')),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    provider.deleteTransaction(tx.id!);
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Deleted'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.only(bottom: 90, left: 20, right: 20)));
                  },
                  background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: isExp ? Colors.red[50] : Colors.green[50], child: Icon(IconData(cat.iconData, fontFamily: 'MaterialIcons'), color: isExp ? Colors.redAccent : Colors.green)),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(tx.note),
                    trailing: Text('${isExp ? '-' : '+'}${NumberFormat('#,###').format(tx.amount)}', style: TextStyle(color: isExp ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))), child: const AddTxSheet(txType: 'Expense', title: 'Add Expense'))),
        backgroundColor: Colors.redAccent, child: const Icon(Icons.remove, color: Colors.white),
      ),
    );
  }
}

// --- VAULT ---
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isDialOpen = false;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 4, vsync: this); _tabController.addListener(() => setState(() {})); }

  Widget _buildAccordion(String period) {
    final provider = Provider.of<TrackerProvider>(context);
    final inSum = provider.getSummaryByTypeAndCategory(period, 'In');
    final outSum = provider.getSummaryByTypeAndCategory(period, 'Out');

    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _buildAssetBox(provider),
        ExpansionTile(
          title: Text("Total In (${provider.formatLakh(provider.getPeriodTotal(period, 'In'))})", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          children: inSum.entries.map((e) => ListTile(title: Text(e.key), trailing: Text('+${provider.formatLakh(e.value)}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LedgerPage(initialLabel: e.key))))).toList(),
        ),
        ExpansionTile(
          title: Text("Total Out (${provider.formatLakh(provider.getPeriodTotal(period, 'Out'))})", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          children: outSum.entries.map((e) => ListTile(title: Text(e.key), trailing: Text('-${provider.formatLakh(e.value)}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LedgerPage(initialLabel: e.key))))).toList(),
        ),
      ],
    );
  }

  Widget _buildAssetBox(TrackerProvider p) {
    return Container(
      padding: const EdgeInsets.all(15), margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        const Text('Total Assets', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        Text('${p.formatLakh(p.totalAssets)} Ks', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: p.wallets.map((w) => Column(children: [Text(w.name, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(p.formatLakh(w.amount), style: const TextStyle(fontWeight: FontWeight.bold))])).toList())
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Vault'), bottom: TabBar(controller: _tabController, isScrollable: true, tabs: const [Tab(text: 'Monthly'), Tab(text: 'Yearly'), Tab(text: 'Overview'), Tab(text: 'More')])),
      body: TabBarView(controller: _tabController, children: [_buildAccordion('Monthly'), _buildAccordion('Yearly'), _buildAccordion('Overview'), const SettingsView()]),
      floatingActionButton: _tabController.index == 3 ? null : FloatingActionButton(
        onPressed: () => setState(() => _isDialOpen = !_isDialOpen),
        child: Icon(_isDialOpen ? Icons.close : Icons.add),
      ),
      // Speed Dial logic simplified for brevity
    );
  }
}

// --- SETTINGS ---
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isSyncing = false;
  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(title: const Text('Lakh Format'), value: p.isLakhEnabled, onChanged: (v) => p.toggleLakh(v)),
        ListTile(
          leading: const Icon(Icons.cloud_upload), title: const Text('Backup to Drive'),
          trailing: _isSyncing ? const CircularProgressIndicator() : const Icon(Icons.chevron_right),
          onTap: () async { setState(() => _isSyncing = true); await GoogleDriveService().backupDatabase(); p.updateSyncTime(); setState(() => _isSyncing = false); },
        ),
      ],
    );
  }
}
