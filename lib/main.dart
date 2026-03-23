import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/tracker_provider.dart';
import 'widgets/add_tx_sheet.dart';
import 'ledger_page.dart';
import 'services/drive_service.dart';
import 'models/app_models.dart'; 

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
      themeMode: p.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
        setState(() => _dragExtent = (_dragExtent > _maxDrag / 2) ? _maxDrag : 0);
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
                  widget.onDelete(); 
                },
                child: Container(width: _maxDrag, alignment: Alignment.center, child: const Icon(Icons.delete, color: Colors.white)),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(-_dragExtent, 0),
            child: Container(color: Theme.of(context).scaffoldBackgroundColor, child: widget.child),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// DAILY HUB SCREEN
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
    final p = Provider.of<TrackerProvider>(context);
    final currencyFormat = NumberFormat('#,###');

    return Scaffold(
      // ခေါင်းစဉ်ကို Provider မှ ခေါ်ယူပြသခြင်း
      appBar: AppBar(title: Text(p.hubTitle, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: p.isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          const SizedBox(height: 20),
          const Text('Current Balance (လက်ကျန်ငွေ)', style: TextStyle(color: Colors.grey, fontSize: 16)),
          GestureDetector(
            onTap: () {
              setState(() => _showFullBalance = true);
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) setState(() => _showFullBalance = false);
              });
            },
            child: Text(
              _showFullBalance ? '${currencyFormat.format(p.totalBalance)} Ks' : '${p.formatLakh(p.totalBalance)} Ks',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: p.totalBalance < 0 ? Colors.redAccent : Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 5),
          Text('Monthly Expenses: -${currencyFormat.format(p.currentMonthExpense)} Ks', style: const TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.blueGrey.withOpacity(0.1) : Colors.white, borderRadius: BorderRadius.circular(24)),
              child: p.transactions.isEmpty ? const Center(child: Text('No Transactions Yet')) : ListView.builder(
                itemCount: p.transactions.length,
                itemBuilder: (ctx, i) {
                  final tx = p.transactions[i];
                  bool isExp = ['Expense', 'HomeTransfer', 'BankDeposit', 'HusbandDeposit'].contains(tx.type);
                  final cat = p.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => AppCategory(name: 'Unknown', iconData: 0xe000, type: 'Expense'));
                  
                  return SwipeToDeleteItem(
                    onDelete: () {
                      p.deleteTransaction(tx.id!);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Record deleted'),
                          duration: const Duration(seconds: 2), 
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(label: 'UNDO', textColor: Colors.blueAccent, onPressed: () => p.undoDelete(tx)),
                        )
                      );
                    },
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: isExp ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), child: Icon(IconData(cat.iconData, fontFamily: 'MaterialIcons'), color: isExp ? Colors.redAccent : Colors.green)),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(tx.note.isEmpty ? 'No Note' : tx.note),
                      trailing: Text('${isExp ? '-' : '+'}${currencyFormat.format(tx.amount)}', style: TextStyle(color: isExp ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold, fontSize: 16))
                    ),
                  );
                }
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => Container(decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))), child: const AddTxSheet(txType: 'Expense', title: 'Add Expense'))), backgroundColor: Colors.redAccent, child: const Icon(Icons.remove, color: Colors.white)),
    );
  }
}

