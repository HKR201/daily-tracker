import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:sqflite_sqlcipher/sqflite.dart'; // 🌟 FIX: SQLCipher အသစ်ကို လှမ်းခေါ်ထားသည်
import '../database/db_helper.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  final _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      var account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) return null;
      final headers = await account.authHeaders;
      return drive.DriveApi(GoogleAuthClient(headers));
    } catch (e) {
      return null;
    }
  }

  Future<void> backupDatabase() async {
    final api = await _getDriveApi();
    if (api == null) return;
    
    // 🌟 WAL ကို Checkpoint ချပြီး DB ထဲ အကုန်ဝင်အောင် အရင်လုပ်မည်
    final db = await DatabaseHelper.instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');

    final dbPath = await getDatabasesPath();
    final file = File(path.join(dbPath, 'tracker.db'));
    if (!file.existsSync()) return;

    final fileList = await api.files.list(q: "name = 'daily_tracker_backup.db'");
    String? fileId;
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      fileId = fileList.files!.first.id;
    }

    final driveFile = drive.File()..name = 'daily_tracker_backup.db';
    final media = drive.Media(file.openRead(), file.lengthSync());

    if (fileId != null) {
      await api.files.update(driveFile, fileId, uploadMedia: media);
    } else {
      await api.files.create(driveFile, uploadMedia: media);
    }
  }

  Future<void> restoreDatabase() async {
    final api = await _getDriveApi();
    if (api == null) return;

    final fileList = await api.files.list(q: "name = 'daily_tracker_backup.db'");
    if (fileList.files == null || fileList.files!.isEmpty) return;

    final fileId = fileList.files!.first.id!;
    final drive.Media media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

    final dbPath = await getDatabasesPath();
    final file = File(path.join(dbPath, 'tracker.db'));
    
    final List<int> dataStore = [];
    await for (var data in media.stream) { dataStore.addAll(data); }
    file.writeAsBytesSync(dataStore); 
  }

  Future<bool> resetCloudBackup() async {
    try {
      if (_googleSignIn.currentUser != null) await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) return false; 
      final api = drive.DriveApi(GoogleAuthClient(await account.authHeaders));

      final fileList = await api.files.list(q: "name = 'daily_tracker_backup.db'");
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        for (var file in fileList.files!) await api.files.delete(file.id!);
      }
      await _googleSignIn.signOut();
      return true; 
    } catch (e) {
      return false; 
    }
  }
}
