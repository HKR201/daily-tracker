import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/tracker_provider.dart';
import '../models/app_models.dart';
import '../widgets/add_tx_sheet.dart'; 

class LedgerPage extends StatefulWidget {
  final String initialLabel; 
  const LedgerPage({super.key, required this.initialLabel});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  String _selectedLabel = 'All';
  String _filterType = 'All'; 
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedLabel = widget.initialLabel;
  }

  Future<void> _pickTimeFilter(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16.0), child: Text('Filter by Time (အချိန်ဖြင့် စစ်ထုတ်ရန်)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ListTile(
                leading: const Icon(Icons.all_inclusive), title: const Text('All Time (စရင်းအားလုံး)'),
                onTap: () { setState(() { _filterType = 'All'; }); Navigator.pop(ctx); },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today), title: const Text('By Year (နှစ်အလိုက်)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDatePickerMode: DatePickerMode.year);
                  if (picked != null) setState(() { _filterType = 'Year'; _selectedDate = picked; });
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range), title: const Text('By Month (လအလိုက်)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setState(() { _filterType = 'Month'; _selectedDate = picked; });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month), title: const Text('By Day (ရက်အလိုက်)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setState(() { _filterType = 'Day'; _selectedDate = picked; });
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _openEditSheet(AppTransaction tx, AppCategory cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor, 
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))
        ),
        child: AddTxSheet(txType: cat.type, title: 'Record', existingTx: tx),
      )
    );
  }

  String get _timeFilterText {
    if (_filterType == 'All') return 'All Time';
    if (_filterType == 'Year') return DateFormat('yyyy').format(_selectedDate);
    if (_filterType == 'Month') return DateFormat('MMM yyyy').format(_selectedDate);
    if (_filterType == 'Day') return DateFormat('dd MMM yyyy').format(_selectedDate);
    return 'All Time';
  }

  String _getWalletName(int walletId, List<AppWallet> wallets) {
    try {
      return wallets.firstWhere((w) => w.id == walletId).name;
    } catch (e) {
      return 'ပြင်ပ (External)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    final currencyFormat = NumberFormat('#,###');

    // 🌟 OPTIMIZATION: Build အတွင်း တွက်ချက်ခြင်းများကို ဖယ်ရှားပြီး Provider ထဲမှ တိုက်ရိုက်ခေါ်ယူသည်
    final filteredList = p.getFilteredTransactions(_selectedLabel, _filterType, _selectedDate);

    double totalAmount = filteredList.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger (မှတ်တမ်းများ)', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.white,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedLabel,
                      items: ['All', ...p.categories.map((c) => c.name).toSet()].map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (v) => setState(() => _selectedLabel = v!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTimeFilter(context),
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: Text(_timeFilterText, overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent, side: const BorderSide(color: Colors.blueAccent)),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: Colors.blueAccent.withOpacity(0.05),
            child: Column(
              children: [
                Text('Total Amount ($_timeFilterText)', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 5),
                Text(
                  '${p.formatLakh(totalAmount)} Ks', 
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent)
                ),
              ],
            ),
          ),

          Expanded(
            child: filteredList.isEmpty 
              ? const Center(child: Text('No records found (မှတ်တမ်းမရှိပါ)', style: TextStyle(color: Colors.grey))) 
              : ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final tx = filteredList[index];
                bool isExp = ['Expense', 'HomeTransfer', 'BankDeposit', 'HusbandDeposit'].contains(tx.type);
                final cat = p.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => AppCategory(name: 'Unknown', iconData: 0xe000, type: 'Expense'));
                
                String walletName = _getWalletName(tx.sourceWalletId, p.wallets);
                String noteText = tx.note.isNotEmpty ? ' • ${tx.note}' : '';
                String displayDate = DateFormat('dd MMM yyyy').format(DateTime.parse(tx.dateTimestamp));

                // 🌟 UI/UX FIX: Flutter's Built-in Dismissible ကို အသုံးပြုထားသည်
                return Dismissible(
                  key: Key(tx.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    p.deleteTransaction(tx.id!);
                    
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Record deleted'),
                        duration: const Duration(seconds: 2), 
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'UNDO', 
                          textColor: Colors.blueAccent, 
                          onPressed: () => p.undoDelete(tx)
                        ),
                      )
                    );
                  },
                  child: InkWell(
                    onTap: () => _openEditSheet(tx, cat),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isExp ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), 
                        child: Icon(IconData(cat.iconData, fontFamily: 'MaterialIcons'), color: isExp ? Colors.redAccent : Colors.green)
                      ),
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$walletName • $displayDate$noteText'),
                      trailing: Text('${isExp ? '-' : '+'}${currencyFormat.format(tx.amount)}', style: TextStyle(color: isExp ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
