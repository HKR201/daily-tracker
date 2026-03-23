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
  bool isDarkMode = false;
  String lastSyncTime = "Never";

  // ခေါင်းစဉ်နာမည်များအတွက် Variable အသစ်များ (စကင်ဖတ်ထားသည့်အတိုင်း)
  String hubTitle = 'The Daily Hub';
  String vaultTitle = 'The Vault';

  TrackerProvider() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    isLakhEnabled = prefs.getBool('isLakhEnabled') ?? true;
    isDarkMode = prefs.getBool('isDarkMode') ?? false;
    lastSyncTime = prefs.getString('lastSyncTime') ?? "Never";
    
    // ခေါင်းစဉ်များကို ဖုန်း Memory မှ ပြန်ခေါ်ခြင်း
    hubTitle = prefs.getString('hubTitle') ?? 'The Daily Hub';
    vaultTitle = prefs.getString('vaultTitle') ?? 'The Vault';
    
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
      await db.insert('categories', {'name': 'ကိုကြီး', 'icon_data': 0xe314, 'type': 'HomeTransfer'});
      await db.insert('categories', {'name': 'လွှဲငွေ', 'icon_data': 0xe491, 'type': 'HusbandDeposit'});
    }
    await loadAllData();
  }

  Future<void> loadAllData() async {
    isLoading = true; notifyListeners();
    final db = await DatabaseHelper.instance.database;
    wallets = (await db.query('wallets')).map((e) => AppWallet.fromMap(e)).toList();
    categories = (await db.query('categories')).map((e) => AppCategory.fromMap(e)).toList();
    transactions = (await db.query('transactions', orderBy: 'date_timestamp DESC')).map((e) => AppTransaction.fromMap(e)).toList();
    isLoading = false; notifyListeners();
  }

  void toggleTheme() async {
    isDarkMode = !isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    notifyListeners();
  }

  // ခေါင်းစဉ်များကို ပြင်ဆင်ရန် Function အသစ်များ
  Future<void> updateHubTitle(String newTitle) async {
    hubTitle = newTitle;
    (await SharedPreferences.getInstance()).setString('hubTitle', newTitle);
    notifyListeners();
  }

  Future<void> updateVaultTitle(String newTitle) async {
    vaultTitle = newTitle;
    (await SharedPreferences.getInstance()).setString('vaultTitle', newTitle);
    notifyListeners();
  }

  // အိတ်ကပ်နာမည်များကို ပြင်ဆင်ရန် Function အသစ်
  Future<void> renameWallet(int id, String newName) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('wallets', {'name': newName}, where: 'id = ?', whereArgs: [id]);
    await loadAllData(); // Data အသစ်ပြန်ခေါ်၍ UI ကို Update လုပ်မည်
  }

  // Label အသစ်လုပ်လျှင် Icon ပါ ရွေးချယ်နိုင်ရန် Parameter (iconData) ကို ထပ်တိုးထားသည်
  Future<void> addNewCategory(String name, String type, int iconData) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('categories', {'name': name, 'icon_data': iconData, 'type': type});
    await loadAllData();
  }

  Future<int> addTransaction({required double amount, required String type, required int sourceWalletId, required int categoryId, required String note, required String dateString}) async {
    final db = await DatabaseHelper.instance.database;
    int? destWalletId;

    if (type == 'IncomeFromBank' || type == 'IncomeFromHusband') {
      destWalletId = wallets.firstWhere((w) => w.type == 'Balance').id;
      await _adjustWallet(sourceWalletId, -amount); 
      await _adjustWallet(destWalletId!, amount);
    } else if (type == 'BankDeposit' || type == 'HusbandDeposit') {
      destWalletId = type == 'BankDeposit' ? wallets.firstWhere((w) => w.type == 'Bank').id : wallets.firstWhere((w) => w.type == 'Person').id;
      await _adjustWallet(sourceWalletId, -amount); 
      await _adjustWallet(destWalletId!, amount);
    } else if (type == 'Income') {
      int balId = wallets.firstWhere((w) => w.type == 'Balance').id!;
      await _adjustWallet(balId, amount);
    } else {
      await _adjustWallet(sourceWalletId, -amount);
    }

    int id = await db.insert('transactions', AppTransaction(amount: amount, type: type, sourceWalletId: sourceWalletId, destinationWalletId: destWalletId, categoryId: categoryId, note: note, dateTimestamp: dateString).toMap());
    await loadAllData(); return id;
  }

  Future<void> deleteTransaction(int txId) async {
    final tx = transactions.firstWhere((t) => t.id == txId);
    if (tx.type == 'BankDeposit' || tx.type == 'HusbandDeposit' || tx.type == 'IncomeFromBank' || tx.type == 'IncomeFromHusband') {
      await _adjustWallet(tx.sourceWalletId, tx.amount); 
      await _adjustWallet(tx.destinationWalletId!, -tx.amount);
    } else if (tx.type == 'Income') {
      int balId = wallets.firstWhere((w) => w.type == 'Balance').id!;
      await _adjustWallet(balId, -tx.amount);
    } else {
      await _adjustWallet(tx.sourceWalletId, tx.amount);
    }
    await (await DatabaseHelper.instance.database).delete('transactions', where: 'id = ?', whereArgs: [txId]);
    await loadAllData();
  }

  Future<void> undoDelete(AppTransaction oldTx) async {
    await addTransaction(
      amount: oldTx.amount, type: oldTx.type, sourceWalletId: oldTx.sourceWalletId,
      categoryId: oldTx.categoryId!, note: oldTx.note, dateString: oldTx.dateTimestamp
    );
  }

  Future<void> updateTransaction(AppTransaction oldTx, {required double amount, required String type, required int sourceWalletId, required int categoryId, required String note, required String dateString}) async {
    
    if (oldTx.type == 'BankDeposit' || oldTx.type == 'HusbandDeposit' || oldTx.type == 'IncomeFromBank' || oldTx.type == 'IncomeFromHusband') {
      await _adjustWallet(oldTx.sourceWalletId, oldTx.amount); 
      await _adjustWallet(oldTx.destinationWalletId!, -oldTx.amount);
    } else if (oldTx.type == 'Income') {
      int balId = wallets.firstWhere((w) => w.type == 'Balance').id!;
      await _adjustWallet(balId, -oldTx.amount);
    } else {
      await _adjustWallet(oldTx.sourceWalletId, oldTx.amount);
    }

    int? destWalletId;
    if (type == 'IncomeFromBank' || type == 'IncomeFromHusband') {
      destWalletId = wallets.firstWhere((w) => w.type == 'Balance').id;
      await _adjustWallet(sourceWalletId, -amount); 
      await _adjustWallet(destWalletId!, amount); 
    } else if (type == 'BankDeposit' || type == 'HusbandDeposit') {
      destWalletId = type == 'BankDeposit' ? wallets.firstWhere((w) => w.type == 'Bank').id : wallets.firstWhere((w) => w.type == 'Person').id;
      await _adjustWallet(sourceWalletId, -amount); 
      await _adjustWallet(destWalletId!, amount); 
    } else if (type == 'Income') {
      int balId = wallets.firstWhere((w) => w.type == 'Balance').id!;
      await _adjustWallet(balId, amount);
    } else {
      await _adjustWallet(sourceWalletId, -amount);
    }

    final db = await DatabaseHelper.instance.database;
    await db.update('transactions', 
      AppTransaction(id: oldTx.id, amount: amount, type: type, sourceWalletId: sourceWalletId, destinationWalletId: destWalletId, categoryId: categoryId, note: note, dateTimestamp: dateString).toMap(),
      where: 'id = ?', whereArgs: [oldTx.id]
    );
    await loadAllData();
  }

  Future<void> _adjustWallet(int id, double amount) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> res = await db.query('wallets', where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) {
      double currentAmount = res.first['amount'];
      await db.update('wallets', {'amount': currentAmount + amount}, where: 'id = ?', whereArgs: [id]);
    }
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
      DateTime date = DateTime.parse(tx.dateTimestamp);
      bool timeMatch = period == 'Monthly' ? (date.year == now.year && date.month == now.month) : (date.year == now.year);
      bool typeMatch = typeGroup == 'In' ? ['Income', 'IncomeFromBank', 'IncomeFromHusband'].contains(tx.type) : ['Expense', 'HomeTransfer', 'BankDeposit', 'HusbandDeposit'].contains(tx.type);
      return timeMatch && typeMatch;
    });

    Map<String, double> summary = {};
    for (var tx in filtered) {
      String catName = categories.firstWhere((c) => c.id == tx.categoryId).name;
      summary[catName] = (summary[catName] ?? 0.0) + tx.amount;
    }
    return summary;
  }

  double getPeriodTotal(String period, String typeGroup) {
    return getSummaryByTypeAndCategory(period, typeGroup).values.fold(0.0, (a, b) => a + b);
  }

  double get totalAssets => wallets.fold(0.0, (sum, item) => sum + item.amount);
  double get totalBalance => wallets.where((w) => w.type == 'Balance').fold(0.0, (sum, item) => sum + item.amount);

  void toggleLakh(bool val) async { isLakhEnabled = val; (await SharedPreferences.getInstance()).setBool('isLakhEnabled', val); notifyListeners(); }
  void updateSyncTime() async { lastSyncTime = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()); (await SharedPreferences.getInstance()).setString('lastSyncTime', lastSyncTime); notifyListeners(); }
  Future<void> addWallet(AppWallet wallet) async { await (await DatabaseHelper.instance.database).insert('wallets', wallet.toMap()); await loadAllData(); }
}
