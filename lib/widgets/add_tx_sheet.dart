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
  bool _showNote = false; // Note ကို နှိပ်မှပေါ်အောင် ထိန်းချုပ်မည့် Variable
  DateTime _selectedDate = DateTime.now();
  
  AppWallet? _selectedSourceWallet;

  @override
  void initState() {
    super.initState();
    // Form စပွင့်တာနဲ့ Default အနေဖြင့် "Balance (Main Cash)" ကို ရွေးပေးထားပါမည်
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TrackerProvider>(context, listen: false);
      if (provider.wallets.isNotEmpty) {
        setState(() {
          _selectedSourceWallet = provider.wallets.firstWhere((w) => w.type == 'Balance');
        });
      }
    });
  }

  void _evaluateMath(String input) {
    if (input.isEmpty) {
      setState(() { _calcResult = ''; _isError = false; });
      return;
    }
    try {
      String sanitized = input.replaceAll(RegExp(r'[^0-9\+\-\*\/\.]'), '');
      sanitized = sanitized.replaceAll(RegExp(r'\+\++'), '+');
      sanitized = sanitized.replaceAll(RegExp(r'\-\-+'), '-');
      
      Parser p = Parser();
      Expression exp = p.parse(sanitized);
      double eval = exp.evaluate(EvaluationType.REAL, ContextModel());
      
      setState(() {
        _calcResult = eval == eval.toInt() ? eval.toInt().toString() : eval.toStringAsFixed(2);
        _isError = false;
      });
    } catch (e) {
      setState(() { _calcResult = 'Error'; _isError = true; });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveWithCategory(AppCategory category) async {
    if (_calcResult.isEmpty || _calcResult == 'Error' || _calcResult == '0') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter amount')));
      return;
    }
    if (_selectedSourceWallet == null) return;

    double finalAmount = double.parse(_calcResult);
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    
    int newTxId = await provider.addTransaction(
      amount: finalAmount,
      type: widget.txType,
      sourceWalletId: _selectedSourceWallet!.id!,
      categoryId: category.id!,
      note: _noteCtrl.text,
      dateString: _selectedDate.toIso8601String(),
    );
    
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.title} Saved!'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        action: SnackBarAction(label: 'UNDO', textColor: Colors.redAccent, onPressed: () => provider.deleteTransaction(newTxId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final typeCategories = provider.categories.where((c) => c.type == (widget.txType == 'E' ? 'Expense' : 'Income')).toList();
    final color = widget.txType == 'E' ? Colors.redAccent : Colors.blueAccent;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            
            // ခေါင်းစဉ်
            Text(widget.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 15),

            // Calendar ရက်စွဲ ရွေးချယ်ရန်
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.chevron_left, color: Colors.grey),
                    Text(DateFormat('dd-MMM-yyyy').format(_selectedDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            // Amount Input (Cash In / Cash Out)
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: widget.txType == 'E' ? 'Cash Out (ထွက်ငွေ)' : 'Cash In (ဝင်ငွေ)',
                labelStyle: TextStyle(color: color),
                suffixText: _calcResult.isNotEmpty && !_isError ? '= $_calcResult' : _calcResult,
                suffixStyle: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color, width: 2)),
              ),
              onChanged: _evaluateMath,
            ),
            const SizedBox(height: 15),

            // From (ဘယ်အိတ်ကပ်ကနေလဲ) - Dropdown
            DropdownButtonFormField<AppWallet>(
              decoration: InputDecoration(
                labelText: 'From (ဘယ်ကနေလဲ)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
              value: _selectedSourceWallet,
              items: provider.wallets.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
              onChanged: (val) => setState(() => _selectedSourceWallet = val),
            ),
            const SizedBox(height: 15),

            // Note ကို လိုအပ်မှပေါ်အောင် လုပ်ထားပါသည်
            if (!_showNote)
              TextButton.icon(
                onPressed: () => setState(() => _showNote = true),
                icon: const Icon(Icons.edit_note, color: Colors.grey),
                label: const Text('Add Note (မှတ်စုထည့်ရန်)', style: TextStyle(color: Colors.grey)),
              )
            else
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            const SizedBox(height: 25),

            // Category ရွေးချယ်ပြီး Save မည့်နေရာ
            const Text('Tap a category to save (Zero-Click)', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: typeCategories.map((c) {
                return ActionChip(
                  elevation: 2,
                  backgroundColor: color.withOpacity(0.1),
                  side: BorderSide.none,
                  label: Text(c.name, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  avatar: Icon(IconData(c.iconData, fontFamily: 'MaterialIcons'), color: color, size: 18),
                  onPressed: () => _saveWithCategory(c),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
