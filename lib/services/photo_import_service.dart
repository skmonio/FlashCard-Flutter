import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
// import 'package:image_picker/image_picker.dart';  // Temporarily disabled for Firebase compatibility
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PhotoImportService {
  static final PhotoImportService _instance = PhotoImportService._internal();
  factory PhotoImportService() => _instance;
  PhotoImportService._internal();

  // final ImagePicker _picker = ImagePicker();  // Temporarily disabled for Firebase compatibility
  // final TextRecognizer _textRecognizer = TextRecognizer();

  /// Check if camera is available (not on simulator)
  bool get isCameraAvailable {
    // For now, assume camera is available on physical devices
    // We'll let the actual camera picker handle availability
    return true;
  }

  /// Pick an image from camera or gallery with better error handling
  Future<File?> pickImage({bool fromCamera = false}) async {
    // Temporarily disabled for Firebase compatibility
    print('PhotoImportService: Image picker temporarily disabled for Firebase compatibility');
    return null;
  }

  /// Extract text from an image using OCR with better error handling
  Future<List<String>> extractTextFromImage(File imageFile) async {
    // Temporarily disabled for Firebase compatibility
    print('PhotoImportService: OCR temporarily disabled for Firebase compatibility');
    return [];
  }

  /// Extract words with position information from an image
  Future<List<ExtractedWord>> extractWordsWithPosition(String imagePath) async {
    // Temporarily disabled for Firebase compatibility
    print('PhotoImportService: OCR with position temporarily disabled for Firebase compatibility');
    return [];
  }

  /// Clean a word by removing punctuation and converting to lowercase
  String _cleanWord(String word) {
    return word
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .trim();
  }

  /// Clean up resources
  void dispose() {
    try {
      // _textRecognizer.close(); // Temporarily disabled
      print('PhotoImportService: Resources disposed successfully');
    } catch (e) {
      print('PhotoImportService: Error disposing resources: $e');
    }
  }

  /// Force garbage collection to free memory
  void _cleanupMemory() {
    try {
      // This is a hint to the garbage collector
      // In a real app, you might want to use a more sophisticated approach
      print('PhotoImportService: Memory cleanup requested');
    } catch (e) {
      print('PhotoImportService: Error during memory cleanup: $e');
    }
  }
}

/// Data class for extracted words with position information
class ExtractedWord {
  final String word;
  final Rect? boundingBox;
  final double confidence;

  ExtractedWord({
    required this.word,
    this.boundingBox,
    required this.confidence,
  });

  @override
  String toString() {
    return 'ExtractedWord(word: $word, confidence: $confidence)';
  }
}
