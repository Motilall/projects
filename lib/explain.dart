import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        primarySwatch: Colors.orange,  
        useMaterial3: true,    // google design system that defines how button, cards, colors, fonts will look    
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
  File? _image;       // 
  String _result = '';    // string -> the gemini will return in text formate, _result -> the private variavle that will store the texts and will show it in the string ''
  bool _loading = false;  
  
  final ImagePicker _picker = ImagePicker(); 
  // ImagePicker -> the class that contains the blueprint for opening gallery and selceting images (recipe)
  // ImagePicker -> this actually makes the real code from the blueprint (cooked food)
  // _picker -> the varialble to store the picked image
  Future<void> _pickImage(ImageSource source) async {
    // ImageSource source -> this is a parameter which will tell us where to pick the image from
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source); // -> wait for the user to pick am image from camera or gallery and store it in pickedFile
      if (pickedFile == null) return; // if user picked nothing and cancelled then stop everything and do nothing

      setState(() { // tells flutter that something has changed and rebuild the ui using the build() function
        _loading = true;       
        _image = File(pickedFile.path); // take the picked image's location, convert it to a file and store it so we can display it
        _result = '';              
      });
      await _identifyFood();

    } catch (e) { // if try fails come here, e ->  error message
      setState(() {
        _loading = false;
        _result = "Error opening camera: $e";
      });
    }
  }
  Future<void> _identifyFood() async {
    if (_image == null) return;

    try {
      final apiKey = 'AIzaSyCrftXxDrOo6GMliNsKkriEEu9VNBi613E'; 
      
      if (apiKey == 'YOUR_API_KEY_HERE') {
        setState(() {
          _result = "Error: Please paste your API Key in the code!";
          _loading = false;
        });
        return;
      }

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
      appBar: AppBar( // Add a top navigation bar to this screen.
      // appBar: → property of Scaffold that defines the top header area.
      // AppBar( → creating a Material Design top bar widget.
        title: const Text('Food Scanner AI'),// the text that will be displayed on the AppBar
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      
      body: SingleChildScrollView(  // if the content becomes bigger than the screen size then it is scrollable
        child: Column(// top to bottom arrangement
          children: [
            Container(// box widget (div container)
              width: double.infinity,// width wise take as much as space possible
              height: 300,
              color: Colors.grey[200],
              child: _image == null
                  ? const Column( // if the image is not selected yet then show this icon
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fastfood, size: 80, color: Colors.grey),
                        Text("Scan a meal to get a recipe!", style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : Image.file(_image!, fit: BoxFit.cover),// this tells that the image is selected and fill it with the selected image
                  // Image.file(...) → displays an image stored locally.
                  // _image! → the ! tells Dart “I’m sure this is not null.”
                  // fit: BoxFit.cover → makes the image fill the container completely, cropping if needed to maintain aspect ratio.
            ),

            Padding( // is a widget used to add empty space around another widget
              padding: const EdgeInsets.all(20.0), // adds 20 pixels of space on all four sides
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
                  : Text(         
                      _result,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),

          ],
        ),
      ),
    );
  }
}




//1. Is first letter Capital?  → Class/Object
//2. Is first letter small?    → Function or variable
//3. Is there () at end?       → Something is being called
//4. Is there ? after type?    → Can be null



// Complete journy in one picture. 
// User clicks button -> gallery open(XFile) -> XFile - File(display) -> bytes (for Gemini) -> bytes + prompt - Gemini API -> Gemini returns recipe text -> string _resut = recipe -> UI shows recipe on screen


// STEP BY STEP 

// step 1 -> user clicks buttons
// ElevatedButton.icon(
//   onPressed: () => _pickImage(ImageSource.gallery)
// )
// user clicks → _pickImage() function is called
// with ImageSource.gallery as source

// step 2 -> gallery opens, user picks image
//final XFile? pickedFile = await _picker.pickImage(source: source);
// gallery opens
// user picks photo
// stored as XFile in pickedFile
// format: XFile (raw from gallery)

// step 3 -> check if user cancelled
// if (pickedFile == null) return;
// if cancelled → stop everything
// if picked → continue ✅

// STEP 4 — Update UI, show spinner:
//setState(() {
//  _loading = true;                    // show spinner ⏳
//  _image = File(pickedFile.path);     // XFile → File (for display)
//  _result = '';                       // clear old result
//});
// UI rebuilds → shows image + spinner

//STEP 5 — Send to Gemini:
//await _identifyFood();
// _pickImage calls _identifyFood()
// passes _image to Gemini

// STEP 6 — Inside _identifyFood(), image is read:
//final imageBytes = await _image!.readAsBytes();
// File → converted to raw bytes
// format: bytes (1010101...) 
// because Gemini API needs raw bytes not File

//STEP 7 — Prepare and send to Gemini:
//final prompt = TextPart("Identify this food and give me a short recipe.");
//final imagePart = DataPart('image/jpeg', imageBytes);
//final response = await model.generateContent([
//  Content.multi([prompt, imagePart])
//]);
// sending both text prompt + image bytes to Gemini
// Gemini analyzes the image
// returns recipe as text