// ==========================================
// THE VAULT & SETTINGS SCREEN
// ==========================================
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with TickerProviderStateMixin {
  late TabController _tab;
  bool _isOpen = false;
  bool _isAssetsHidden = true; 

  @override
  void initState() { 
    super.initState(); 
    _tab = TabController(length: 3, vsync: this); 
    _tab.addListener(() => setState(() {})); 
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    return Scaffold(
      // ခေါင်းစဉ်ကို Provider မှ ခေါ်ယူပြသခြင်း
      appBar: AppBar(
        title: Text(p.vaultTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26)), 
        backgroundColor: Colors.transparent, 
        elevation: 0,
        bottom: TabBar(
          controller: _tab, 
          isScrollable: false, 
          labelColor: Colors.blueAccent, 
          unselectedLabelColor: Colors.grey, 
          indicatorColor: Colors.blueAccent,
          tabs: const [Tab(text: 'Monthly'), Tab(text: 'Yearly'), Tab(text: 'More')]
        )
      ),
      body: Stack(children: [
        TabBarView(
          controller: _tab, 
          children: [_buildAccordion(p, 'Monthly'), _buildAccordion(p, 'Yearly'), const SettingsView()]
        ),
        if (_isOpen) GestureDetector(onTap: () => setState(() => _isOpen = false), child: Container(color: Colors.black26)),
      ]),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: _tab.index == 2 ? null : _buildFab(p),
    );
  }

  Widget _buildAccordion(TrackerProvider p, String period) {
    final inSum = p.getSummaryByTypeAndCategory(period, 'In');
    final outSum = p.getSummaryByTypeAndCategory(period, 'Out');
    return ListView(padding: const EdgeInsets.all(15), children: [
      _buildAssetBox(p),
      ExpansionTile(
        title: Text('Total In (${p.formatLakh(p.getPeriodTotal(period, 'In'))})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), 
        leading: const Icon(Icons.arrow_downward, color: Colors.green),
        children: inSum.entries.map((e) => ListTile(
          title: Text(e.key), 
          trailing: Text('+${p.formatLakh(e.value)}', style: const TextStyle(color: Colors.green)), 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LedgerPage(initialLabel: e.key)))
        )).toList()
      ),
      ExpansionTile(
        title: Text('Total Out (${p.formatLakh(p.getPeriodTotal(period, 'Out'))})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)), 
        leading: const Icon(Icons.arrow_upward, color: Colors.redAccent),
        children: outSum.entries.map((e) => ListTile(
          title: Text(e.key), 
          trailing: Text('-${p.formatLakh(e.value)}', style: const TextStyle(color: Colors.redAccent)), 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LedgerPage(initialLabel: e.key)))
        )).toList()
      ),
    ]);
  }

  // သပ်သပ်ရပ်ရပ် ပြင်ဆင်ထားသော Asset Box
  Widget _buildAssetBox(TrackerProvider p) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _isAssetsHidden = !_isAssetsHidden),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        margin: const EdgeInsets.only(bottom: 15), 
        decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), 
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const Text('စုစုပေါင်း ပိုင်ဆိုင်မှု', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(_isAssetsHidden ? Icons.visibility_off : Icons.visibility, color: Colors.blueAccent, size: 22),
                ),
              ],
            ),
            if (!_isAssetsHidden) ...[
              const SizedBox(height: 15),
              Text('${p.formatLakh(p.totalAssets)} Ks', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround, 
                children: p.wallets.map((w) => Column(children: [
                  Text(w.name, style: const TextStyle(fontSize: 13, color: Colors.grey)), 
                  const SizedBox(height: 5),
                  Text(p.formatLakh(w.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
                ])).toList()
              ),
            ]
          ]
        )
      ),
    );
  }

  // FAB တွင် Pocket အမည်များကို အမှန်ပေါ်စေရန် ပြင်ဆင်ခြင်း
  Widget _buildFab(TrackerProvider p) {
    // Dynamic အိတ်ကပ်နာမည်များကို ယူခြင်း
    String bankName = p.wallets.length > 1 ? p.wallets[1].name : 'ဘဏ်စာရင်း';
    String personName = p.wallets.length > 2 ? p.wallets[2].name : 'ယောကျ်ားစာရင်း';

    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (_isOpen) ...[
        _btn(personName, () => _open('HusbandDeposit', personName)),
        _btn(bankName, () => _open('BankDeposit', bankName)),
        _btn('အိမ်လွှဲငွေ', () => _open('HomeTransfer', 'အိမ်လွှဲငွေ')),
        _btn('ဝင်ငွေ', () => _open('Income', 'Income (ဝင်ငွေ)')),
      ],
      FloatingActionButton(onPressed: () => setState(() => _isOpen = !_isOpen), child: Icon(_isOpen ? Icons.close : Icons.add)),
    ]);
  }

  Widget _btn(String l, VoidCallback t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: FloatingActionButton.extended(onPressed: t, label: Text(l), heroTag: l));
  
  void _open(String t, String ti) { 
    setState(() => _isOpen = false); 
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (c) => Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))), 
        child: AddTxSheet(txType: t, title: ti)
      )
    ); 
  }
}

