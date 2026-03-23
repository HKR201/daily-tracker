import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/tracker_provider.dart';
import 'widgets/add_tx_sheet.dart';
import 'models/app_models.dart';
import 'services/drive_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => TrackerProvider())],
      child: const DailyTrackerApp(),
    ),
  );
}

class DailyTrackerApp extends StatelessWidget {
  const DailyTrackerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, background: const Color(0xFFF5F7FA)),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_filled, color: Colors.blueAccent), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree, color: Colors.blueAccent), label: 'Vault'),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 1: THE DAILY HUB (Current Balance & History)
// ==========================================
class DailyHubScreen extends StatefulWidget {
  const DailyHubScreen({super.key});
  @override
  State<DailyHubScreen> createState() => _DailyHubScreenState();
}

class _DailyHubScreenState extends State<DailyHubScreen> {
  bool _showFullBalance = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final currencyFormat = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(title: const Text('The Daily Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)), backgroundColor: Colors.transparent, elevation: 0),
      body: provider.isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          const SizedBox(height: 20),
          const Text('Current Balance (လက်ကျန်ငွေ)', style: TextStyle(color: Colors.grey, fontSize: 16)),
          GestureDetector(
            onTap: () => setState(() {
              _showFullBalance = true;
              Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _showFullBalance = false); });
            }),
            child: Text(
              _showFullBalance ? '${currencyFormat.format(provider.totalBalance)} Ks' : '${provider.formatLakh(provider.totalBalance)} Ks',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: provider.totalBalance < 0 ? Colors.redAccent : Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 5),
          Text('Monthly Expenses: -${currencyFormat.format(provider.currentMonthExpense)} Ks', 
               style: const TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
              child: provider.transactions.isEmpty ? const Center(child: Text('No Transactions Yet', style: TextStyle(color: Colors.grey))) : ListView.builder(
                itemCount: provider.transactions.length,
                itemBuilder: (context, index) {
                  final tx = provider.transactions[index];
                  bool isExpense = ['Expense', 'HomeTransfer', 'BankDeposit', 'HusbandDeposit'].contains(tx.type);
                  final cat = provider.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => AppCategory(name: 'Unknown', iconData: 0xe000, type: 'Expense'));

                  return Dismissible(
                    key: Key(tx.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      provider.deleteTransaction(tx.id!);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Deleted successfully'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.only(bottom: 90, left: 20, right: 20))
                      );
                    },
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: isExpense ? Colors.red[50] : Colors.green[50], child: Icon(IconData(cat.iconData, fontFamily: 'MaterialIcons'), color: isExpense ? Colors.redAccent : Colors.green)),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(tx.note.isEmpty ? 'No Note' : tx.note),
                      trailing: Text('${isExpense ? '-' : '+'}${currencyFormat.format(tx.amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isExpense ? Colors.redAccent : Colors.green)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))), child: const AddTxSheet(txType: 'Expense', title: 'Add Expense (ထွက်ငွေ)'))),
        backgroundColor: Colors.redAccent, elevation: 4, child: const Icon(Icons.remove, color: Colors.white, size: 28),
      ),
    );
  }
}

