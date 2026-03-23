import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/tracker_provider.dart';
import 'widgets/add_tx_sheet.dart';
import 'ledger_page.dart';
import 'services/drive_service.dart';

void main() { 
  runApp(MultiProvider(providers: [ChangeNotifierProvider(create: (_) => TrackerProvider())], child: const DailyTrackerApp())); 
}

class DailyTrackerApp extends StatelessWidget {
  const DailyTrackerApp({super.key});
  @override
  Widget build(BuildContext context) { 
    final p = Provider.of<TrackerProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      themeMode: p.isDarkMode ? ThemeMode.dark : ThemeMode.light, // Dark Mode ချိန်ညှိခြင်း
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueAccent, brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF5F7FA)), 
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueAccent, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF121212)),
      home: const MainScreen()
    ); 
  }
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
    return Scaffold(
      body: _tabs[_idx], 
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx, 
        onDestinationSelected: (i) => setState(() => _idx = i), 
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'), 
          NavigationDestination(icon: Icon(Icons.account_tree), label: 'Vault')
        ]
      )
    );
  }
}

// ညာဘက်ဆွဲလျှင် Delete ခလုတ်ပေါ်လာပြီး နှိပ်မှ ဖျက်မည့် Custom Widget
class SwipeToDeleteItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  const SwipeToDeleteItem({super.key, required this.child, required this.onDelete});

  @override
  State<SwipeToDeleteItem> createState() => _SwipeToDeleteItemState();
}

