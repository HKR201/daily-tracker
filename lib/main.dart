import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, background: const Color(0xFFF5F7FA)), useMaterial3: true),
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
      // အောက်ခြေမှာ Home နဲ့ Vault ၂ ခုပဲ ရှိပါမယ်
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
// DAILY HUB SCREEN (အရင်အတိုင်းပါ)
// ==========================================
class DailyHubScreen extends StatefulWidget {
  const DailyHubScreen({super.key});
  @override
  State<DailyHubScreen> createState() => _DailyHubScreenState();
}

class _DailyHubScreenState extends State<DailyHubScreen> {
  bool _showFullBalance = false;
  void _toggleBalanceView() {
    setState(() => _showFullBalance = true);
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _showFullBalance = false); });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('The Daily Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)), backgroundColor: Colors.transparent, elevation: 0),
      body: provider.isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          const SizedBox(height: 20),
          const Text('Total Balance', style: TextStyle(color: Colors.grey, fontSize: 16)),
          GestureDetector(
            onTap: _toggleBalanceView,
            child: Text(_showFullBalance ? '${provider.totalBalance.toStringAsFixed(0)} Ks' : '${provider.formatLakh(provider.totalBalance)} Ks',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: provider.totalBalance < 0 ? Colors.redAccent : Colors.blueAccent)),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
              child: provider.transactions.isEmpty ? const Center(child: Text('No Transactions Yet', style: TextStyle(color: Colors.grey))) : ListView.builder(
                itemCount: provider.transactions.length,
                itemBuilder: (context, index) {
                  final tx = provider.transactions[index];
                  final cat = provider.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => AppCategory(name: 'Unknown', iconData: 0xe000, type: 'Expense'));
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: tx.type == 'E' ? Colors.red[50] : Colors.green[50], child: Icon(IconData(cat.iconData, fontFamily: 'MaterialIcons'), color: tx.type == 'E' ? Colors.redAccent : Colors.green)),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(tx.note.isEmpty ? 'No Note' : tx.note),
                    trailing: Text('${tx.type == 'E' ? '-' : '+'}${tx.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tx.type == 'E' ? Colors.redAccent : Colors.green)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))), child: const AddTxSheet(txType: 'E', title: 'Add Expense (ထွက်ငွေ)'))),
        backgroundColor: Colors.redAccent, elevation: 4, child: const Icon(Icons.remove, color: Colors.white, size: 28),
      ),
    );
  }
}

