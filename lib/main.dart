import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "a.env");
  } catch (e) {
    debugPrint("Error loading .env file: $e");
  }
  runApp(const FoodScannerApp());
}

class FoodScannerApp extends StatelessWidget {
  const FoodScannerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        fontFamily: 'Gladolia',
      ),
      home: const MainAnimationWrapper(),
    );
  }
}

class MainAnimationWrapper extends StatefulWidget {
  const MainAnimationWrapper({super.key});
  @override
  State<MainAnimationWrapper> createState() => _MainAnimationWrapperState();
}

class _MainAnimationWrapperState extends State<MainAnimationWrapper> {
  bool _isAppLoaded = false;
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset("assets/videos/intro.mp4")
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.play();
        _videoController.setVolume(0);
        setState(() {});
      });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _isAppLoaded = true);
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_videoController.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),
          Positioned.fill(
            child: Opacity(
              opacity: _isAppLoaded ? 1.0 : 0.0,
              child: FoodScannerHome(showUI: _isAppLoaded),
            ),
          ),
          // Morphing Search Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOutQuart,
            top: _isAppLoaded ? 60 : 0,
            left: _isAppLoaded ? 25 : 0,
            right: _isAppLoaded ? 25 : 0,
            height: _isAppLoaded ? 65 : screenHeight,
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOutQuart,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(_isAppLoaded ? 20 : 0),
                    ),
                    child: _isAppLoaded ? const SearchBarContent() : const SizedBox.shrink(),
                  ),
                ),
                if (_isAppLoaded)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(Icons.menu_rounded, color: Colors.orange, size: 30),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FoodScannerHome extends StatefulWidget {
  final bool showUI;
  const FoodScannerHome({super.key, required this.showUI});
  @override
  State<FoodScannerHome> createState() => _FoodScannerHomeState();
}

class _FoodScannerHomeState extends State<FoodScannerHome> {
  File? _activeImage;
  String _result = "";
  bool _isLoading = false;
  int _currentStoryPage = 0;
  final PageController _pageController = PageController();
  final List<String> _storyTitles = ["The Reveal", "Ingredients", "Steps", "Health"];

  // Voice States
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  double _soundLevel = 0.0;

