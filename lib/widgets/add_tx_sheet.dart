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
  final AppWallet _externalWallet = AppWallet(id: -1, name: 'ပြင်ပရင်းမြစ်', type: 'External', amount: 0, lastUpdated: '');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Provider.of<TrackerProvider>(context, listen: false);
      setState(() {
        if (widget.txType == 'Income') _selectedSourceWallet = _externalWallet;
        else if (p.wallets.isNotEmpty) _selectedSourceWallet = p.wallets.firstWhere((w) => w.type == 'Balance');
      });
    });
  }

  void _evaluateMath(String input) {
    if (input.isEmpty) { setState(() { _calcResult = ''; _isError = false; }); return; }
    String raw = input.replaceAll(',', '');
    String formatted = raw.replaceAllMapped(RegExp(r'\d+'), (m) => NumberFormat('#,###').format(int.parse(m.group(0)!)));
    if (input != formatted) {
      _amountCtrl.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
    }
    try {
      String sanitized = raw.replaceAll(RegExp(r'[^0-9\+\-\*\/\.]'), '').replaceAll(RegExp(r'\+\++'), '+').replaceAll(RegExp(r'\-\-+'), '-');
      double eval = Parser().parse(sanitized).evaluate(EvaluationType.REAL, ContextModel());
      setState(() { 
        _calcResult = eval == eval.toInt() ? NumberFormat('#,###').format(eval.toInt()) : NumberFormat('#,###.##').format(eval); 
        _isError = false; 
      });
    } catch (e) { setState(() { _calcResult = 'Error'; _isError = true; }); }
  }

  void _showAddLabelDialog() {
    String newLabel = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Label'),
        content: TextField(autofocus: true, onChanged: (val) => newLabel = val),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (newLabel.trim().isNotEmpty) {
                Provider.of<TrackerProvider>(context, listen: false).addNewCategory(newLabel.trim(), widget.txType);
                Navigator.pop(ctx);
              }
            }, 
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _saveWithCategory(AppCategory category) async {
    if (_calcResult.isEmpty || _calcResult == 'Error' || _calcResult == '0') return;
    final p = Provider.of<TrackerProvider>(context, listen: false);
    double amount = double.parse(_calcResult.replaceAll(',', ''));
    String finalType = widget.txType;
    int sourceId = _selectedSourceWallet!.id!;

    if (widget.txType == 'Income') {
      if (_selectedSourceWallet!.id == -1) { finalType = 'Income'; sourceId = p.wallets.firstWhere((w) => w.type == 'Balance').id!; }
      else if (_selectedSourceWallet!.type == 'Bank') finalType = 'IncomeFromBank';
      else if (_selectedSourceWallet!.type == 'Person') finalType = 'IncomeFromHusband';
    }

    int id = await p.addTransaction(amount: amount, type: finalType, sourceWalletId: sourceId, categoryId: category.id!, note: _noteCtrl.text, dateString: _selectedDate.toIso8601String());
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.title} Saved!'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final cats = provider.categories.where((c) => c.type == widget.txType).toList();
    final color = (widget.txType == 'Expense' || widget.txType == 'HomeTransfer') ? Colors.redAccent : Colors.blueAccent;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 15),
            TextField(controller: _amountCtrl, keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), onChanged: _evaluateMath, decoration: InputDecoration(labelText: 'Amount', suffixText: '= $_calcResult')),
            const SizedBox(height: 15),
            DropdownButtonFormField<AppWallet>(
              value: _selectedSourceWallet,
              items: (widget.txType == 'Income' ? [_externalWallet, ...provider.wallets.where((w) => w.type != 'Balance')] : provider.wallets).map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
              onChanged: (val) => setState(() => _selectedSourceWallet = val),
              decoration: const InputDecoration(labelText: 'From/To'),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ...cats.map((c) => ActionChip(label: Text(c.name), onPressed: () => _saveWithCategory(c))),
                ActionChip(backgroundColor: Colors.grey[200], label: const Text('+ Add'), onPressed: _showAddLabelDialog),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
