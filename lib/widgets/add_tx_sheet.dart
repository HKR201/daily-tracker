import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:math_expressions/math_expressions.dart';
import '../providers/tracker_provider.dart';
import '../models/app_models.dart';

class AddTxSheet extends StatefulWidget {
  const AddTxSheet({super.key});

  @override
  State<AddTxSheet> createState() => _AddTxSheetState();
}

class _AddTxSheetState extends State<AddTxSheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  String _calcResult = '';
  bool _isError = false;
  AppCategory? _selectedCategory;
  String _txType = 'E'; // E = Expense, In = Income

  void _evaluateMath(String input) {
    if (input.isEmpty) {
      setState(() {
        _calcResult = '';
        _isError = false;
      });
      return;
    }
    try {
      // အမှားရိုက်မိတာတွေကို ရှင်းလင်းပေးတဲ့ နေရာ
      String sanitized = input.replaceAll(RegExp(r'[^0-9\+\-\*\/\.]'), '');
      sanitized = sanitized.replaceAll(RegExp(r'\+\++'), '+');
      sanitized = sanitized.replaceAll(RegExp(r'\-\-+'), '-');
      
      Parser p = Parser();
      Expression exp = p.parse(sanitized);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      setState(() {
        if (eval == eval.toInt()) {
          _calcResult = eval.toInt().toString();
        } else {
          _calcResult = eval.toStringAsFixed(2);
        }
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _calcResult = 'Error';
        _isError = true;
      });
    }
  }

  void _save() {
    if (_calcResult.isEmpty || _calcResult == 'Error' || _calcResult == '0') return;
    if (_selectedCategory == null) return;

    double finalAmount = double.parse(_calcResult);
    
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    provider.addTransaction(
      amount: finalAmount,
      type: _txType,
      categoryId: _selectedCategory!.id!,
      note: _noteCtrl.text,
    );
    
    Navigator.pop(context); // Form ကို ပိတ်ပါမယ်
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final typeCategories = provider.categories.where((c) => c.type == (_txType == 'E' ? 'Expense' : 'Income')).toList();

    return Padding(
      // Keyboard တက်လာရင် Form ပါ အပေါ်ကို ရွှေ့ပေးမယ့် padding
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 20),
            
            // Expense / Income ရွေးချယ်ရန်
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Expense (ထွက်ငွေ)')),
                    selected: _txType == 'E',
                    onSelected: (val) { setState(() { _txType = 'E'; _selectedCategory = null; }); },
                    selectedColor: Colors.red[100],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Income (ဝင်ငွေ)')),
                    selected: _txType == 'In',
                    onSelected: (val) { setState(() { _txType = 'In'; _selectedCategory = null; }); },
                    selectedColor: Colors.green[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Smart Calculator ပမာဏထည့်ရန်
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Amount (e.g. 1500+300)',
                suffixText: _calcResult.isNotEmpty && !_isError ? '= $_calcResult' : _calcResult,
                suffixStyle: TextStyle(
                  color: _isError ? Colors.red : Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onChanged: _evaluateMath,
            ),
            const SizedBox(height: 15),

            // အမျိုးအစား (Category) ရွေးရန်
            DropdownButtonFormField<AppCategory>(
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), labelText: 'Category'),
              value: _selectedCategory,
              items: typeCategories.map((c) {
                return DropdownMenuItem(value: c, child: Text(c.name));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 15),
            
            // မှတ်စု (Note)
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 25),

            // Save ခလုတ်
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _txType == 'E' ? Colors.redAccent : Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: _save,
                child: const Text('Save Transaction', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
