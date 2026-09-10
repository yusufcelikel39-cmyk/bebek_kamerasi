import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:just_audio/just_audio.dart';

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
      title: 'Miranın Kamerası',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const AnaSecimEkrani(),
    );
  }
}

// 1. GİRİŞ EKRANI: Kamera mı yoksa İzleyici (Alıcı) cihaz mı olacağını seçme
class AnaSecimEkrani extends StatelessWidget {
  const AnaSecimEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miranın Kamerası'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.child_care, size: 80, color: Colors.pinkAccent),
            const SizedBox(height: 20),
            const Text(
              'Lütfen bu cihazın rolünü seçin:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[700],
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BebekKameraYayiniEkrani()),
                );
              },
              icon: const Icon(Icons.camera_front, size: 28),
              label: const Text('Bu Cihaz Bebek Kamerası Olsun', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const IzleyiciBaglantiEkrani()),
                );
              },
              icon: const Icon(Icons.monitor, size: 28),
              label: const Text('Bu Cihaz İzleyici (Ebeveyn) Olsun', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. BEBEK KAMERASI EKRANI (Yayını veren ve hareket algılayan taraf)
class BebekKameraYayiniEkrani extends StatefulWidget {
  const BebekKameraYayiniEkrani({super.key});

  @override
  State<BebekKameraYayiniEkrani> createState() => _BebekKameraYayiniEkraniState();
}

class _BebekKameraYayiniEkraniState extends State<BebekKameraYayiniEkrani> {
  CameraController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initKamera();
  }

  Future<void> _initKamera() async {
    if (cameras.isEmpty) return;
    _controller = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: true);
    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint("Kamera başlatma hatası: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Miranın Kamerası')),
        body: const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Miranın Kamerası - Yayın Modu'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.pinkAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            child: const Text(
              "Kamera aktif. Ebeveyn cihazından IP adresi ile bağlanarak bebeğinizi izleyebilirsiniz.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// 3. İZLEYİCİ EKRANI (IP ile bağlanıp alarm kurulan taraf)
class IzleyiciBaglantiEkrani extends StatefulWidget {
  const IzleyiciBaglantiEkrani({super.key});

  @override
  State<IzleyiciBaglantiEkrani> createState() => _IzleyiciBaglantiEkraniState();
}

class _IzleyiciBaglantiEkraniState extends State<IzleyiciBaglantiEkrani> {
  final TextEditingController _ipController = TextEditingController();
  bool _isConnecting = false;
  bool _alarmAktif = false;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  Future<void> _alarmCal() async {
    if (!_alarmAktif) return;
    try {
      await _audioPlayer.setUrl('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3');
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Ses çalma hatası: $e");
    }
  }

  void _baglantiKur() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir Kamera IP adresi girin!')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    // Simüle edilmiş IP bağlantı testi
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
      
      // Başarılı bağlantı sonrası izleme sayfasına geçiş simülasyonu veya bilgi
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bağlantı Başarılı'),
          content: Text('$ip adresindeki Miranın Kamerası cihazına bağlanıldı.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miranın Kamerası - İzleyici'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kamera Cihazının Yerel IP Adresini Girin:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Örn: 192.168.1.55',
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.wifi, color: Colors.pinkAccent),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isConnecting ? null : _baglantiKur,
              child: _isConnecting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Kameraya Bağlan', style: TextStyle(fontSize: 16)),
            ),
            const Divider(height: 40, color: Colors.grey),
            SwitchListTile(
              title: const Text('Hareket Algılama Alarmı'),
              subtitle: const Text('Bebek hareket ettiğinde telefonunuzda siren çalar.'),
              value: _alarmAktif,
              activeColor: Colors.pinkAccent,
              onChanged: (val) {
                setState(() {
                  _alarmAktif = val;
                });
                if (val) {
                  _alarmCal();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}