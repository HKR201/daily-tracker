import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:intl/intl.dart';
import '../providers/tracker_provider.dart';
import '../models/app_models.dart';

class AddTxSheet extends StatefulWidget {
  final String txType; 
  final String title;

  const AddTxSheet({super.key, required this.txType, required this.title});

  @override
  State<AddTxSheet> createState() => _AddTxSheetState();
}

class _AddTxSheetState extends State<AddTxSheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  
  String _calcResult = '';
  bool _isError = false;
  bool _showNote = false; 
  DateTime _selectedDate = DateTime.now();
  
  AppWallet? _selectedSourceWallet;
  
  // Income တွင်သာ သုံးမည့် "ပြင်ပရင်းမြစ်" Fake Wallet
  final AppWallet _externalWallet = AppWallet(id: -1, name: 'ပြင်ပရင်းမြစ် (External)', type: 'External', amount: 0, lastUpdated: '');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TrackerProvider>(context, listen: false);
      setState(() {
        if (widget.txType == 'Income') {
          _selectedSourceWallet = _externalWallet;
        } else if (provider.wallets.isNotEmpty) {
          _selectedSourceWallet = provider.wallets.firstWhere((w) => w.type == 'Balance');
        }
      });
    });
  }

  void _evaluateMath(String input) {
    if (input.isEmpty) { setState(() { _calcResult = ''; _isError = false; }); return; }
    try {
      String sanitized = input.replaceAll(RegExp(r'[^0-9\+\-\*\/\.]'), '').replaceAll(RegExp(r'\+\++'), '+').replaceAll(RegExp(r'\-\-+'), '-');
      double eval = Parser().parse(sanitized).evaluate(EvaluationType.REAL, ContextModel());
      setState(() { _calcResult = eval == eval.toInt() ? eval.toInt().toString() : eval.toStringAsFixed(2); _isError = false; });
    } catch (e) {
      setState(() { _calcResult = 'Error'; _isError = true; });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null && picked != _selectedDate) setState(() => _selectedDate = picked);
  }

  void _showAddLabelDialog() {
    String newLabel = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Label'),
        content: TextField(autofocus: true, decoration: const InputDecoration(hintText: 'Enter name'), onChanged: (val) => newLabel = val),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (newLabel.trim().isNotEmpty) {
                Provider.of<TrackerProvider>(context, listen: false).addNewCategory(newLabel.trim(), widget.txType);
                Navigator.pop(ctx);
              }
            }, 
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _saveWithCategory(AppCategory category) async {
    if (_calcResult.isEmpty || _calcResult == 'Error' || _calcResult == '0') return;
    if (_selectedSourceWallet == null) return;

    final provider = Provider.of<TrackerProvider>(context, listen: false);
    
    // Income Form မှ လာသော Logic များကို ခွဲထုတ်ခြင်း
    String finalTxType = widget.txType;
    int finalSourceId = _selectedSourceWallet!.id!;

    if (widget.txType == 'Income') {
      if (_selectedSourceWallet!.id == -1) {
        finalTxType = 'Income'; // ပြင်ပဝင်ငွေ
        finalSourceId = provider.wallets.firstWhere((w) => w.type == 'Balance').id!;
      } else if (_selectedSourceWallet!.type == 'Bank') {
        finalTxType = 'IncomeFromBank'; // ဘဏ်မှဝင်ငွေ
      } else if (_selectedSourceWallet!.type == 'Person') {
        finalTxType = 'IncomeFromHusband'; // ယောကျ်ားမှဝင်ငွေ
      }
    }

    int newTxId = await provider.addTransaction(
      amount: double.parse(_calcResult), type: finalTxType,
      sourceWalletId: finalSourceId, categoryId: category.id!,
      note: _noteCtrl.text, dateString: _selectedDate.toIso8601String(),
    );
    
    if (!mounted) return;
    Navigator.pop(context);
    
    // SnackBar ပြဿနာဖြေရှင်းခြင်း (FAB အပေါ်မှာပေါ်မယ်၊ ၃ စက္ကန့်နဲ့ပျောက်မယ်)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.title} Saved!'), 
        duration: const Duration(seconds: 3), 
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
        backgroundColor: Colors.black87,
        action: SnackBarAction(label: 'UNDO', textColor: Colors.redAccent, onPressed: () => provider.deleteTransaction(newTxId))
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final typeCategories = provider.categories.where((c) => c.type == widget.txType).toList();
    final color = (widget.txType == 'Expense' || widget.txType == 'HomeTransfer') ? Colors.redAccent : Colors.blueAccent;

    // Dropdown တွင်ပေါ်မည့် အိတ်ကပ်များ
    List<AppWallet> availableWallets = [];
    if (widget.txType == 'Income') {
      availableWallets = [_externalWallet, ...provider.wallets.where((w) => w.type == 'Bank' || w.type == 'Person')];
    } else {
      availableWallets = provider.wallets.where((w) {
        if (widget.txType == 'BankDeposit' && w.type == 'Bank') return false;
        if (widget.txType == 'HusbandDeposit' && w.type == 'Person') return false;
        return true;
      }).toList();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Text(widget.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 15),

            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Icon(Icons.chevron_left, color: Colors.grey), Text(DateFormat('dd-MMM-yyyy').format(_selectedDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Icon(Icons.calendar_today, color: color)]),
              ),
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _amountCtrl, keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(labelText: widget.txType == 'Income' ? 'Cash In (ဝင်ငွေ)' : 'Cash Out (ထွက်ငွေ)', labelStyle: TextStyle(color: color), suffixText: _calcResult.isNotEmpty && !_isError ? '= $_calcResult' : _calcResult, suffixStyle: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color, width: 2))),
              onChanged: _evaluateMath,
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<AppWallet>(
              decoration: InputDecoration(labelText: 'From (ဘယ်ကနေ ဝင်/ထွက် မလဲ)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
              value: availableWallets.contains(_selectedSourceWallet) ? _selectedSourceWallet : (availableWallets.isNotEmpty ? availableWallets.first : null),
              items: availableWallets.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
              onChanged: (val) => setState(() => _selectedSourceWallet = val),
            ),
            const SizedBox(height: 15),

            if (!_showNote) TextButton.icon(onPressed: () => setState(() => _showNote = true), icon: const Icon(Icons.edit_note, color: Colors.grey), label: const Text('Add Note', style: TextStyle(color: Colors.grey)))
            else TextField(controller: _noteCtrl, decoration: InputDecoration(labelText: 'Notes', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 25),

            const Text('Tap a category to save (Zero-Click)', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 10),
            
            Wrap(
              spacing: 10, runSpacing: 10,
              children: [
                ...typeCategories.map((c) => ActionChip(elevation: 2, backgroundColor: color.withOpacity(0.1), side: BorderSide.none, label: Text(c.name, style: TextStyle(color: color, fontWeight: FontWeight.bold)), avatar: Icon(IconData(c.iconData, fontFamily: 'MaterialIcons'), color: color, size: 18), onPressed: () => _saveWithCategory(c))),
                ActionChip(elevation: 2, backgroundColor: Colors.grey[200], side: BorderSide.none, label: Text('+ Add Label', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)), onPressed: _showAddLabelDialog),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
