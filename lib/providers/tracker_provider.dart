import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../database/db_helper.dart';

class TrackerProvider extends ChangeNotifier {
  List<AppWallet> wallets = [];
  List<AppCategory> categories = [];
  List<AppTransaction> transactions = [];
  bool isLoading = true;
  bool isLakhEnabled = true;
  String lastSyncTime = "Never";

  TrackerProvider() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    isLakhEnabled = prefs.getBool('isLakhEnabled') ?? true;
    lastSyncTime = prefs.getString('lastSyncTime') ?? "Never";

    await loadAllData();
    if (wallets.isEmpty) await addWallet(AppWallet(name: 'Main Cash', type: 'Balance', amount: 0.0, lastUpdated: DateTime.now().toIso8601String()));
    if (categories.isEmpty) {
      final db = await DatabaseHelper.instance.database;
      await db.insert('categories', {'name': 'Foods & Drinks', 'icon_data': 0xe25a, 'type': 'Expense'});
      await db.insert('categories', {'name': 'Shopping', 'icon_data': 0xe5fc, 'type': 'Expense'});
      await db.insert('categories', {'name': 'Salary', 'icon_data': 0xe3f8, 'type': 'Income'});
    }
    await loadAllData();
  }

  void toggleLakh(bool value) async {
    isLakhEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLakhEnabled', value);
    notifyListeners();
  }

  void updateSyncTime() async {
    final now = DateTime.now();
    lastSyncTime = "${now.day}-${now.month}-${now.year} ${now.hour}:${now.minute}";
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSyncTime', lastSyncTime);
    notifyListeners();
  }

  Future<void> loadAllData() async {
    isLoading = true; notifyListeners();
    final db = await DatabaseHelper.instance.database;
    wallets = (await db.query('wallets')).map((e) => AppWallet.fromMap(e)).toList();
    categories = (await db.query('categories')).map((e) => AppCategory.fromMap(e)).toList();
    transactions = (await db.query('transactions', orderBy: 'date_timestamp DESC')).map((e) => AppTransaction.fromMap(e)).toList();
    isLoading = false; notifyListeners();
  }

  Future<void> addWallet(AppWallet wallet) async {
    await (await DatabaseHelper.instance.database).insert('wallets', wallet.toMap());
    await loadAllData();
  }

  Future<int> addTransaction({required double amount, required String type, required int categoryId, required String note}) async {
    final db = await DatabaseHelper.instance.database;
    int walletId = wallets.firstWhere((w) => w.type == 'Balance').id ?? 1;
    int id = await db.insert('transactions', AppTransaction(amount: amount, type: type, sourceWalletId: walletId, categoryId: categoryId, note: note, dateTimestamp: DateTime.now().toIso8601String()).toMap());
    
    double newAmount = wallets.firstWhere((w) => w.id == walletId).amount + (type == 'In' ? amount : -amount);
    await db.update('wallets', {'amount': newAmount}, where: 'id = ?', whereArgs: [walletId]);
    await loadAllData();
    return id;
  }

  Future<void> deleteTransaction(int txId) async {
    final db = await DatabaseHelper.instance.database;
    final txMap = await db.query('transactions', where: 'id = ?', whereArgs: [txId]);
    if (txMap.isEmpty) return;
    AppTransaction tx = AppTransaction.fromMap(txMap.first);
    double newAmount = wallets.firstWhere((w) => w.id == tx.sourceWalletId).amount + (tx.type == 'E' ? tx.amount : -tx.amount);
    await db.update('wallets', {'amount': newAmount}, where: 'id = ?', whereArgs: [tx.sourceWalletId]);
    await db.delete('transactions', where: 'id = ?', whereArgs: [txId]);
    await loadAllData();
  }

  String formatLakh(double amount) {
    if (isLakhEnabled && amount.abs() >= 100000) return "${(amount / 100000).toStringAsFixed(1)} Lakh"; 
    return amount.toStringAsFixed(0);
  }

  double get totalBalance => wallets.where((w) => w.type == 'Balance').fold(0.0, (sum, item) => sum + item.amount);
}
