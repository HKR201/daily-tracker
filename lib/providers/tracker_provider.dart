import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../database/db_helper.dart';

class TrackerProvider extends ChangeNotifier {
  List<AppWallet> wallets = [];
  List<AppCategory> categories = [];
  List<AppTransaction> transactions = [];

  bool isLoading = true;
  bool isLakhEnabled = true; // Lakh စနစ်ကို ဖွင့်ထားပါတယ်

  TrackerProvider() {
    _init();
  }

  Future<void> _init() async {
    await loadAllData();
    if (wallets.isEmpty) {
      await addWallet(AppWallet(name: 'Main Cash', type: 'Balance', amount: 0.0, lastUpdated: DateTime.now().toIso8601String()));
    }
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

    // မှတ်တမ်း (Transactions) အသစ်ဆုံးကို အပေါ်ဆုံးကပြဖို့ ORDER BY ထည့်ထားပါတယ်
    final txData = await db.query('transactions', orderBy: 'date_timestamp DESC');
    transactions = txData.map((e) => AppTransaction.fromMap(e)).toList();

    isLoading = false;
    notifyListeners();
  }

  Future<void> addWallet(AppWallet wallet) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('wallets', wallet.toMap());
    await loadAllData();
  }

  Future<void> addTransaction({required double amount, required String type, required int categoryId, required String note}) async {
    final db = await DatabaseHelper.instance.database;
    int walletId = wallets.firstWhere((w) => w.type == 'Balance').id ?? 1;

    AppTransaction tx = AppTransaction(
      amount: amount,
      type: type,
      sourceWalletId: walletId,
      categoryId: categoryId,
      note: note,
      dateTimestamp: DateTime.now().toIso8601String(),
    );

    await db.insert('transactions', tx.toMap());

    AppWallet wallet = wallets.firstWhere((w) => w.id == walletId);
    double newAmount = wallet.amount;
    if (type == 'E') newAmount -= amount;
    if (type == 'In') newAmount += amount;

    await db.update('wallets', {'amount': newAmount}, where: 'id = ?', whereArgs: [walletId]);
    await loadAllData();
  }

  // သိန်းဂဏန်းပြောင်းပေးမယ့် Function (Global Utility)
  String formatLakh(double amount) {
    if (isLakhEnabled && amount.abs() >= 100000) {
      double lakh = amount / 100000;
      return "${lakh.toStringAsFixed(1)} Lakh"; 
    }
    return amount.toStringAsFixed(0);
  }

  double get totalBalance {
    return wallets.where((w) => w.type == 'Balance').fold(0.0, (sum, item) => sum + item.amount);
  }
}
