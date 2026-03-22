import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../database/db_helper.dart';

class TrackerProvider extends ChangeNotifier {
  List<AppWallet> wallets = [];
  List<AppCategory> categories = [];
  List<AppTransaction> transactions = [];

  bool isLoading = true;

  TrackerProvider() {
    _init();
  }

  Future<void> _init() async {
    await loadAllData();
    // Database အလွတ်ဖြစ်နေရင် အစမ်းသုံးဖို့ "Main Cash" အိတ်လေး တစ်ခု အလိုလို ဆောက်ပေးပါမယ်
    if (wallets.isEmpty) {
      await addWallet(AppWallet(name: 'Main Cash', type: 'Balance', amount: 0.0, lastUpdated: DateTime.now().toIso8601String()));
      await loadAllData();
    }
  }

  Future<void> loadAllData() async {
    isLoading = true;
    notifyListeners(); // UI ကို Data ယူနေကြောင်း အသိပေးသည်

    final db = await DatabaseHelper.instance.database;
    
    final walletsData = await db.query('wallets');
    wallets = walletsData.map((e) => AppWallet.fromMap(e)).toList();

    isLoading = false;
    notifyListeners(); // UI ကို Data ရပြီဖြစ်ကြောင်း အသိပေးသည်
  }

  Future<void> addWallet(AppWallet wallet) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('wallets', wallet.toMap());
    await loadAllData();
  }

  // Balance Type ဖြစ်တဲ့ ငွေအိတ်တွေ အကုန်ပေါင်းပြီး လက်ကျန်ငွေ တွက်ပေးမယ့် Function
  double get totalBalance {
    return wallets.where((w) => w.type == 'Balance').fold(0.0, (sum, item) => sum + item.amount);
  }
}
