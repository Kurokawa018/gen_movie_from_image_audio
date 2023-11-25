import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _videoController;



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Video')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[

            // 音声ファイルの再生ボタン
            // if (_audioByteData != null)
            //   ElevatedButton(
            //     onPressed: _playAudio,
            //     child: Text('Play Audio'),
            //   ),
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
              ),
              // VideoPlayerウィジェット
              if (_videoController != null && _videoController!.value.isInitialized)
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
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
    try {
      // 一時ディレクトリの取得
      final tempDir = await getTemporaryDirectory();
      final imagePath = '${tempDir.path}/image.jpeg';
      final audioPath = '${tempDir.path}/audio.mp3';
      final outputPath = '${tempDir.path}/output.mp4';

      // ByteDataをファイルに書き込む
      await File(imagePath).writeAsBytes(imageByteData);
      await File(audioPath).writeAsBytes(audioByteData);

      // FFmpegを使用して動画を生成
      final session = await FFmpegKit.execute('-y -loop 1 -i $imagePath -i $audioPath -c:v mpeg4 -c:a copy -shortest -pix_fmt yuv420p $outputPath');

      final returnCode = await session.getReturnCode();
      final logs = await session.getLogs();
      print("==============");
      for (Log log in logs) {
        // 各ログオブジェクトからメッセージを抽出して出力
        print(log.getMessage());
      }
      print("==============");
      if (ReturnCode.isSuccess(returnCode)) {
        // 動画ファイルの読み込み
        final videoFile = File(outputPath);
        print("video createed success!!!!!!");
        await saveVideoToFile(videoFile);
        print("Saved File");
        final videoData = await videoFile.readAsBytes();
        await _loadAndPlayVideo(videoData);
        return videoData;
      } else {
        final log = await session.getAllLogsAsString();
        print("video created faied");
        return null;
      }
    } catch (e) {
      print('Error occurred during video creation: $e');
      return null;
    }
  }

  Future<void> _loadAndPlayVideo(Uint8List videoData) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempVideoFile = File('${tempDir.path}/tempVideo.mp4');
      await tempVideoFile.writeAsBytes(videoData);

      print("Load an play video" + tempVideoFile.toString());
      _videoController = VideoPlayerController.file(tempVideoFile)
        ..initialize().then((_) {
          setState(() {});
        }).catchError((e) {
          print("Video Playerの初期化中にエラーが発生しました: $e");
          // 必要に応じてユーザーにエラーメッセージを表示
        });
    } catch (e) {
      print("動画の読み込み中にエラーが発生しました: $e");
      // 必要に応じてユーザーにエラーメッセージを表示
    }
  }

  Future<void> saveVideoToFile(File videoFile) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final directory = await getExternalStorageDirectory(); // 外部ストレージディレクトリを取得
      final newPath = '${directory?.path}/Download'; // 新しいパスを設定

      await videoFile.copy(newPath); // ファイルを新しい場所にコピー
      print("動画が保存されました: $newPath");
    } else {
      print("ストレージへのアクセス許可が拒否されました");
    }
  }


}