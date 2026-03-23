import 'package:sqflite_sqlcipher/sqflite.dart'; // 🌟 FIX: SQLCipher အသစ်ကို လှမ်းခေါ်ထားသည်
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Database ကို Password ခံ၍ လုံခြုံစွာ ဖွင့်မည်
    return await openDatabase(
      path,
      version: 1,
      password: 'Tkr_Secure_Hash_Key_2026!@#', // Encrypted Key
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        last_updated TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_data INTEGER NOT NULL,
        type TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        source_wallet_id INTEGER NOT NULL,
        destination_wallet_id INTEGER,
        category_id INTEGER NOT NULL,
        note TEXT,
        date_timestamp TEXT NOT NULL
      )
    ''');
  }
}
