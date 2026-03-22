import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:math_expressions/math_expressions.dart';
import '../providers/tracker_provider.dart';
import '../models/app_models.dart';

class AddTxSheet extends StatefulWidget {
  final String txType; // 'E' (Expense) သို့မဟုတ် 'In' (Income) ကို အပြင်ကနေ လှမ်းပို့ပေးရပါမယ်
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

  // Zero-Click Save Logic (Category နှိပ်တာနဲ့ အလုပ်လုပ်ပါမယ်)
  void _saveWithCategory(AppCategory category) async {
    if (_calcResult.isEmpty || _calcResult == 'Error' || _calcResult == '0') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    double finalAmount = double.parse(_calcResult);
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    
    // 1. Save လုပ်ပြီး ID ကို ယူပါမယ်
    int newTxId = await provider.addTransaction(
      amount: finalAmount,
      type: widget.txType,
      categoryId: category.id!,
      note: _noteCtrl.text,
    );
    
    // 2. Form ကို ပိတ်ပါမယ်
    if (!mounted) return;
    Navigator.pop(context);

    // 3. ၄ စက္ကန့်တိတိ ပေါ်နေမယ့် UNDO (ပြန်ဖျက်ရန်) SnackBar ကို ပြပါမယ်
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.title} Saved: $finalAmount Ks'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.redAccent,
          onPressed: () {
            // UNDO နှိပ်ရင် ခုနက ID ကို ပြန်ဖျက်ခိုင်းပါမယ်
            provider.deleteTransaction(newTxId);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final typeCategories = provider.categories.where((c) => c.type == (widget.txType == 'E' ? 'Expense' : 'Income')).toList();
    final color = widget.txType == 'E' ? Colors.redAccent : Colors.green;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            
            // ခေါင်းစဉ် (Expense သို့မဟုတ် Income)
            Text(widget.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 20),
            
            // Amount Input
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Amount (e.g. 1500+300)',
                suffixText: _calcResult.isNotEmpty && !_isError ? '= $_calcResult' : _calcResult,
                suffixStyle: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: color, width: 2)),
              ),
              onChanged: _evaluateMath,
            ),
            const SizedBox(height: 15),

            // Note Input
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 25),

            const Text('Tap a category to save (Zero-Click)', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 10),

            // Categories ကို ခလုတ်လေးတွေ (Chips) အနေနဲ့ ပြပါမယ်
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
                  onPressed: () => _saveWithCategory(c), // နှိပ်လိုက်တာနဲ့ Save ပါမယ်
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
