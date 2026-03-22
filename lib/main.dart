import 'package:flutter/material.dart';

void main() {
  runApp(const DailyTrackerApp());
}

class DailyTrackerApp extends StatelessWidget {
  const DailyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.lightBlue,
            brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.black54,
        backgroundColor: Colors.lightBlue,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled, size: 30),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_tree, size: 30),
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
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      appBar: AppBar(
        title: const Text('The Daily Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
        backgroundColor: Colors.lightBlue,
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('1,200,000', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
            const Text('600,000', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.lightBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: Text('Insights / Ledger Cards Here', style: TextStyle(color: Colors.white))),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open Expense Form
        },
        backgroundColor: Colors.lightBlue,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      appBar: AppBar(
        title: const Text('The Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
        backgroundColor: Colors.lightBlue,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTabBtn('Monthly'),
              _buildTabBtn('Yearly'),
              _buildTabBtn('Overview'),
              _buildTabBtn('More'),
            ],
          ),
        ),
      ),
      body: const Center(
        child: Text('Vault Categories Accordion UI Here'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open Speed Dial Menu
        },
        backgroundColor: Colors.lightBlue,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildTabBtn(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.lightBlue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
