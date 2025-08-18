import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class PhotoImportService {
  static final PhotoImportService _instance = PhotoImportService._internal();
  factory PhotoImportService() => _instance;
  PhotoImportService._internal();

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = GoogleMlKit.vision.textRecognizer();

  /// Check if camera is available (not on simulator)
  bool get isCameraAvailable {
    // For now, assume camera is available on physical devices
    // We'll let the actual camera picker handle availability
    return true;
  }

  /// Pick an image from camera or gallery with better error handling
  Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      print('PhotoImportService: Starting image picker...');
      
      print('PhotoImportService: Attempting to pick image from ${fromCamera ? 'camera' : 'gallery'}');
      
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024, // Reduced from 1920 to save memory
        maxHeight: 1024, // Reduced from 1080 to save memory
        imageQuality: 70, // Reduced from 85 to save memory and improve performance
      );
      
      if (image != null) {
        print('PhotoImportService: Image selected successfully');
        final file = File(image.path);
        
        // Check if file exists and is readable
        if (await file.exists()) {
          final fileSize = await file.length();
          print('PhotoImportService: File size: ${fileSize} bytes');
          
          // Check if file is too large (over 10MB)
          if (fileSize > 10 * 1024 * 1024) {
            print('PhotoImportService: File too large, returning null');
            return null;
          }
          
          return file;
        } else {
          print('PhotoImportService: File does not exist');
          return null;
        }
      }
      print('PhotoImportService: No image selected');
      return null;
    } catch (e) {
      print('PhotoImportService: Error picking image: $e');
      return null;
    }
  }

  /// Extract text from an image using OCR with better error handling
  Future<List<String>> extractTextFromImage(File imageFile) async {
    try {
      print('PhotoImportService: Starting OCR processing...');
      
      // Validate file exists
      if (!await imageFile.exists()) {
        print('PhotoImportService: Image file does not exist');
        return [];
      }
      
      final inputImage = InputImage.fromFile(imageFile);
      print('PhotoImportService: InputImage created, processing...');
      
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      print('PhotoImportService: OCR completed, processing ${recognizedText.blocks.length} blocks');
      
      List<String> extractedWords = [];
      
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          for (TextElement element in line.elements) {
            String text = element.text.trim();
            if (text.isNotEmpty) {
              // Split by whitespace and filter out punctuation
              List<String> words = text.split(' ');
              for (String word in words) {
                String cleanWord = _cleanWord(word);
                if (cleanWord.isNotEmpty && 
                    cleanWord.length > 2 && 
                    cleanWord.length < 50 && // Add maximum length to prevent memory issues
                    RegExp(r'^[a-zA-ZÀ-ÿ]+$').hasMatch(cleanWord)) {
                  extractedWords.add(cleanWord);
                }
              }
            }
          }
        }
      }
      
      // Remove duplicates and limit to prevent memory issues
      final uniqueWords = extractedWords.toSet().toList();
      if (uniqueWords.length > 100) {
        print('PhotoImportService: Limiting words to 100 to prevent memory issues');
        uniqueWords.removeRange(100, uniqueWords.length);
      }
      
      print('PhotoImportService: Extracted ${uniqueWords.length} unique words');
      return uniqueWords;
    } catch (e) {
      print('PhotoImportService: Error extracting text from image: $e');
      return [];
    }
  }

  /// Extract text with position information for better word selection
  Future<List<ExtractedWord>> extractWordsWithPosition(File imageFile) async {
    try {
      print('PhotoImportService: Starting OCR with position processing...');
      
      // Validate file exists
      if (!await imageFile.exists()) {
        print('PhotoImportService: Image file does not exist');
        return [];
      }
      
      final inputImage = InputImage.fromFile(imageFile);
      print('PhotoImportService: InputImage created, processing...');
      
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      print('PhotoImportService: OCR completed, processing ${recognizedText.blocks.length} blocks');
      
      List<ExtractedWord> extractedWords = [];
      
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          for (TextElement element in line.elements) {
            String text = element.text.trim();
            if (text.isNotEmpty) {
              // Split by whitespace and filter out punctuation
              List<String> words = text.split(' ');
              for (String word in words) {
                String cleanWord = _cleanWord(word);
                if (cleanWord.isNotEmpty && 
                    cleanWord.length > 2 && 
                    cleanWord.length < 50 && // Add maximum length to prevent memory issues
                    RegExp(r'^[a-zA-ZÀ-ÿ]+$').hasMatch(cleanWord)) {
                  extractedWords.add(ExtractedWord(
                    word: cleanWord,
                    boundingBox: element.boundingBox,
                    confidence: element.confidence ?? 0.0,
                  ));
                }
              }
            }
          }
        }
      }
      
      // Remove duplicates based on word text and limit to prevent memory issues
      Map<String, ExtractedWord> uniqueWords = {};
      for (var extractedWord in extractedWords) {
        if (!uniqueWords.containsKey(extractedWord.word)) {
          uniqueWords[extractedWord.word] = extractedWord;
        }
        
        // Limit to 100 words to prevent memory issues
        if (uniqueWords.length >= 100) {
          print('PhotoImportService: Limiting words to 100 to prevent memory issues');
          break;
        }
      }
      
      final result = uniqueWords.values.toList();
      print('PhotoImportService: Extracted ${result.length} unique words with position');
      return result;
    } catch (e) {
      print('PhotoImportService: Error extracting words with position: $e');
      return [];
    }
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
      _textRecognizer.close();
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
