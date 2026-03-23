import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/tracker_provider.dart';
import '../models/app_models.dart';

// ညာဘက်ဆွဲလျှင် Delete Icon ပေါ်ပြီး ထပ်နှိပ်မှဖျက်မည့် Custom Widget (Ledger အတွက် သီးသန့်)
class SwipeToDeleteLedgerItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  const SwipeToDeleteLedgerItem({super.key, required this.child, required this.onDelete});

  @override
  State<SwipeToDeleteLedgerItem> createState() => _SwipeToDeleteLedgerItemState();
}

class _SwipeToDeleteLedgerItemState extends State<SwipeToDeleteLedgerItem> {
  double _dragExtent = 0;
  final double _maxDrag = 80;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragExtent -= details.primaryDelta!;
          if (_dragExtent < 0) _dragExtent = 0;
          if (_dragExtent > _maxDrag) _dragExtent = _maxDrag;
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() => _dragExtent = (_dragExtent > _maxDrag / 2) ? _maxDrag : 0);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.redAccent,
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  setState(() => _dragExtent = 0);
                  widget.onDelete(); // တကယ်ဖျက်မည့် နေရာ
                },
                child: Container(width: _maxDrag, alignment: Alignment.center, child: const Icon(Icons.delete, color: Colors.white)),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(-_dragExtent, 0),
            child: Container(color: Theme.of(context).scaffoldBackgroundColor, child: widget.child),
          ),
        ],
      ),
    );
  }
}

class LedgerPage extends StatefulWidget {
  final String initialLabel; // Vault မှ ဝင်လာလျှင် ပါလာမည့် Label
  const LedgerPage({super.key, required this.initialLabel});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  String _selectedLabel = 'All';
  String _filterType = 'All'; // 'All', 'Year', 'Month', 'Day'
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedLabel = widget.initialLabel;
  }

  // အချိန်ရွေးချယ်မည့် Dialog
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

  // Filter ၏ ခေါင်းစဉ်စာသားကို ဖော်ပြရန်
  String get _timeFilterText {
    if (_filterType == 'All') return 'All Time';
    if (_filterType == 'Year') return DateFormat('yyyy').format(_selectedDate);
    if (_filterType == 'Month') return DateFormat('MMM yyyy').format(_selectedDate);
    if (_filterType == 'Day') return DateFormat('dd MMM yyyy').format(_selectedDate);
    return 'All Time';
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TrackerProvider>(context);
    final currencyFormat = NumberFormat('#,###');

    // 1. Data များကို Label နှင့် အချိန်အလိုက် စစ်ထုတ်ခြင်း (Filtering Logic)
    final filteredList = p.transactions.where((tx) {
      // Label Filter
      final cat = p.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => AppCategory(name: 'Unknown', iconData: 0, type: 'Expense'));
      bool labelOk = (_selectedLabel == 'All') || (cat.name == _selectedLabel);

      // Time Filter
      DateTime d = DateTime.parse(tx.dateTimestamp);
      bool timeOk = true;
      if (_filterType == 'Year') {
        timeOk = (d.year == _selectedDate.year);
      } else if (_filterType == 'Month') {
        timeOk = (d.year == _selectedDate.year && d.month == _selectedDate.month);
      } else if (_filterType == 'Day') {
        timeOk = (d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day);
      }

      return labelOk && timeOk;
    }).toList();

    // 2. စစ်ထုတ်ထားသော Data များ၏ စုစုပေါင်းပမာဏကို တွက်ခြင်း
    double totalAmount = filteredList.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger (မှတ်တမ်းများ)', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Bar Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.white,
            child: Row(
              children: [
                // Label Dropdown
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
                // Time Filter Button
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

          // Total Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: Colors.blueAccent.withOpacity(0.05),
            child: Column(
              children: [
                Text('Total Amount (${_timeFilterText})', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 5),
                Text(
                  '${p.formatLakh(totalAmount)} Ks', 
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent)
                ),
              ],
            ),
          ),

          // Transaction List
          Expanded(
            child: filteredList.isEmpty 
              ? const Center(child: Text('No records found (မှတ်တမ်းမရှိပါ)', style: TextStyle(color: Colors.grey))) 
              : ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final tx = filteredList[index];
                bool isExp = ['Expense', 'HomeTransfer', 'BankDeposit', 'HusbandDeposit'].contains(tx.type);
                final cat = p.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => AppCategory(name: 'Unknown', iconData: 0xe000, type: 'Expense'));

                return SwipeToDeleteLedgerItem(
                  onDelete: () {
                    p.deleteTransaction(tx.id!); // ဖျက်မည် (သက်ဆိုင်ရာ ငွေများ ပြန်ပေါင်းမည်)
                    
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Record deleted'),
                        duration: const Duration(seconds: 3), // SnackBar issue is paused, standard wait applied
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'UNDO', 
                          textColor: Colors.blueAccent, 
                          onPressed: () => p.undoDelete(tx) // Redo လုပ်မည်
                        ),
                      )
                    );
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isExp ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), 
                      child: Icon(IconData(cat.iconData, fontFamily: 'MaterialIcons'), color: isExp ? Colors.redAccent : Colors.green)
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${DateFormat('dd MMM yyyy').format(DateTime.parse(tx.dateTimestamp))} • ${tx.note}'),
                    trailing: Text('${isExp ? '-' : '+'}${currencyFormat.format(tx.amount)}', style: TextStyle(color: isExp ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
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