// ==========================================
// VAULT SCREEN (Tab များနှင့် Settings ပါဝင်သည်)
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
    // Tab ၄ ခုအတွက် Controller
    _tabController = TabController(length: 4, vsync: this);
    // Tab ပြောင်းရင် ခလုတ်ဖျောက်ဖို့ သိအောင်
    _tabController.addListener(() { setState(() {}); }); 

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
    setState(() {
      _isDialOpen = !_isDialOpen;
      _isDialOpen ? _animController.forward() : _animController.reverse();
    });
  }

  void _openSheet(String type, String title) {
    _toggleDial();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))), child: AddTxSheet(txType: type, title: title)));
  }

  Widget _buildDialButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
          const SizedBox(width: 15),
          FloatingActionButton(heroTag: title, mini: true, backgroundColor: color, onPressed: onTap, child: Icon(icon, color: Colors.white)),
        ],
      ),
    );
  }

  // Accordion စာရင်းပြမည့်နေရာ
  Widget _buildAccordionView() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        ExpansionTile(
          title: const Text("Total In (ဝင်ငွေစုစုပေါင်း)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          leading: const Icon(Icons.arrow_downward, color: Colors.green),
          children: const [ListTile(title: Text('Salary'), trailing: Text('+100,000', style: TextStyle(color: Colors.green)))],
        ),
        ExpansionTile(
          title: const Text("Total Out (ထွက်ငွေစုစုပေါင်း)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          leading: const Icon(Icons.arrow_upward, color: Colors.redAccent),
          children: const [
            ListTile(title: Text('Foods & Drinks'), trailing: Text('-15,000', style: TextStyle(color: Colors.redAccent))),
            ListTile(title: Text('Shopping'), trailing: Text('-45,000', style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // အစ်ကို ဝိုင်းပြထားတဲ့ နေရာလေးပါ
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: 'Monthly'),
            Tab(text: 'Yearly'),
            Tab(text: 'Overview'),
            Tab(text: 'More'), // ဤနေရာတွင် Settings ပေါ်လာပါမည်
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildAccordionView(), // Monthly အပိုင်း
              _buildAccordionView(), // Yearly အပိုင်း
              _buildAccordionView(), // Overview အပိုင်း
              const SettingsView(),  // More (Settings) အပိုင်း
            ],
          ),
          if (_isDialOpen) GestureDetector(onTap: _toggleDial, child: Container(color: Colors.black.withOpacity(0.3))),
        ],
      ),
      // "More" Tab (Index 3) သို့ ရောက်နေလျှင် အပေါင်းခလုတ်ကို ဖျောက်ထားပါမည်
      floatingActionButton: _tabController.index == 3 ? null : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildDialButton('ယောက်ျားအပ်ငွေ', Icons.person, Colors.purple, () => _openSheet('In', 'ယောက်ျားအပ်ငွေ')),
                _buildDialButton('ဘဏ်အပ်ငွေ', Icons.account_balance, Colors.orange, () => _openSheet('In', 'ဘဏ်အပ်ငွေ')),
                _buildDialButton('အိမ်လွှဲငွေ', Icons.home, Colors.teal, () => _openSheet('In', 'အိမ်လွှဲငွေ')),
                _buildDialButton('ဝင်ငွေ', Icons.attach_money, Colors.green, () => _openSheet('In', 'Income (ဝင်ငွေ)')),
              ],
            ),
          ),
          FloatingActionButton(
            heroTag: 'MainVaultFab',
            onPressed: _toggleDial,
            backgroundColor: _isDialOpen ? Colors.grey : Colors.blueAccent,
            child: AnimatedRotation(
              turns: _isDialOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 250),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SETTINGS VIEW (More Tab အောက်တွင် ပေါ်မည့်နေရာ)
// ==========================================
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final GoogleDriveService _driveService = GoogleDriveService();
  bool _isSyncing = false;

  void _backupData(TrackerProvider provider) async {
    setState(() => _isSyncing = true);
    bool success = await _driveService.backupDatabase();
    setState(() => _isSyncing = false);
    if (success) {
      provider.updateSyncTime();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup Successful! 🎉', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup Failed. Please try again.'), backgroundColor: Colors.redAccent));
    }
  }

  void _restoreData(TrackerProvider provider) async {
    setState(() => _isSyncing = true);
    bool success = await _driveService.restoreDatabase();
    setState(() => _isSyncing = false);
    if (success) {
      provider.loadAllData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore Successful! 🎉', style: TextStyle(color: Colors.white)), backgroundColor: Colors.blueAccent));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No backup found or Restore Failed.'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          child: SwitchListTile(
            title: const Text('Lakh Format (သိန်းဂဏန်းဖြင့်ပြရန်)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('1,000,000 Ks ကို 10.0 Lakh ဟု ပြပါမည်'),
            value: provider.isLakhEnabled,
            activeColor: Colors.blueAccent,
            onChanged: (val) => provider.toggleLakh(val),
          ),
        ),
        const SizedBox(height: 30),
        const Text('Cloud Backup', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload, color: Colors.blueAccent, size: 30),
                title: const Text('Backup to Google Drive', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Last synced: ${provider.lastSyncTime}'),
                trailing: _isSyncing ? const CircularProgressIndicator() : const Icon(Icons.chevron_right),
                onTap: _isSyncing ? null : () => _backupData(provider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_download, color: Colors.green, size: 30),
                title: const Text('Restore from Google Drive', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('ဖုန်းအသစ်ပြောင်းလျှင် Data ပြန်ယူရန်'),
                trailing: _isSyncing ? const CircularProgressIndicator() : const Icon(Icons.chevron_right),
                onTap: _isSyncing ? null : () => _restoreData(provider),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
