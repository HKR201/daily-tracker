class AppWallet {
  final int? id;
  final String name; // e.g., KBZ Pay, Cash
  final String type; // Balance, Bank, Person, Group
  final double amount;
  final String lastUpdated;

  AppWallet({this.id, required this.name, required this.type, required this.amount, required this.lastUpdated});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'amount': amount,
      'last_updated': lastUpdated,
    };
  }

  factory AppWallet.fromMap(Map<String, dynamic> map) {
    return AppWallet(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      amount: map['amount'],
      lastUpdated: map['last_updated'],
    );
  }
}

class AppCategory {
  final int? id;
  final String name;
  final int iconData; // Saved as integer
  final String type; // Expense, Income, Group

  AppCategory({this.id, required this.name, required this.iconData, required this.type});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_data': iconData,
      'type': type,
    };
  }

  factory AppCategory.fromMap(Map<String, dynamic> map) {
    return AppCategory(
      id: map['id'],
      name: map['name'],
      iconData: map['icon_data'],
      type: map['type'],
    );
  }
}

class AppTransaction {
  final int? id;
  final double amount;
  final String type; // E, In, G, P, B
  final int sourceWalletId;
  final int? destinationWalletId;
  final int? categoryId;
  final String note;
  final String dateTimestamp;

  AppTransaction({
    this.id,
    required this.amount,
    required this.type,
    required this.sourceWalletId,
    this.destinationWalletId,
    this.categoryId,
    required this.note,
    required this.dateTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'source_wallet_id': sourceWalletId,
      'destination_wallet_id': destinationWalletId,
      'category_id': categoryId,
      'note': note,
      'date_timestamp': dateTimestamp,
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    return AppTransaction(
      id: map['id'],
      amount: map['amount'],
      type: map['type'],
      sourceWalletId: map['source_wallet_id'],
      destinationWalletId: map['destination_wallet_id'],
      categoryId: map['category_id'],
      note: map['note'],
      dateTimestamp: map['date_timestamp'],
    );
  }
}
