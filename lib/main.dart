import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() => runApp(MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription _intentSub;
  final _sharedFiles = <SharedMediaFile>[];

  @override
  void initState() {
    super.initState();

    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);

        print(_sharedFiles.map((f) => f.toMap()));
      });
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);
        print(_sharedFiles.map((f) => f.toMap()));

        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.instance.reset();
      });
    });

    getSetupData();
  }

  String? apiKey;
  String? gokapiUrl;
  Future getSetupData() async {
    FlutterSecureStorage storage = FlutterSecureStorage();
    apiKey = await storage.read(key: "api_key");
    gokapiUrl = await storage.read(key: "url");
    setState(() {apiKey=apiKey;gokapiUrl=gokapiUrl;});
    if (apiKey == null || gokapiUrl == null) {
      if (!mounted) return;
      print("Setup not completed!!! No API key or URL");
    }
  }

  void editSavedData(String key) {
    String? newValue;
    showDialog(context: context, builder: (context) => 
    Dialog(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(autocorrect: false, decoration: InputDecoration(hint: Text("Your $key goes here...")),
        onChanged: (value) => newValue = value,),
      ),
      ElevatedButton(onPressed: () async {
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
      }, child: Text("Update $key"))
    ],),
    ));
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyleBold = const TextStyle(fontWeight: FontWeight.bold);
    return Scaffold(
        appBar: AppBar(
          title: const Text('Gokapi Quick Upload'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              ElevatedButton(onPressed: () => editSavedData("url"), child: Text("Gokapi URL: ${gokapiUrl.toString()}")),
              ElevatedButton(onPressed: () => editSavedData("api_key"), child: Text("API Key: ${apiKey.toString()}")),
              Text("Shared files:", style: textStyleBold),
              Text(_sharedFiles
                      .map((f) => f.toMap())
                      .join(",\n****************\n")),
            ],
          ),
        ),
    );
  }
}