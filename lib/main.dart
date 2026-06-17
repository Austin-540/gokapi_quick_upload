import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mime/mime.dart';

void main() => runApp(MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription _intentSub;
  SharedMediaFile? _sharedFile;

  @override
  void initState() {
    super.initState();

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      setState(() {
        _sharedFile = value.last;
      });
    }, onError: (err) {});

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        setState(() {
        _sharedFile = value.last;

        ReceiveSharingIntent.instance.reset();
          });
  }
  });
      

      

    getSetupData();
    }

  String? apiKey;
  String? gokapiUrl;
  Future? fileUploadStatus;

  Future getSetupData() async {
    FlutterSecureStorage storage = FlutterSecureStorage();
    apiKey = await storage.read(key: "api_key");
    gokapiUrl = await storage.read(key: "url");
    setState(() {
      apiKey = apiKey;
      gokapiUrl = gokapiUrl;
    });
    if (apiKey == null || gokapiUrl == null) {
      if (!mounted) return;
      return;
    }

    if (_sharedFile == null) {
      fileUploadStatus = Future.value("");
      return "empty";
      
    }
    fileUploadStatus = uploadFiles([File(_sharedFile!.path)]);
  }

  void editSavedData(String key) {
    String? newValue;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                autocorrect: false,
                decoration: InputDecoration(
                  hint: Text("Your $key goes here..."),
                ),
                onChanged: (value) => newValue = value,
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (key == "url") {
                  setState(() {
                    gokapiUrl = newValue;
                  });
                } else if (key == "api_key") {
                  setState(() {
                    apiKey = newValue;
                  });
                }
                FlutterSecureStorage storage = FlutterSecureStorage();
                await storage.write(key: key, value: newValue);

                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Text("Update $key"),
            ),
          ],
        ),
      ),
    );
  }

  Future uploadFiles(List<File> l) async {
    if (l.isEmpty) return "No file selected...";

    String? respBody;
    for (var file in l) {
      final uri = Uri.parse('$gokapiUrl/api/files/add');
      final request = http.MultipartRequest('POST', uri);

      final stream = http.ByteStream(file.openRead());
      final length = await file.length();
      final multipartFile = http.MultipartFile(
        'file', // field name
        stream,
        length,
        filename: file.path.split('/').last,
        contentType: MediaType.parse(lookupMimeType(file.path)!),
      );
      request.files.add(multipartFile);

      request.fields['allowedDownloads'] = "0";
      request.fields['expiryDays'] = "0";
      request.headers['apikey'] = apiKey!; //This function will run after the check

      final response = await request.send();
      respBody = await response.stream.bytesToString();
    }

    try {
      var shareResult = await SharePlus.instance.share(
        ShareParams(
          uri: Uri.parse(jsonDecode(respBody!)["FileInfo"]["UrlHotlink"]),
        ),
      );

      if (shareResult.status == ShareResultStatus.success) {
        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      }


    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Something went wrong :/"),
          content: Text(e.toString()),
        ),
      );
    }

    return respBody; //always returns the final file...
  }

  void selectNewFile() async {
    FilePickerResult? result = await FilePicker.pickFiles();

    if (result != null) {
      File newFile = File(result.files.single.path!);
      setState(() {
        fileUploadStatus = uploadFiles([newFile]);
      });
    } else {
      return;
    }
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gokapi Quick Upload')),
      body: Center(
        child: Column(
          children: <Widget>[
            ElevatedButton(
              onPressed: () => editSavedData("url"),
              child: Text("Gokapi URL: ${gokapiUrl.toString()}"),
            ),
            ElevatedButton(
              onPressed: () => editSavedData("api_key"),
              child: Text("API Key: ${apiKey.toString()}"),
            ),
            FutureBuilder(future: fileUploadStatus, builder: fileUploadBuilder),
          ],
        ),
      ),
    );
  }

  Widget fileUploadBuilder(BuildContext context, AsyncSnapshot snapshot) {
    if (snapshot.hasData) {
      return Column(
        children: [
          Text(snapshot.data.toString()),
          OutlinedButton(
            onPressed: () => selectNewFile(),
            child: Text("Select a file"),
          ),
        ],
      );
    } else if (snapshot.hasError) {
      return Text(snapshot.error.toString());
    } else {
      return CircularProgressIndicator();
    }
  }
}
