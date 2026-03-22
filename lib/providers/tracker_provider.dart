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
    
    if (wallets.isEmpty) {
      await addWallet(AppWallet(name: 'Balance', type: 'Balance', amount: 0.0, lastUpdated: DateTime.now().toIso8601String()));
      await addWallet(AppWallet(name: 'ဘဏ်စာရင်း', type: 'Bank', amount: 0.0, lastUpdated: DateTime.now().toIso8601String()));
      await addWallet(AppWallet(name: 'ယောကျ်ားစာရင်း', type: 'Person', amount: 0.0, lastUpdated: DateTime.now().toIso8601String()));
    }
    
    if (categories.isEmpty) {
      final db = await DatabaseHelper.instance.database;
      await db.insert('categories', {'name': 'Foods & Drinks', 'icon_data': 0xe25a, 'type': 'Expense'});
      await db.insert('categories', {'name': 'Shopping', 'icon_data': 0xe5fc, 'type': 'Expense'});
      await db.insert('categories', {'name': 'Salary', 'icon_data': 0xe3f8, 'type': 'Income'});
      await db.insert('categories', {'name': 'KPay', 'icon_data': 0xe040, 'type': 'BankDeposit'});
      await db.insert('categories', {'name': 'AYA', 'icon_data': 0xe040, 'type': 'BankDeposit'});
      await db.insert('categories', {'name': 'ကိုကြီး', 'icon_data': 0xe314, 'type': 'HomeTransfer'});
      await db.insert('categories', {'name': 'အိမ်', 'icon_data': 0xe314, 'type': 'HomeTransfer'});
      await db.insert('categories', {'name': 'လွှဲငွေ', 'icon_data': 0xe491, 'type': 'HusbandDeposit'});
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

  Future<void> addNewCategory(String name, String type) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('categories', {'name': name, 'icon_data': 0xe163, 'type': type});
    await loadAllData();
  }

  Future<int> addTransaction({
    required double amount, 
    required String type, 
    required int sourceWalletId, 
    required int categoryId, 
    required String note,
    required String dateString,
  }) async {
    final db = await DatabaseHelper.instance.database;
    AppWallet srcWallet = wallets.firstWhere((w) => w.id == sourceWalletId);
    int? destWalletId;

    if (type == 'IncomeFromBank' || type == 'IncomeFromHusband') {
      // ဘဏ် (သို့) ယောကျ်ား ကနေ ဝင်ငွေ (Balance ထဲ ပေါင်းမယ်)
      destWalletId = wallets.firstWhere((w) => w.type == 'Balance').id;
      await db.update('wallets', {'amount': srcWallet.amount - amount}, where: 'id = ?', whereArgs: [sourceWalletId]);
      AppWallet dest = wallets.firstWhere((w) => w.id == destWalletId);
      await db.update('wallets', {'amount': dest.amount + amount}, where: 'id = ?', whereArgs: [destWalletId]);
    } 
    else if (type == 'BankDeposit' || type == 'HusbandDeposit') {
      // Balance ကနေ ဘဏ် (သို့) ယောကျ်ား ထဲ အပ်ငွေ
      destWalletId = type == 'BankDeposit' ? wallets.firstWhere((w) => w.type == 'Bank').id : wallets.firstWhere((w) => w.type == 'Person').id;
      await db.update('wallets', {'amount': srcWallet.amount - amount}, where: 'id = ?', whereArgs: [sourceWalletId]);
      AppWallet dest = wallets.firstWhere((w) => w.id == destWalletId);
      await db.update('wallets', {'amount': dest.amount + amount}, where: 'id = ?', whereArgs: [destWalletId]);
    } 
    else if (type == 'Income') {
      // ပြင်ပ ဝင်ငွေ (Balance ထဲပဲ ပေါင်းမယ်)
      await db.update('wallets', {'amount': srcWallet.amount + amount}, where: 'id = ?', whereArgs: [sourceWalletId]);
    } 
    else if (type == 'Expense' || type == 'HomeTransfer') {
      // ထွက်ငွေ
      await db.update('wallets', {'amount': srcWallet.amount - amount}, where: 'id = ?', whereArgs: [sourceWalletId]);
    }

    int id = await db.insert('transactions', AppTransaction(
      amount: amount, type: type, sourceWalletId: sourceWalletId, destinationWalletId: destWalletId, categoryId: categoryId, note: note, dateTimestamp: dateString
    ).toMap());
    
    await loadAllData();
    return id;
  }

  Future<void> deleteTransaction(int txId) async {
    final db = await DatabaseHelper.instance.database;
    final txMap = await db.query('transactions', where: 'id = ?', whereArgs: [txId]);
    if (txMap.isEmpty) return;
    
    AppTransaction tx = AppTransaction.fromMap(txMap.first);
    AppWallet srcWallet = wallets.firstWhere((w) => w.id == tx.sourceWalletId);
    
    if (tx.type == 'BankDeposit' || tx.type == 'HusbandDeposit' || tx.type == 'IncomeFromBank' || tx.type == 'IncomeFromHusband') {
      AppWallet dest = wallets.firstWhere((w) => w.id == tx.destinationWalletId);
      await db.update('wallets', {'amount': srcWallet.amount + tx.amount}, where: 'id = ?', whereArgs: [tx.sourceWalletId]);
      await db.update('wallets', {'amount': dest.amount - tx.amount}, where: 'id = ?', whereArgs: [tx.destinationWalletId]);
    } 
    else if (tx.type == 'Income') {
      await db.update('wallets', {'amount': srcWallet.amount - tx.amount}, where: 'id = ?', whereArgs: [tx.sourceWalletId]);
    } 
    else if (tx.type == 'Expense' || tx.type == 'HomeTransfer') {
      await db.update('wallets', {'amount': srcWallet.amount + tx.amount}, where: 'id = ?', whereArgs: [tx.sourceWalletId]);
    }

    await db.delete('transactions', where: 'id = ?', whereArgs: [txId]);
    await loadAllData();
  }

  String formatLakh(double amount) {
    if (isLakhEnabled && amount.abs() >= 100000) return "${(amount / 100000).toStringAsFixed(1)} Lakh"; 
    return amount.toStringAsFixed(0);
  }

  double get totalAssets => wallets.fold(0.0, (sum, item) => sum + item.amount);
  double get totalBalance => wallets.where((w) => w.type == 'Balance').fold(0.0, (sum, item) => sum + item.amount);
}
