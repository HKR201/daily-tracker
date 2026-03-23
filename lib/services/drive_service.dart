import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

// Google Drive API ဖြင့် ချိတ်ဆက်ရန်အတွက် Auth Client
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

  // Drive API အား ရယူခြင်း (Sign-In လုပ်ပြီးသား ရှိ/မရှိ စစ်ဆေးသည်)
  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      var account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn(); // မရှိသေးလျှင် Sign In လုပ်ခိုင်းမည်
      
      if (account == null) return null;
      
      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);
      return drive.DriveApi(client);
    } catch (e) {
      return null;
    }
  }

  // Backup တင်ခြင်း (Upload)
  Future<void> backupDatabase() async {
    final api = await _getDriveApi();
    if (api == null) return;
    
    final dbPath = await getDatabasesPath();
    final file = File(path.join(dbPath, 'tracker.db'));
    if (!file.existsSync()) return;

    // Google Drive တွင် Backup ဖိုင်အဟောင်း ရှိ/မရှိ ရှာဖွေခြင်း
    final fileList = await api.files.list(q: "name = 'daily_tracker_backup.db'");
    String? fileId;
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      fileId = fileList.files!.first.id;
    }

    final driveFile = drive.File()..name = 'daily_tracker_backup.db';
    final media = drive.Media(file.openRead(), file.lengthSync());

    if (fileId != null) {
      // အဟောင်းရှိလျှင် အပေါ်မှ ထပ်မံ အစားထိုးမည် (Update)
      await api.files.update(driveFile, fileId, uploadMedia: media);
    } else {
      // မရှိသေးလျှင် အသစ်ဖန်တီးမည် (Create)
      await api.files.create(driveFile, uploadMedia: media);
    }
  }

  // Restore ပြန်ယူခြင်း (Download)
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
    await for (var data in media.stream) {
      dataStore.addAll(data);
    }
    file.writeAsBytesSync(dataStore); // လက်ရှိဖုန်းထဲက Database ပေါ်သို့ အစားထိုးထည့်သွင်းမည်
  }

  // 🌟 အသစ်ထည့်သွင်းထားသော Reset Backup စနစ် (Force Re-Authentication)
  Future<bool> resetCloudBackup() async {
    try {
      // ၁။ လက်ရှိ ဝင်ထားသည့် အကောင့်ရှိလျှင် အတင်း Sign Out (ထွက်) ခိုင်းမည်
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.signOut();
      }
      
      // ၂။ အကောင့်ပြန်ရွေးခိုင်းမည် (လုံခြုံရေးအတွက် Password ပြန်တောင်းသကဲ့သို့ လုပ်ဆောင်သည်)
      final account = await _googleSignIn.signIn();
      if (account == null) return false; // User က ပြန်မဝင်ဘဲ Cancel လုပ်သွားလျှင် ရပ်မည်

      final headers = await account.authHeaders;
      final client = GoogleAuthClient(headers);
      final api = drive.DriveApi(client);

      // ၃။ Drive ထဲမှ Backup ဖိုင်ကို ရှာဖွေပြီး အပြီးတိုင် ဖျက်ပစ်မည်
      final fileList = await api.files.list(q: "name = 'daily_tracker_backup.db'");
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        for (var file in fileList.files!) {
          await api.files.delete(file.id!);
        }
      }
      
      // ဖျက်ပြီးနောက် လုံခြုံရေးအတွက် အကောင့်ကိုပါ ပြန်ထွက်ပေးထားမည်
      await _googleSignIn.signOut();
      return true; // အောင်မြင်စွာ ဖျက်သိမ်းပြီးကြောင်း ပြန်ပို့မည်
      
    } catch (e) {
      return false; // Error တက်လျှင် False ပြန်ပို့မည်
    }
  }
}
