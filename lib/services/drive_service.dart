import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

// Google က ပေးလိုက်တဲ့ ခွင့်ပြုချက် (Headers) တွေကို ချိတ်ဆက်ပေးမယ့် ကြားခံစနစ်
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
  // Google Drive ရဲ့ လျှို့ဝှက်ခန်း (appDataFolder) ကိုပဲ သုံးခွင့်တောင်းပါမယ်
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  // Login ဝင်ပြီး Drive နဲ့ ချိတ်ဆက်ပါမယ်
  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null; // Login မဝင်ရင် ရပ်မယ်

      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);
      return drive.DriveApi(client);
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  // Database ကို Drive ပေါ် အရန်သိမ်းမယ့် (Backup) Function
  Future<bool> backupDatabase() async {
    try {
      final api = await _getDriveApi();
      if (api == null) return false;

      // ဖုန်းထဲက Database ဖိုင်ကို ရှာပါမယ်
      final dbPath = p.join(await getDatabasesPath(), 'daily_tracker.db');
      final file = File(dbPath);
      if (!file.existsSync()) return false;

      // Drive ပေါ်မှာ အရင်သိမ်းထားတဲ့ ဖိုင်ဟောင်း ရှိ/မရှိ စစ်ပါမယ်
      final fileList = await api.files.list(
        spaces: 'appDataFolder',
        q: "name='daily_tracker_backup.db'",
      );

      String? existingFileId;
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        existingFileId = fileList.files!.first.id;
      }

      // ဖိုင်အသစ်ကို Drive ပေါ် တင်ပါမယ်
      final driveFile = drive.File()..name = 'daily_tracker_backup.db';
      final media = drive.Media(file.openRead(), file.lengthSync());

      if (existingFileId != null) {
        // အဟောင်းရှိရင် အဟောင်းပေါ်ကို ထပ်ပိုးသိမ်းမယ် (Update)
        await api.files.update(driveFile, existingFileId, uploadMedia: media);
      } else {
        // အဟောင်းမရှိရင် အသစ်တည်ဆောက်မယ်
        driveFile.parents = ['appDataFolder'];
        await api.files.create(driveFile, uploadMedia: media);
      }
      return true;
    } catch (e) {
      print("Backup Error: $e");
      return false;
    }
  }

  // Drive ပေါ်ကနေ ဖုန်းထဲကို ပြန်ယူမယ့် (Restore) Function
  Future<bool> restoreDatabase() async {
    try {
      final api = await _getDriveApi();
      if (api == null) return false;

      final fileList = await api.files.list(
        spaces: 'appDataFolder',
        q: "name='daily_tracker_backup.db'",
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return false; // Backup မရှိရင် ပြန်ဆုတ်မယ်
      }

      final String fileId = fileList.files!.first.id!;
      final drive.Media fileMedia = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      // ဖုန်းထဲက Database အဟောင်းနေရာမှာ အစားထိုးပါမယ်
      final dbPath = p.join(await getDatabasesPath(), 'daily_tracker.db');
      final file = File(dbPath);
      
      final List<int> dataStore = [];
      await for (final data in fileMedia.stream) {
        dataStore.addAll(data);
      }
      await file.writeAsBytes(dataStore);

      return true;
    } catch (e) {
      print("Restore Error: $e");
      return false;
    }
  }
}
