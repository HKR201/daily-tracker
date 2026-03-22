import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/tracker_provider.dart';
import 'widgets/add_tx_sheet.dart';
import 'models/app_models.dart'; // Category နာမည်တွေ ပြန်ရှာဖို့ ထည့်ထားပါတယ်

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

class DailyHubScreen extends StatefulWidget {
  const DailyHubScreen({super.key});

  @override
  State<DailyHubScreen> createState() => _DailyHubScreenState();
}

class _DailyHubScreenState extends State<DailyHubScreen> {
  // သိန်းဂဏန်း (Lakh) အပြည့်ပြမလား၊ အတိုပြမလား မှတ်မယ့်နေရာ
  bool _showFullBalance = false;

  void _toggleBalanceView() {
    setState(() {
      _showFullBalance = true;
    });
    // ၃ စက္ကန့်နေရင် ပြန်ပြောင်းပေးမယ်
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showFullBalance = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Daily Hub', style: TextStyle(fontWeight: FontWeight.bold)),
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
              
              // Balance ကို သိန်းဂဏန်းနဲ့ ပြမယ့် နေရာ (နှိပ်လို့ရပါတယ်)
              GestureDetector(
                onTap: _toggleBalanceView,
                child: Text(
                  _showFullBalance 
                      ? '${provider.totalBalance.toStringAsFixed(0)} Ks' // ဂဏန်းအပြည့်ပြမယ်
                      : '${provider.formatLakh(provider.totalBalance)} Ks', // Lakh နဲ့ပြမယ်
                  style: TextStyle(
                    fontSize: 40, 
                    fontWeight: FontWeight.bold, 
                    color: provider.totalBalance < 0 ? Colors.redAccent : Colors.blueAccent // အနှုတ်ဆို အနီရောင်ပြမယ်
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
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: provider.transactions.isEmpty 
                    ? const Center(child: Text('No Transactions Yet', style: TextStyle(color: Colors.grey)))
                    // မှတ်တမ်းတွေ ရှိလာရင် List လေးနဲ့ ကတ်ပြားလေးတွေ ပြမယ်
                    : ListView.builder(
                        itemCount: provider.transactions.length,
                        itemBuilder: (context, index) {
                          final tx = provider.transactions[index];
                          // Category နာမည်ကို ID ကနေ လှမ်းရှာမယ်
                          final category = provider.categories.firstWhere(
                            (c) => c.id == tx.categoryId, 
                            orElse: () => AppCategory(name: 'Unknown', iconData: 0xe000, type: 'Expense')
                          );
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: tx.type == 'E' ? Colors.red[100] : Colors.green[100],
                              child: Icon(IconData(category.iconData, fontFamily: 'MaterialIcons'), 
                                          color: tx.type == 'E' ? Colors.redAccent : Colors.green),
                            ),
                            title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(tx.note.isEmpty ? 'No Note' : tx.note),
                            trailing: Text(
                              '${tx.type == 'E' ? '-' : '+'}${tx.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16,
                                color: tx.type == 'E' ? Colors.redAccent : Colors.green,
                              ),
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
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
              ),
              child: const AddTxSheet(),
            ),
          );
        },
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Vault Data Here'),
      ),
    );
  }
}