  // --- IMAGE & AI LOGIC (SYNCED) ---
  Future<void> _processImage(ImageSource source) async {
    final XFile? pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _activeImage = File(pickedFile.path);
      _isLoading = true;
      _result = "";
      _currentStoryPage = 0;
    });

    await _identifyFood();
  }

  Future<void> _identifyFood() async {
    if (_activeImage == null) return;
    if (!_isLoading) setState(() => _isLoading = true);

    try {
      String apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final imageBytes = await _activeImage!.readAsBytes();
      
      final prompt = TextPart(
          "Identify food. Split into 4 sections with '---': 1. Food Name only, 2. Comma-separated list of ingredients (no headers), 3. Numbered recipe steps, 4. Nutrition info.");

      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', imageBytes)])
      ]);

      setState(() {
        _result = response.text ?? "Error identifying food";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = "Connection Error. Please check API key.";
        _isLoading = false;
      });
    }
  }

  // --- VOICE NAVIGATION LOGIC ---
  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            String command = val.recognizedWords.toLowerCase();
            if (command.contains("camera")) _processImage(ImageSource.camera);
            if (command.contains("gallery")) _processImage(ImageSource.gallery);
            if (command.contains("analyze") || command.contains("scan")) _identifyFood();
          },
          onSoundLevelChange: (level) => setState(() => _soundLevel = level),
        );
      }
    } else {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasData = _result.isNotEmpty || _isLoading;
    return Stack(
      children: [
        // Background Blur
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            color: hasData ? Colors.black.withOpacity(0.5) : Colors.transparent,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: hasData ? 15 : 0, sigmaY: hasData ? 15 : 0),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),

        if (hasData)
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 140),
                _buildStoryProgress(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentStoryPage = i),
                    itemCount: 4,
                    itemBuilder: (context, index) => _buildStoryCard(index),
                  ),
                ),
              ],
            ),
          ),

        if (hasData && !_isLoading)
          Positioned(
            top: 140, right: 30,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => setState(() => _result = ""),
            ),
          ),

        // Bottom Nav with Pulse Mic
        AnimatedPositioned(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutBack,
          bottom: (widget.showUI && !hasData) ? 0 : -200,
          left: 0, right: 0,
          child: _buildAirPodsNavBar(),
        ),
      ],
    );
  }

  Widget _buildStoryCard(int index) {
    List<String> parts = _result.split('---');
    String content = _isLoading ? "Chef Gemini is cooking..." : (parts.length > index ? parts[index].trim() : "Data error");

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(35)),
      child: index == 0 ? _buildRevealCard(content) : index == 1 ? _buildIngredientGrid(content) : index == 2 ? _buildStepList(content) : _buildSimpleCard("Health", content),
    );
  }

  Widget _buildRevealCard(String name) {
    String cleanName = name.replaceAll(RegExp(r'^\d+\.\s*Name:?\s*', caseSensitive: false), '');
    return Column(children: [
      Expanded(flex: 3, child: Container(margin: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(25)), child: ClipRRect(borderRadius: BorderRadius.circular(25), child: _activeImage != null ? Image.file(_activeImage!, fit: BoxFit.cover) : const Icon(Icons.fastfood, size: 50, color: Colors.orange)))),
      Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(cleanName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)))),
    ]);
  }

  Widget _buildIngredientGrid(String raw) {
    List<String> list = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return Column(children: [
      const Padding(padding: EdgeInsets.all(20), child: Text("Ingredients", style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold))),
      Expanded(child: SingleChildScrollView(child: Wrap(spacing: 10, runSpacing: 10, children: list.map((i) => Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: Colors.orange[50], border: Border.all(color: Colors.orangeAccent), borderRadius: BorderRadius.circular(15)), child: Text(i, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)))).toList()))),
      Padding(padding: const EdgeInsets.all(20), child: Text("Total: ${list.length}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange))),
    ]);
  }

  Widget _buildStepList(String raw) {
    List<String> steps = raw.split(RegExp(r'\d+[\.\)]\s+')).where((s) => s.trim().isNotEmpty).toList();
    return Column(children: [
      const Padding(padding: EdgeInsets.all(20), child: Text("Recipe Steps", style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold))),
      Expanded(child: ListView.builder(itemCount: steps.length, itemBuilder: (context, i) => Container(margin: const EdgeInsets.fromLTRB(20, 0, 20, 15), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("STEP ${i + 1}", style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(steps[i].trim(), style: const TextStyle(fontSize: 16))])))),
    ]);
  }

  Widget _buildSimpleCard(String title, String content) => Column(children: [Padding(padding: const EdgeInsets.all(20), child: Text(title, style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold))), Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 25), child: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 18))))), const SizedBox(height: 20)]);

  Widget _buildStoryProgress() => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(children: List.generate(4, (i) => Expanded(child: Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: _currentStoryPage >= i ? Colors.orange : Colors.white24, borderRadius: BorderRadius.circular(10)))))));

  Widget _buildAirPodsNavBar() => Container(
    height: 160, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _buildBtn(Icons.camera_alt, "Camera", () => _processImage(ImageSource.camera)),
      _buildPulseMic(),
      _buildBtn(Icons.photo_library, "Gallery", () => _processImage(ImageSource.gallery)),
    ]),
  );

  Widget _buildPulseMic() => GestureDetector(
    onTap: _toggleListening,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(alignment: Alignment.center, children: [
        if (_isListening) ...[
          _ripple(1.2 + (_soundLevel * 0.1), 0.3),
          _ripple(1.5 + (_soundLevel * 0.2), 0.15),
        ],
        Container(height: 70, width: 70, decoration: BoxDecoration(color: _isListening ? Colors.orange : Colors.orange[50], shape: BoxShape.circle), child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.white : Colors.orange, size: 30)),
      ]),
      const SizedBox(height: 5),
      Text(_isListening ? "Listening..." : "Voice", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _ripple(double s, double o) => AnimatedScale(scale: s, duration: const Duration(milliseconds: 100), child: Container(height: 70, width: 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orange.withOpacity(o), width: 3))));

  Widget _buildBtn(IconData i, String l, VoidCallback t) => InkWell(onTap: t, child: Column(mainAxisSize: MainAxisSize.min, children: [Container(height: 60, width: 60, decoration: BoxDecoration(color: Colors.orange[50], shape: BoxShape.circle), child: Icon(i, color: Colors.orange)), const SizedBox(height: 8), Text(l, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]));
}

class SearchBarContent extends StatelessWidget {
  const SearchBarContent({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Icon(Icons.search, color: Colors.white), SizedBox(width: 15), Text("Search recipes...", style: TextStyle(color: Colors.white, fontSize: 16))]));
  }
}