// ==========================================
// SCREEN 2: THE VAULT (Accordion Summary)
// ==========================================
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with TickerProviderStateMixin {
  bool _isDialOpen = false;
  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _expandAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _toggleDial() {
    setState(() { _isDialOpen = !_isDialOpen; _isDialOpen ? _animController.forward() : _animController.reverse(); });
  }

  void _openSheet(String type, String title) {
    _toggleDial();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))), child: AddTxSheet(txType: type, title: title)));
  }

  Widget _buildDialButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
            const SizedBox(width: 15),
            FloatingActionButton(heroTag: title, mini: true, backgroundColor: color, onPressed: onTap, child: Icon(icon, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionView(String period) {
    final provider = Provider.of<TrackerProvider>(context);
    final inSummary = provider.getSummaryByTypeAndCategory(period, 'In');
    final outSummary = provider.getSummaryByTypeAndCategory(period, 'Out');

    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _buildAssetBox(provider),
        ExpansionTile(
          title: Text("Total In (${provider.formatLakh(provider.getPeriodTotal(period, 'In'))})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          leading: const Icon(Icons.arrow_downward, color: Colors.green),
          children: inSummary.entries.map((e) => ListTile(
            title: Text(e.key),
            trailing: Text('+${provider.formatLakh(e.value)}', style: const TextStyle(color: Colors.green)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LedgerPage(filterCategory: e.key))),
          )).toList(),
        ),
        ExpansionTile(
          title: Text("Total Out (${provider.formatLakh(provider.getPeriodTotal(period, 'Out'))})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          leading: const Icon(Icons.arrow_upward, color: Colors.redAccent),
          children: outSummary.entries.map((e) => ListTile(
            title: Text(e.key),
            trailing: Text('-${provider.formatLakh(e.value)}', style: const TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LedgerPage(filterCategory: e.key))),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildAssetBox(TrackerProvider provider) {
    return Container(
      padding: const EdgeInsets.all(15), margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          const Text('Total Assets (စုစုပေါင်း ပိုင်ဆိုင်မှု)', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('${provider.formatLakh(provider.totalAssets)} Ks', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: provider.wallets.map((w) => Column(children: [Text(w.name, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(provider.formatLakh(w.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))])).toList(),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
        backgroundColor: Colors.transparent, elevation: 0,
        bottom: TabBar(
          controller: _tabController, isScrollable: true, labelColor: Colors.blueAccent, unselectedLabelColor: Colors.grey, indicatorColor: Colors.blueAccent,
          tabs: const [Tab(text: 'Monthly'), Tab(text: 'Yearly'), Tab(text: 'Overview'), Tab(text: 'More')],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(controller: _tabController, children: [_buildAccordionView('Monthly'), _buildAccordionView('Yearly'), _buildAccordionView('Overview'), const SettingsView()]),
          if (_isDialOpen) GestureDetector(onTap: _toggleDial, child: Container(color: Colors.black.withOpacity(0.3))),
        ],
      ),
      floatingActionButton: _tabController.index == 3 ? null : Column(
        mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildDialButton('ယောကျ်ားအပ်ငွေ', Icons.person, Colors.purple, () => _openSheet('HusbandDeposit', 'ယောကျ်ားအပ်ငွေ')),
                _buildDialButton('ဘဏ်အပ်ငွေ', Icons.account_balance, Colors.orange, () => _openSheet('BankDeposit', 'ဘဏ်အပ်ငွေ')),
                _buildDialButton('အိမ်လွှဲငွေ', Icons.home, Colors.teal, () => _openSheet('HomeTransfer', 'အိမ်လွှဲငွေ')),
                _buildDialButton('ဝင်ငွေ', Icons.attach_money, Colors.green, () => _openSheet('Income', 'Income (ဝင်ငွေ)')),
              ],
            ),
          ),
          FloatingActionButton(
            heroTag: 'MainVaultFab', onPressed: _toggleDial, backgroundColor: _isDialOpen ? Colors.grey : Colors.blueAccent,
            child: AnimatedRotation(turns: _isDialOpen ? 0.125 : 0, duration: const Duration(milliseconds: 250), child: const Icon(Icons.add, color: Colors.white, size: 28)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 3: LEDGER PAGE (Detailed History)
// ==========================================
class LedgerPage extends StatelessWidget {
  final String filterCategory;
  const LedgerPage({super.key, required this.filterCategory});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final currencyFormat = NumberFormat('#,###');
    final filteredList = provider.transactions.where((tx) {
      final cat = provider.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => AppCategory(name: 'Unknown', iconData: 0, type: ''));
      return cat.name == filterCategory;
    }).toList();

    double total = filteredList.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(title: Text('$filterCategory Ledger'), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(25), width: double.infinity, color: Colors.white,
            child: Column(children: [const Text('Total for this Label', style: TextStyle(color: Colors.grey)), Text('${provider.formatLakh(total)} Ks', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent))]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final tx = filteredList[index];
                return Dismissible(
                  key: Key(tx.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                  onDismissed: (_) => provider.deleteTransaction(tx.id!),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(DateFormat('dd').format(DateTime.parse(tx.dateTimestamp)))),
                    title: Text(DateFormat('dd MMM yyyy').format(DateTime.parse(tx.dateTimestamp))),
                    subtitle: Text(tx.note.isEmpty ? 'No Note' : tx.note),
                    trailing: Text(currencyFormat.format(tx.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

// ==========================================
// SETTINGS VIEW (Google Drive Backup)
// ==========================================
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final GoogleDriveService _driveService = GoogleDriveService();
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: SwitchListTile(title: const Text('Lakh Format', style: TextStyle(fontWeight: FontWeight.bold)), value: provider.isLakhEnabled, activeColor: Colors.blueAccent, onChanged: (val) => provider.toggleLakh(val))),
        const SizedBox(height: 30),
        const Text('Cloud Backup', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.cloud_upload, color: Colors.blueAccent), title: const Text('Backup to Google Drive'), subtitle: Text('Last synced: ${provider.lastSyncTime}'), trailing: _isSyncing ? const CircularProgressIndicator() : const Icon(Icons.chevron_right), onTap: () async { setState(() => _isSyncing = true); await _driveService.backupDatabase(); provider.updateSyncTime(); setState(() => _isSyncing = false); }),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.cloud_download, color: Colors.green), title: const Text('Restore from Google Drive'), trailing: _isSyncing ? const CircularProgressIndicator() : const Icon(Icons.chevron_right), onTap: () async { setState(() => _isSyncing = true); await _driveService.restoreDatabase(); provider.loadAllData(); setState(() => _isSyncing = false); }),
            ],
          ),
        ),
      ],
    );
  }
}
