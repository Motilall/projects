import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Required to load assets before the app starts
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Make sure your file is named 'a.env' in your project root
    await dotenv.load(fileName: "a.env");
  } catch (e) {
    debugPrint("Error loading .env file: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const FoodScannerHome(),
    );
  }
}

class FoodScannerHome extends StatefulWidget {
  const FoodScannerHome({super.key});

  @override
  State<FoodScannerHome> createState() => _FoodScannerHomeState();
}

class _FoodScannerHomeState extends State<FoodScannerHome> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  File? _image;
  String _result = "Voice Assistant Ready! Tap the mic and say 'Open Camera'.";
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) => debugPrint('Speech Error: $val'),
        onStatus: (val) => debugPrint('Speech Status: $val'),
      );
      setState(() {});
    } catch (e) {
      setState(() => _result = "Speech Init Error: $e");
    }
  }

  void _startListening() async {
    // Note: removed 'options' parameter as it caused an error in your build
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          String words = result.recognizedWords.toLowerCase();
          _result = "I heard: $words";

          if (words.contains("open camera") || words.contains("scan")) {
            _stopListening();
            _pickImage(ImageSource.camera);
          }
        });
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 5),
    );
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _loading = true;
        _image = File(pickedFile.path);
        _result = '';
      });
      await _identifyFood();
    } catch (e) {
      setState(() {
        _loading = false;
        _result = "Error opening camera: $e";
      });
    }
  }

  Future<void> _identifyFood() async {
    if (_image == null) return;

    try {
      String apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

      if (apiKey.isEmpty) {
        setState(() {
          _result = "Error: API Key missing in a.env file!";
          _loading = false;
        });
        return;
      }

      // Fixed: Only declaring 'model' once to avoid the scope error
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final imageBytes = await _image!.readAsBytes();
      final prompt = TextPart("Identify this food and give me a short recipe.");
      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      setState(() {
        _result = response.text ?? "Could not identify food.";
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _result = "API Error: $e";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Scanner AI'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.grey[200],
              child: _image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fastfood, size: 80, color: Colors.grey),
                        Text("Scan a meal to get a recipe!",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : Image.file(_image!, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: _loading
                  ? const CircularProgressIndicator()
                  : SelectionArea(
                      child: Text(_result, style: const TextStyle(fontSize: 16)),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _speechToText.isNotListening ? _startListening : _stopListening,
        backgroundColor: Colors.orange,
        child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }
}