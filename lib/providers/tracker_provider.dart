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
    
    // Wallet အလွတ်ဖြစ်နေရင် Main Cash ကို တည်ဆောက်မယ်
    if (wallets.isEmpty) {
      await addWallet(AppWallet(name: 'Main Cash', type: 'Balance', amount: 0.0, lastUpdated: DateTime.now().toIso8601String()));
    }
    
    // Category အလွတ်ဖြစ်နေရင် အစမ်းသုံးဖို့ ထည့်ပေးမယ်
    if (categories.isEmpty) {
      final db = await DatabaseHelper.instance.database;
      await db.insert('categories', {'name': 'Foods & Drinks', 'icon_data': 0xe25a, 'type': 'Expense'});
      await db.insert('categories', {'name': 'Shopping', 'icon_data': 0xe5fc, 'type': 'Expense'});
      await db.insert('categories', {'name': 'Salary', 'icon_data': 0xe3f8, 'type': 'Income'});
    }
    await loadAllData();
  }

  Future<void> loadAllData() async {
    isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    
    final walletsData = await db.query('wallets');
    wallets = walletsData.map((e) => AppWallet.fromMap(e)).toList();

    final catData = await db.query('categories');
    categories = catData.map((e) => AppCategory.fromMap(e)).toList();

    isLoading = false;
    notifyListeners();
  }

  Future<void> addWallet(AppWallet wallet) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('wallets', wallet.toMap());
    await loadAllData();
  }

  // ငွေစာရင်း အသစ်သွင်းမယ့် Function
  Future<void> addTransaction({required double amount, required String type, required int categoryId, required String note}) async {
    final db = await DatabaseHelper.instance.database;
    
    // လက်ရှိမှာ Main Cash ထဲကပဲ အရင် နှုတ်/ပေါင်း လုပ်ပါမယ်
    int walletId = wallets.firstWhere((w) => w.type == 'Balance').id ?? 1;

    AppTransaction tx = AppTransaction(
      amount: amount,
      type: type,
      sourceWalletId: walletId,
      categoryId: categoryId,
      note: note,
      dateTimestamp: DateTime.now().toIso8601String(),
    );

    // 1. Transaction ကို မှတ်မယ်
    await db.insert('transactions', tx.toMap());

    // 2. Wallet ထဲက ပိုက်ဆံကို အတိုးအလျှော့လုပ်မယ်
    AppWallet wallet = wallets.firstWhere((w) => w.id == walletId);
    double newAmount = wallet.amount;
    if (type == 'E') newAmount -= amount; // Expense ဆိုရင် နှုတ်မယ်
    if (type == 'In') newAmount += amount; // Income ဆိုရင် ပေါင်းမယ်

    await db.update('wallets', {'amount': newAmount}, where: 'id = ?', whereArgs: [walletId]);
    
    await loadAllData();
  }

  double get totalBalance {
    return wallets.where((w) => w.type == 'Balance').fold(0.0, (sum, item) => sum + item.amount);
  }
}
