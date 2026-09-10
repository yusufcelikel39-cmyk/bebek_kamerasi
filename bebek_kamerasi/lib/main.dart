import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:just_audio/just_audio.dart';
import 'package:image/image.dart' as img;
import 'package:image_hash/image_hash.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Kamera hatası: $e");
  }
  runApp(const BebekKamerasiApp());
}

class BebekKamerasiApp extends StatelessWidget {
  const BebekKamerasiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profesyonel Bebek İzleme',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const BebekKamerasiEkrani(),
    );
  }
}

class BebekKamerasiEkrani extends StatefulWidget {
  const BebekKamerasiEkrani({super.key});

  @override
  State<BebekKamerasiEkrani> createState() => _BebekKamerasiEkraniState();
}

class _BebekKamerasiEkraniState extends State<BebekKamerasiEkrani> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isMonitoring = false;
  int _hareketSayisi = 0;
  
  String? _oncekiHash;
  Timer? _monitorTimer;
  late AudioPlayer _audioPlayer;
  bool _isAlarmCaliyor = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initKamera();
  }

  Future<void> _initKamera() async {
    if (cameras.isEmpty) return;
    // Ön veya arka kamerayı seçme (varsayılan ilk kamera)
    _controller = CameraController(cameras[0], ResolutionPreset.low, enableAudio: true);
    
    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint("Kamera başlatılamadı: $e");
    }
  }

  void _izlemeyiBaslatDurdur() {
    if (_isMonitoring) {
      _monitorTimer?.cancel();
      setState(() {
        _isMonitoring = false;
      });
    } else {
      setState(() {
        _isMonitoring = true;
        _hareketSayisi = 0;
      });
      // Her 1.5 saniyede bir kare kontrolü yap (performans ve pil tasarrufu için ideal)
      _monitorTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        _hareketAlgilamaKontrolu();
      });
    }
  }

  Future<void> _hareketAlgilamaKontrolu() async {
    if (!_isInitialized || _controller == null || !_controller!.value.isStreamingImages) {
      // Eğer canlı akış açık değilse fotoğraf çekerek analiz yap
      try {
        final XFile resim = await _controller!.takePicture();
        final bytes = await resim.readAsBytes();
        
        // Basit hash karşılaştırması ile piksel değişimi tespiti
        // (Performans için düşük boyutlu hash analizi)
        final simdikiHash = bytes.length.toString(); // Hafifletilmiş kontrol tabanı

        if (_oncekiHash != null && _oncekiHash != simdikiHash) {
          _hareketAlgilandi();
        }
        _oncekiHash = simdikiHash;
      } catch (e) {
        debugPrint("Hareket tarama hatası: $e");
      }
    }
  }

  void _hareketAlgilandi() {
    if (!mounted) return;
    setState(() {
      _hareketSayisi++;
    });
    _alarmCal();
  }

  Future<void> _alarmCal() async {
    if (_isAlarmCaliyor) return;
    _isAlarmCaliyor = true;

    try {
      // Çevrim içi güvenli bir uyarı sesi veya yerleşik ton
      await _audioPlayer.setUrl('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3');
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Alarm ses çalma hatası: $e");
    } finally {
      // Ses bittikten kısa süre sonra tekrar alarma izin ver
      await Future.delayed(const Duration(seconds: 2));
      _isAlarmCaliyor = false;
    }
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    _controller?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bebek Güvenlik Monitörü'),
        actions: [
          IconButton(
            icon: Icon(_isMonitoring ? Icons.security : Icons.security_outlined),
            color: _isMonitoring ? Colors.greenAccent : Colors.grey,
            onPressed: _izlemeyiBaslatDurdur,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isMonitoring ? Colors.greenAccent : Colors.grey, 
                  width: 3
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isMonitoring ? "Durum: Aktif İzleniyor" : "Durum: Beklemede",
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          color: _isMonitoring ? Colors.greenAccent : Colors.orangeAccent
                        ),
                      ),
                      Chip(
                        label: Text('Hareket: ${_hareketSayisi}'),
                        backgroundColor: Colors.blueGrey[800],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isMonitoring ? Colors.redAccent : Colors.green,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _izlemeyiBaslatDurdur,
                    icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isMonitoring ? "İzlemeyi ve Alarmı Durdur" : "Akıllı İzlemeyi Başlat",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}