// ==========================================
// ADVANCED SETTINGS VIEW
// ==========================================
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final GoogleDriveService _driveService = GoogleDriveService();
  bool _isSyncing = false;
  bool _isResetting = false;

  void _showRenameDialog(String title, String initialValue, Function(String) onSave) {
    String newVal = initialValue;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          autofocus: true,
          controller: TextEditingController(text: initialValue),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (val) => newVal = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (newVal.trim().isNotEmpty) {
                onSave(newVal.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ၁။ Display Settings
        const Text('Display & Format', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.white, borderRadius: BorderRadius.circular(15)), 
          child: Column(
            children: [
              SwitchListTile(title: const Text('Lakh Format', style: TextStyle(fontWeight: FontWeight.bold)), value: provider.isLakhEnabled, activeColor: Colors.blueAccent, onChanged: (val) => provider.toggleLakh(val)),
              const Divider(height: 1),
              SwitchListTile(title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)), value: provider.isDarkMode, activeColor: Colors.blueAccent, onChanged: (val) => provider.toggleTheme()),
            ],
          )
        ),
        const SizedBox(height: 30),

        // ၂။ Personalization (နာမည်များ ပြင်ရန်)
        const Text('Personalization (နာမည်များ ပြင်ဆင်ရန်)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.white, borderRadius: BorderRadius.circular(15)), 
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.title, color: Colors.blueAccent), title: const Text('Rename Daily Hub', style: TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.edit, size: 18), onTap: () => _showRenameDialog('Rename Daily Hub', provider.hubTitle, (v) => provider.updateHubTitle(v))),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.title, color: Colors.blueAccent), title: const Text('Rename Vault', style: TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.edit, size: 18), onTap: () => _showRenameDialog('Rename Vault', provider.vaultTitle, (v) => provider.updateVaultTitle(v))),
              const Divider(height: 1),
              ExpansionTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
                title: const Text('Rename Pockets (အိတ်ကပ်များ)', style: TextStyle(fontWeight: FontWeight.bold)),
                children: provider.wallets.map((w) => ListTile(
                  title: Text(w.name),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _showRenameDialog('Rename Pocket', w.name, (v) => provider.renameWallet(w.id!, v))
                )).toList(),
              ),
            ],
          )
        ),
        const SizedBox(height: 30),

        // ၃။ Cloud Backup & Reset
        const Text('Cloud Backup & Security', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.white, borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.cloud_upload, color: Colors.blueAccent), title: const Text('Backup to Google Drive', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Last synced: ${provider.lastSyncTime}'), trailing: _isSyncing ? const CircularProgressIndicator() : const Icon(Icons.chevron_right), onTap: () async { setState(() => _isSyncing = true); await _driveService.backupDatabase(); provider.updateSyncTime(); setState(() => _isSyncing = false); }),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.cloud_download, color: Colors.green), title: const Text('Restore from Google Drive', style: TextStyle(fontWeight: FontWeight.bold)), trailing: _isSyncing ? const CircularProgressIndicator() : const Icon(Icons.chevron_right), onTap: () async { setState(() => _isSyncing = true); await _driveService.restoreDatabase(); provider.loadAllData(); setState(() => _isSyncing = false); }),
              const Divider(height: 1),
              // Reset ခလုတ်
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent), 
                title: const Text('Reset Cloud Backup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)), 
                trailing: _isResetting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)) : const Icon(Icons.chevron_right, color: Colors.redAccent), 
                onTap: () async {
                  bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
                    title: const Text('Are you sure?', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('This will permanently delete your cloud backup.\n\nYou will need to choose your Google account again to verify.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.white))),
                    ],
                  ));
                  
                  if (confirm == true) {
                    setState(() => _isResetting = true);
                    bool success = await _driveService.resetCloudBackup();
                    if (success) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('lastSyncTime', 'Never');
                      provider.lastSyncTime = 'Never';
                      provider.loadAllData();
                    }
                    setState(() => _isResetting = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Cloud Backup has been reset.' : 'Failed to reset backup.')));
                    }
                  }
                }
              ),
            ],
          ),
        ),
      ],
    );
  }
}
