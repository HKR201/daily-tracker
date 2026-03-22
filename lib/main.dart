import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/tracker_provider.dart';
import 'widgets/add_tx_sheet.dart';
import 'models/app_models.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TrackerProvider()),
      ],
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          background: const Color(0xFFF5F7FA),
        ),
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

  final List<Widget> _screens = [
    const DailyHubScreen(),
    const VaultScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_filled, color: Colors.blueAccent),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree, color: Colors.blueAccent),
            label: 'Vault',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 1: THE DAILY HUB (Main Hub)
// ==========================================
class DailyHubScreen extends StatefulWidget {
  const DailyHubScreen({super.key});

  @override
  State<DailyHubScreen> createState() => _DailyHubScreenState();
}

class _DailyHubScreenState extends State<DailyHubScreen> {
  bool _showFullBalance = false;

  void _toggleBalanceView() {
    setState(() { _showFullBalance = true; });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() { _showFullBalance = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Daily Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: provider.isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text('Total Balance', style: TextStyle(color: Colors.grey, fontSize: 16)),
              GestureDetector(
                onTap: _toggleBalanceView,
                child: Text(
                  _showFullBalance 
                      ? '${provider.totalBalance.toStringAsFixed(0)} Ks' 
                      : '${provider.formatLakh(provider.totalBalance)} Ks',
                  style: TextStyle(
                    fontSize: 40, 
                    fontWeight: FontWeight.bold, 
                    color: provider.totalBalance < 0 ? Colors.redAccent : Colors.blueAccent
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: provider.transactions.isEmpty 
                    ? const Center(child: Text('No Transactions Yet', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: provider.transactions.length,
                        itemBuilder: (context, index) {
                          final tx = provider.transactions[index];
                          final category = provider.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => AppCategory(name: 'Unknown', iconData: 0xe000, type: 'Expense'));
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: tx.type == 'E' ? Colors.red[50] : Colors.green[50],
                              child: Icon(IconData(category.iconData, fontFamily: 'MaterialIcons'), color: tx.type == 'E' ? Colors.redAccent : Colors.green),
                            ),
                            title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(tx.note.isEmpty ? 'No Note' : tx.note),
                            trailing: Text(
                              '${tx.type == 'E' ? '-' : '+'}${tx.amount.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tx.type == 'E' ? Colors.redAccent : Colors.green),
                            ),
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Main Hub ကနေ Expense Form သီးသန့်ပဲ ခေါ်ပါမယ်
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
              child: const AddTxSheet(txType: 'E', title: 'Add Expense (ထွက်ငွေ)'),
            ),
          );
        },
        backgroundColor: Colors.redAccent, // Expense အတွက် အနီရောင် သုံးထားပါတယ်
        elevation: 4,
        child: const Icon(Icons.remove, color: Colors.white, size: 28), // အနှုတ် လက္ခဏာ
      ),
    );
  }
}

// ==========================================
// SCREEN 2: THE VAULT (Accordion & Speed Dial)
// ==========================================
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with SingleTickerProviderStateMixin {
  bool _isDialOpen = false;
  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _expandAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleDial() {
    setState(() {
      _isDialOpen = !_isDialOpen;
      if (_isDialOpen) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  void _openSheet(String type, String title) {
    _toggleDial(); // မီနူးကို အရင်ပိတ်မယ်
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
        child: AddTxSheet(txType: type, title: title),
      ),
    );
  }

  Widget _buildDialButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(width: 15),
          FloatingActionButton(
            heroTag: title, // Hero tag မတူအောင် ခွဲပေးရပါတယ်
            mini: true,
            backgroundColor: color,
            onPressed: onTap,
            child: Icon(icon, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['Monthly', 'Yearly', 'Overview', 'More']
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ))
                .toList(),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Accordion UI List
          ListView(
            padding: const EdgeInsets.all(15),
            children: [
              ExpansionTile(
                title: const Text("Total In (ဝင်ငွေစုစုပေါင်း)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                leading: const Icon(Icons.arrow_downward, color: Colors.green),
                children: [
                  ListTile(title: const Text('Salary'), trailing: const Text('+100,000', style: TextStyle(color: Colors.green))),
                ],
              ),
              ExpansionTile(
                title: const Text("Total Out (ထွက်ငွေစုစုပေါင်း)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                leading: const Icon(Icons.arrow_upward, color: Colors.redAccent),
                children: [
                  ListTile(title: const Text('Foods & Drinks'), trailing: const Text('-15,000', style: TextStyle(color: Colors.redAccent))),
                  ListTile(title: const Text('Shopping'), trailing: const Text('-45,000', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),

          // Speed Dial Background Overlay (မှိန်သွားမယ့် အမည်းရောင်နောက်ခံ)
          if (_isDialOpen)
            GestureDetector(
              onTap: _toggleDial,
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
        ],
      ),
      // Custom Animated Speed Dial ခလုတ်
      floatingActionButton: Column(
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
              turns: _isDialOpen ? 0.125 : 0, // 0.125 ဆိုတာ 45 ဒီဂရီ လှည့်တာပါ (အပေါင်း ကနေ ကြက်ခြေခတ် ဖြစ်သွားမယ်)
              duration: const Duration(milliseconds: 250),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
