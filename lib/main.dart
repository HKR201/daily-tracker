import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/tracker_provider.dart';

void main() {
  runApp(
    // App တစ်ခုလုံးကို Provider နဲ့ ပတ်ပေးလိုက်ပါပြီ
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
        // Minimalist ဖြစ်အောင် အရောင်ကို ရှင်းရှင်းလင်းလင်း ပြင်ထားပါတယ်
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          background: const Color(0xFFF5F7FA), // ခဲပြာရောင်ဖျော့ဖျော့ နောက်ခံ
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
        // Modern Look ဖြစ်တဲ့ NavigationBar ကို သုံးထားပါတယ်
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

class DailyHubScreen extends StatelessWidget {
  const DailyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider ထဲက Data တွေကို လှမ်းယူပါပြီ
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
              // Database ကလာတဲ့ အစစ်အမှန် Balance ကို ပြပါမယ်
              Text(
                '${provider.totalBalance.toStringAsFixed(0)} Ks', 
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blueAccent)
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
                  child: const Center(
                    child: Text('Transactions will appear here', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // နောက်အပိုင်းမှာ ဒီနေရာကနေ Transaction Form ခေါ်ပါမယ်
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
