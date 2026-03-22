import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);

  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null;
      final headers = await account.authHeaders;
      return drive.DriveApi(GoogleAuthClient(headers));
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  Future<bool> backupDatabase() async {
    try {
      final api = await _getDriveApi();
      if (api == null) return false;
      final file = File(p.join(await getDatabasesPath(), 'daily_tracker.db'));
      if (!file.existsSync()) return false;

      final fileList = await api.files.list(spaces: 'appDataFolder', q: "name='daily_tracker_backup.db'");
      String? existingId = (fileList.files?.isNotEmpty ?? false) ? fileList.files!.first.id : null;

      final driveFile = drive.File()..name = 'daily_tracker_backup.db';
      final media = drive.Media(file.openRead(), file.lengthSync());

      if (existingId != null) {
        await api.files.update(driveFile, existingId, uploadMedia: media);
      } else {
        driveFile.parents = ['appDataFolder'];
        await api.files.create(driveFile, uploadMedia: media);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> restoreDatabase() async {
    try {
      final api = await _getDriveApi();
      if (api == null) return false;
      final fileList = await api.files.list(spaces: 'appDataFolder', q: "name='daily_tracker_backup.db'");
      if (fileList.files == null || fileList.files!.isEmpty) return false;

      final drive.Media fileMedia = await api.files.get(fileList.files!.first.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final file = File(p.join(await getDatabasesPath(), 'daily_tracker.db'));
      
      final List<int> dataStore = [];
      await for (final data in fileMedia.stream) { dataStore.addAll(data); }
      await file.writeAsBytes(dataStore);
      return true;
    } catch (e) {
      return false;
    }
  }
}
