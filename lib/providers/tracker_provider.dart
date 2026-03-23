import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
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
  }

  Future<void> loadAllData() async {
    isLoading = true; notifyListeners();
    final db = await DatabaseHelper.instance.database;
    wallets = (await db.query('wallets')).map((e) => AppWallet.fromMap(e)).toList();
    if (wallets.isEmpty) {
      await addWallet(AppWallet(name: 'Balance', type: 'Balance', amount: 0.0, lastUpdated: ''));
      await addWallet(AppWallet(name: 'ဘဏ်စာရင်း', type: 'Bank', amount: 0.0, lastUpdated: ''));
      await addWallet(AppWallet(name: 'ယောကျ်ားစာရင်း', type: 'Person', amount: 0.0, lastUpdated: ''));
    }
    categories = (await db.query('categories')).map((e) => AppCategory.fromMap(e)).toList();
    transactions = (await db.query('transactions', orderBy: 'date_timestamp DESC')).map((e) => AppTransaction.fromMap(e)).toList();
    isLoading = false; notifyListeners();
  }

  Future<void> addNewCategory(String name, String type) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('categories', {'name': name, 'icon_data': 0xe163, 'type': type});
    await loadAllData();
  }

  Future<int> addTransaction({required double amount, required String type, required int sourceWalletId, required int categoryId, required String note, required String dateString}) async {
    final db = await DatabaseHelper.instance.database;
    int? destId;
    if (type == 'IncomeFromBank' || type == 'IncomeFromHusband') {
      destId = wallets.firstWhere((w) => w.type == 'Balance').id;
      _adjustWallet(sourceWalletId, -amount); _adjustWallet(destId!, amount);
    } else if (type == 'BankDeposit' || type == 'HusbandDeposit') {
      destId = type == 'BankDeposit' ? wallets.firstWhere((w) => w.type == 'Bank').id : wallets.firstWhere((w) => w.type == 'Person').id;
      _adjustWallet(sourceWalletId, -amount); _adjustWallet(destId!, amount);
    } else if (type == 'Income') {
      int balId = wallets.firstWhere((w) => w.type == 'Balance').id!;
      _adjustWallet(balId, amount);
    } else { _adjustWallet(sourceWalletId, -amount); }

    int id = await db.insert('transactions', AppTransaction(amount: amount, type: type, sourceWalletId: sourceWalletId, destinationWalletId: destId, categoryId: categoryId, note: note, dateTimestamp: dateString).toMap());
    await loadAllData(); return id;
  }

  Future<void> deleteTransaction(int txId) async {
    final tx = transactions.firstWhere((t) => t.id == txId);
    if (tx.type == 'BankDeposit' || tx.type == 'HusbandDeposit' || tx.type == 'IncomeFromBank' || tx.type == 'IncomeFromHusband') {
      _adjustWallet(tx.sourceWalletId, tx.amount); _adjustWallet(tx.destinationWalletId!, -tx.amount);
    } else if (tx.type == 'Income') {
      int balId = wallets.firstWhere((w) => w.type == 'Balance').id!;
      _adjustWallet(balId, -tx.amount);
    } else { _adjustWallet(tx.sourceWalletId, tx.amount); }
    await (await DatabaseHelper.instance.database).delete('transactions', where: 'id = ?', whereArgs: [txId]);
    await loadAllData();
  }

  void _adjustWallet(int id, double amount) async {
    final db = await DatabaseHelper.instance.database;
    final w = wallets.firstWhere((w) => w.id == id);
    await db.update('wallets', {'amount': w.amount + amount}, where: 'id = ?', whereArgs: [id]);
  }

  String formatLakh(double amount) {
    if (isLakhEnabled && amount.abs() >= 100000) return "${(amount / 100000).toStringAsFixed(1)} Lakh";
    return NumberFormat('#,###').format(amount);
  }

  double get currentMonthExpense {
    DateTime now = DateTime.now();
    return transactions.where((tx) {
      DateTime d = DateTime.parse(tx.dateTimestamp);
      return d.year == now.year && d.month == now.month && (tx.type == 'Expense' || tx.type == 'HomeTransfer');
    }).fold(0.0, (sum, tx) => sum + tx.amount);
  }

  Map<String, double> getSummaryByTypeAndCategory(String period, String typeGroup) {
    DateTime now = DateTime.now();
    var filtered = transactions.where((tx) {
      DateTime d = DateTime.parse(tx.dateTimestamp);
      bool tMatch = period == 'Monthly' ? (d.year == now.year && d.month == now.month) : (d.year == now.year);
      bool typeMatch = typeGroup == 'In' ? ['Income', 'IncomeFromBank', 'IncomeFromHusband'].contains(tx.type) : ['Expense', 'HomeTransfer', 'BankDeposit', 'HusbandDeposit'].contains(tx.type);
      return tMatch && typeMatch;
    });
    Map<String, double> sum = {};
    for (var tx in filtered) {
      String cat = categories.firstWhere((c) => c.id == tx.categoryId).name;
      sum[cat] = (sum[cat] ?? 0.0) + tx.amount;
    }
    return sum;
  }

  double getPeriodTotal(String p, String g) => getSummaryByTypeAndCategory(p, g).values.fold(0.0, (a, b) => a + b);
  double get totalAssets => wallets.fold(0.0, (s, i) => s + i.amount);
  double get totalBalance => wallets.where((w) => w.type == 'Balance').fold(0.0, (s, i) => s + i.amount);
  Future<void> addWallet(AppWallet w) async { await (await DatabaseHelper.instance.database).insert('wallets', w.toMap()); await loadAllData(); }
  void toggleLakh(bool v) async { isLakhEnabled = v; (await SharedPreferences.getInstance()).setBool('isLakhEnabled', v); notifyListeners(); }
  void updateSyncTime() async { lastSyncTime = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()); (await SharedPreferences.getInstance()).setString('lastSyncTime', lastSyncTime); notifyListeners(); }
}
