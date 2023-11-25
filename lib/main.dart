import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Creator',
      home: VideoCreatorPage(),
    );
  }
}

class VideoCreatorPage extends StatefulWidget {
  @override
  _VideoCreatorPageState createState() => _VideoCreatorPageState();
}

class _VideoCreatorPageState extends State<VideoCreatorPage> {
  Uint8List? _imageByteData;
  Uint8List? _audioByteData;
  Uint8List? _videoByteData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Video')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
            onPressed: () async {
              final image = await _pickImage();
                if (image != null) {
                  setState(() => _imageByteData = image);
                }
              },
              child: Text('Select Image'),
            ),
            ElevatedButton(
              onPressed: () async {
                final audio = await _pickAudio();
                if (audio != null) {
                  setState(() => _audioByteData = audio);
                }
              },
              child: Text('Select Audio'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_imageByteData != null && _audioByteData != null) {
                  final video = await _createVideo(_imageByteData!, _audioByteData!);
                  if ( video != null) {
                    setState(() => _videoByteData = video);
                  }
                }
              },
              child: Text('Create Video'),
            ),
            if (_videoByteData != null) ...[
                Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Video created! ByteData Size: ${_videoByteData!.length}'),
                )
            ],
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path!);
      final image = file.readAsBytes();
      return image;
    } else {
      print (" pickedFile is null");
    }
  }

  Future<Uint8List?> _pickAudio() async {
    // ストレージ権限を要求
    bool hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      print('Storage permission is denied');
      return null;  // 権限がない場合はnullを返す
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final audio = file.readAsBytes();
      return audio;// ByteDataを返す
    }
    return null;  // ファイルが選択されなかった場合はnullを返す
  }

  Future<bool> requestStoragePermission() async {
    var status = await Permission.storage.status;
    print(status);
    if (status.isDenied) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  Future<Uint8List?> _createVideo(Uint8List imageByteData, Uint8List audioByteData) async {
    // 一時ディレクトリの取得
    final tempDir = await getTemporaryDirectory();
    final imagePath = '${tempDir.path}/image.jpg';
    final audioPath = '${tempDir.path}/audio.mp3';
    final outputPath = '${tempDir.path}/output.mp4';

    // ByteDataをファイルに書き込む
    await File(imagePath).writeAsBytes(imageByteData);
    await File(audioPath).writeAsBytes(audioByteData);

    // FFmpegを使用して動画を生成
    final result = await FFmpegKit.execute('-loop 1 -i $imagePath -i $audioPath -c:v libx264 -tune stillimage -c:a copy -shortest -pix_fmt yuv420p $outputPath');

    if (result.getReturnCode() == 0) {
      // 動画ファイルの読み込み
      final videoFile = File(outputPath);
      print("Video created successfully");
      return videoFile.readAsBytes();
    } else {
      print('Video creation failed');
      return null;
    }
  }
}
