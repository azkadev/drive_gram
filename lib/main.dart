import 'dart:convert';
import 'dart:io';

import 'package:cool_alert/cool_alert.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:telegram_client/telegram_client.dart';
import 'package:http/http.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  await Hive.initFlutter();
  Box box = await Hive.openBox("drivegram");
  runApp(MyApp(
    box: box,
  ));
}

class MyApp extends StatelessWidget {
  final Box box;
  const MyApp({Key? key, required this.box}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drive Gram',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
        title: 'Drive Gram',
        box: box,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final Box box;
  const MyHomePage({Key? key, required this.title, required this.box}) : super(key: key);
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  TelegramBotApi tg = TelegramBotApi("0");

  int _total = 0, _received = 0;
  late StreamedResponse _response;
  File? _image;
  final List<int> _bytes = [];

  Future<void> downloadImage(String url) async {
    _response = await Client().send(Request('GET', Uri.parse(url)));
    _total = _response.contentLength ?? 0;

    _response.stream.listen((value) {
      setState(() {
        _bytes.addAll(value);
        _received += value.length;
      });
    }).onDone(() async {
      // final file = File('${(await getApplicationDocumentsDirectory()).path}/image.png');
      // await file.writeAsBytes(_bytes);
      // setState(() {
      //   _image = file;
      // });
    });
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box("drivegram").listenable(),
      builder: (ctx, box, widgetS) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
          ),
          body: listFiles(),
          floatingActionButton: FloatingActionButton.extended(
            label: Text('${_received ~/ 1024}/${_total ~/ 1024} KB'),
            icon: const Icon(Icons.file_upload),
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles();

              if (result != null) {
                var files = result.files.single;
                if (files.path != null) {
                  if (files.size >= 52428800) {
                    return CoolAlert.show(
                      context: context,
                      type: CoolAlertType.info,
                      text: "Failed\nFile Size: ${filesize(files.size)}\nTolong pilih file lain lagi ya pastikan kurang dari 50 Mb",
                    );
                  }
                  File file = File(files.path ?? "");

                  print(files.size);

                  var chat_id = 0;
                  var file_id = "BQACAgUAAxkDAAIFb2L2jK27NxA6c7EOWwjdQhiDNrkXAAKUBQACpRSxV_skyf6UQ_0XKQQ";
                  var send = await tg.requestForm("sendDocument", parameters: {
                    "chat_id": chat_id,
                    "document": tg.buffer(
                      file.readAsBytesSync(),
                      name: files.name,
                    ),
                  }, onUploadProgress: (bytes, total) {
                    print(bytes);
                    setState(() {
                      _received = bytes;
                      _total = total;
                    });
                  });
                  List filesData = widget.box.get("files", defaultValue: []);
                  for (var i = 0; i < filesData.length; i++) {
                    var loop_data = filesData[i];
                    if (loop_data is Map) {
                      if (loop_data["file_unique_id"] == send["result"]["document"]["file_unique_id"]) {
                        return CoolAlert.show(
                          context: context,
                          type: CoolAlertType.info,
                          text: "Failed\nFile sudah ada di database",
                        );
                      }
                    } else {
                      filesData.removeAt(i);
                    }
                  }
                  filesData.add(send["result"]["document"]);
                  await widget.box.put("files", filesData);
                  return await CoolAlert.show(
                    context: context,
                    type: CoolAlertType.success,
                    text: "Berhasil Menambahkan data",
                  );

                  // print(send);
                  // var getFile = await tg.request("getFile", parameters: {
                  //   "file_id": file_id,
                  // });
                  // var url = getFile["result"]["file_url"];
                  // print(getFile);
                  // tg.fileDownload('https://upload.wikimedia.org/wikipedia/commons/f/ff/Pizigani_1367_Chart_10MB.jpg', path: "./download.dart", onDownloadProgress: (bytes, total) {
                  //   setState(() {
                  //     _received = bytes;
                  //     _total = total;
                  //   });
                  // });
                }
              }
            },
            tooltip: 'Increment',
          ),
        ); // This trailing comma makes auto-formatting nicer for build methods.
      },
    );
  }

  Widget listFiles() {
    late List datas = [];
    try {
      datas = widget.box.get("files", defaultValue: []);
    } catch (e) {
      print(e);
    }
    return ListView.builder(
      itemCount: datas.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(15),
          child: FutureBuilder(
            future: tg.request("getFile", parameters: {"file_id": datas[index]["file_id"]}),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                if (snapshot.data != null) {
                  return ListTile(
                    onTap: () async {},
                    leading: FutureBuilder(
                      future: (datas[index]["thumb"] is Map) ? tg.request("getFile", parameters: {"file_id": datas[index]["thumb"]["file_id"]}) : null,
                      builder: (context, snapsho) {
                        if (snapsho.connectionState == ConnectionState.waiting) {
                          return Container(
                            height: 50,
                            width: 50,
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapsho.hasData) {
                          if (snapsho.data is Map) {
                            return Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(image: DecorationImage(image: Image.network((snapsho.data as Map)["result"]["file_url"]).image)),
                            );
                          }
                        }
                        return Container(
                          height: 50,
                          width: 50,
                          child: const Center(
                            child: const Icon(
                              Icons.file_copy,
                            ),
                          ),
                        );
                      },
                    ),
                    title: Text(datas[index]["file_name"]),
                    trailing: InkWell(
                      onTap: () async {
                        var file = File("./documents/${datas[index]["file_name"]}");
                        if (file.existsSync()) {
                          return await CoolAlert.show(
                            context: context,
                            type: CoolAlertType.info,
                            text: "File Sudah ada",
                          );
                        } else {
                          tg.fileDownload((snapshot.data as Map)["result"]["file_url"], path: "./documents/${datas[index]["file_name"]}", onDownloadProgress: (bytes, total) {});
                        }
                      },
                      child: const Icon(
                        Icons.download,
                      ),
                    ),
                  );
                }
              }
              return Container(
                child: Text(
                  json.encode(datas[index]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// A method returns a human readable string representing a file _size
String filesize(dynamic size, [int round = 2]) {
  /** 
   * [size] can be passed as number or as string
   *
   * the optional parameter [round] specifies the number 
   * of digits after comma/point (default is 2)
   */
  var divider = 1024;
  int _size;
  try {
    _size = int.parse(size.toString());
  } catch (e) {
    throw ArgumentError('Can not parse the size parameter: $e');
  }

  if (_size < divider) {
    return '$_size B';
  }

  if (_size < divider * divider && _size % divider == 0) {
    return '${(_size / divider).toStringAsFixed(0)} KB';
  }

  if (_size < divider * divider) {
    return '${(_size / divider).toStringAsFixed(round)} KB';
  }

  if (_size < divider * divider * divider && _size % divider == 0) {
    return '${(_size / (divider * divider)).toStringAsFixed(0)} MB';
  }

  if (_size < divider * divider * divider) {
    return '${(_size / divider / divider).toStringAsFixed(round)} MB';
  }

  if (_size < divider * divider * divider * divider && _size % divider == 0) {
    return '${(_size / (divider * divider * divider)).toStringAsFixed(0)} GB';
  }

  if (_size < divider * divider * divider * divider) {
    return '${(_size / divider / divider / divider).toStringAsFixed(round)} GB';
  }

  if (_size < divider * divider * divider * divider * divider && _size % divider == 0) {
    num r = _size / divider / divider / divider / divider;
    return '${r.toStringAsFixed(0)} TB';
  }

  if (_size < divider * divider * divider * divider * divider) {
    num r = _size / divider / divider / divider / divider;
    return '${r.toStringAsFixed(round)} TB';
  }

  if (_size < divider * divider * divider * divider * divider * divider && _size % divider == 0) {
    num r = _size / divider / divider / divider / divider / divider;
    return '${r.toStringAsFixed(0)} PB';
  } else {
    num r = _size / divider / divider / divider / divider / divider;
    return '${r.toStringAsFixed(round)} PB';
  }
}