class _SwipeToDeleteItemState extends State<SwipeToDeleteItem> {
  double _dragExtent = 0;
  final double _maxDrag = 80;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragExtent -= details.primaryDelta!;
          if (_dragExtent < 0) _dragExtent = 0;
          if (_dragExtent > _maxDrag) _dragExtent = _maxDrag;
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          if (_dragExtent > _maxDrag / 2) { _dragExtent = _maxDrag; } 
          else { _dragExtent = 0; }
        });
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.redAccent,
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  setState(() => _dragExtent = 0);
                  widget.onDelete(); // Delete ခလုတ်နှိပ်မှ ဖျက်မည်
                },
                child: Container(width: _maxDrag, alignment: Alignment.center, child: const Icon(Icons.delete, color: Colors.white)),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(-_dragExtent, 0),
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor, // အနောက်ခံအရောင်နဲ့ ညှိထားသည်
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
class DailyHubScreen extends StatelessWidget {
  const DailyHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('The Daily Hub')),
      body: Column(children: [
        const SizedBox(height: 20),
        const Text('Current Balance', style: TextStyle(color: Colors.grey)),
        Text(p.formatLakh(p.totalBalance), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        Text('Monthly Expenses: -${NumberFormat('#,###').format(p.currentMonthExpense)} Ks', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Expanded(child: ListView.builder(itemCount: p.transactions.length, itemBuilder: (ctx, i) {
          final tx = p.transactions[i];
          bool isExp = ['Expense', 'HomeTransfer', 'BankDeposit', 'HusbandDeposit'].contains(tx.type);
          
          return SwipeToDeleteItem(
            onDelete: () {
              p.deleteTransaction(tx.id!); // ဖျက်လိုက်မည်
              
              // SnackBar ကို ၂ စက္ကန့်နဲ့ ပျောက်အောင်နှင့် Undo လုပ်နိုင်အောင် ပြင်ဆင်ခြင်း
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Record deleted'),
                  duration: const Duration(seconds: 2), // 2 Sec အလိုလိုပျောက်မည်
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'UNDO', 
                    textColor: Colors.blueAccent,
                    onPressed: () => p.undoDelete(tx), // ပြန်ခေါ်မည်
                  ),
                )
              );
            },
            child: ListTile(
              title: Text(tx.note.isEmpty ? 'Record' : tx.note), 
              trailing: Text('${isExp ? '-' : '+'}${NumberFormat('#,###').format(tx.amount)}', style: TextStyle(color: isExp ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold))
            ),
          );
        }))
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (c) => const AddTxSheet(txType: 'Expense', title: 'Add Expense')), child: const Icon(Icons.remove)),
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
  bool _isOpen = false;
  @override
  void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); _tab.addListener(() => setState(() {})); }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('The Vault'), bottom: TabBar(controller: _tab, isScrollable: true, tabs: const [Tab(text: 'Monthly'), Tab(text: 'Yearly'), Tab(text: 'Overview'), Tab(text: 'More')])),
      body: Stack(children: [
        TabBarView(controller: _tab, children: [_buildAccordion(p, 'Monthly'), _buildAccordion(p, 'Yearly'), const Center(child: Text('Overview')), const SettingsView()]),
        if (_isOpen) GestureDetector(onTap: () => setState(() => _isOpen = false), child: Container(color: Colors.black26)),
      ]),
      floatingActionButton: _tab.index == 3 ? null : _buildFab(),
    );
  }

  Widget _buildAccordion(TrackerProvider p, String period) {
    final inSum = p.getSummaryByTypeAndCategory(period, 'In');
    final outSum = p.getSummaryByTypeAndCategory(period, 'Out');
    return ListView(padding: const EdgeInsets.all(15), children: [
      _buildAssetBox(p),
      ExpansionTile(title: Text('Total In (${p.formatLakh(p.getPeriodTotal(period, 'In'))})'), children: inSum.entries.map((e) => ListTile(title: Text(e.key), trailing: Text(p.formatLakh(e.value)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LedgerPage(initialLabel: e.key))))).toList()),
      ExpansionTile(title: Text('Total Out (${p.formatLakh(p.getPeriodTotal(period, 'Out'))})'), children: outSum.entries.map((e) => ListTile(title: Text(e.key), trailing: Text(p.formatLakh(e.value)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LedgerPage(initialLabel: e.key))))).toList()),
    ]);
  }

  Widget _buildAssetBox(TrackerProvider p) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(padding: const EdgeInsets.all(15), margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Column(children: [
      const Text('Total Assets'), Text(p.formatLakh(p.totalAssets), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: p.wallets.map((w) => Column(children: [Text(w.name, style: const TextStyle(fontSize: 12)), Text(p.formatLakh(w.amount), style: const TextStyle(fontWeight: FontWeight.bold))])).toList())
    ]));
  }

  Widget _buildFab() {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (_isOpen) ...[
        _btn('ယောကျ်ားအပ်ငွေ', () => _open('HusbandDeposit', 'ယောကျ်ားအပ်ငွေ')),
        _btn('ဘဏ်အပ်ငွေ', () => _open('BankDeposit', 'ဘဏ်အပ်ငွေ')),
        _btn('အိမ်လွှဲငွေ', () => _open('HomeTransfer', 'အိမ်လွှဲငွေ')),
        _btn('ဝင်ငွေ', () => _open('Income', 'Income (ဝင်ငွေ)')),
      ],
      FloatingActionButton(onPressed: () => setState(() => _isOpen = !_isOpen), child: Icon(_isOpen ? Icons.close : Icons.add)),
    ]);
  }

  Widget _btn(String l, VoidCallback t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: FloatingActionButton.extended(onPressed: t, label: Text(l), heroTag: l));
  void _open(String t, String ti) { setState(() => _isOpen = false); showModalBottomSheet(context: context, isScrollControlled: true, builder: (c) => AddTxSheet(txType: t, title: ti)); }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      SwitchListTile(title: const Text('Lakh Format'), value: p.isLakhEnabled, onChanged: (v) => p.toggleLakh(v)),
      SwitchListTile(title: const Text('Dark Mode'), value: p.isDarkMode, activeColor: Colors.blueAccent, onChanged: (v) => p.toggleTheme()), // Dark Mode Toggle အသစ်
      ListTile(leading: const Icon(Icons.cloud_upload), title: const Text('Backup'), onTap: () => GoogleDriveService().backupDatabase()),
    ]);
  }
}
