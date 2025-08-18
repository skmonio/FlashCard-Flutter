import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/store_pack.dart';
import '../models/flash_card.dart';
import 'flashcard_provider.dart';

class StoreProvider extends ChangeNotifier {
  List<StorePack> _storePacks = [];
  Set<String> _unlockedPacks = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<StorePack> get storePacks => _storePacks;
  Set<String> get unlockedPacks => _unlockedPacks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize the store
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _loadStoreMetadata();
      await _loadUnlockedPacks();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Validate unlocked packs against actual user collection
  Future<void> validateUnlockedPacks(FlashcardProvider flashcardProvider) async {
    try {
      final validUnlockedPacks = <String>{};
      
      for (final packId in _unlockedPacks) {
        final pack = getPackById(packId);
        if (pack != null) {
          // Check if any decks from this pack exist in user's collection
          final hasImportedDecks = await _checkPackExistsInCollection(pack, flashcardProvider);
          if (hasImportedDecks) {
            validUnlockedPacks.add(packId);
          } else {
            print('Pack $packId no longer exists in user collection, marking as locked');
          }
        }
      }
      
      // Update unlocked packs
      _unlockedPacks = validUnlockedPacks;
      
      // Update store packs with validated unlocked status
      _storePacks = _storePacks.map((pack) {
        return pack.copyWith(unlocked: _unlockedPacks.contains(pack.id));
      }).toList();
      
      // Save the updated unlocked packs
      await _saveUnlockedPacks();
      notifyListeners();
    } catch (e) {
      print('Error validating unlocked packs: $e');
    }
  }

  // Check if a pack's decks exist in the user's collection
  Future<bool> _checkPackExistsInCollection(StorePack pack, FlashcardProvider flashcardProvider) async {
    try {
      // Load the CSV to get deck names
      final csvString = await rootBundle.loadString('assets/data/store_packs/${pack.filename}');
      final lines = csvString.split('\n').where((line) => line.trim().isNotEmpty).toList();
      
      if (lines.length < 2) return false; // No data rows
      
      // Get deck names from the first data row
      final firstDataRow = lines[1];
      final fields = _parseCSVLine(firstDataRow);
      if (fields.isEmpty) return false;
      
      final deckNames = fields[0].trim(); // Deck info is in first column
      if (deckNames.isEmpty) return false;
      
      // Parse deck hierarchy
      List<String> deckHierarchy;
      if (deckNames.contains(' > ')) {
        deckHierarchy = deckNames.split(' > ').map((name) => name.trim()).toList();
      } else {
        deckHierarchy = [deckNames];
      }
      
      // Check if any of the decks exist in user's collection
      for (final deckName in deckHierarchy) {
        final deckExists = flashcardProvider.decks.any((deck) => deck.name == deckName);
        if (deckExists) {
          return true; // At least one deck from this pack exists
        }
      }
      
      return false; // No decks from this pack exist
    } catch (e) {
      print('Error checking pack existence: $e');
      return false;
    }
  }

  // Simple CSV parsing helper
  List<String> _parseCSVLine(String line) {
    final result = <String>[];
    String current = '';
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    
    result.add(current.trim());
    return result;
  }

  // Load store metadata from JSON file
  Future<void> _loadStoreMetadata() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/store_packs/store_metadata.json');
      
      final jsonData = json.decode(jsonString);
      
      _storePacks = (jsonData['store_packs'] as List)
          .map((packJson) => StorePack.fromJson(packJson))
          .toList();
      
      // Sort by category, difficulty, and name
      _storePacks.sort((a, b) {
        // First sort by category
        if (a.category != b.category) {
          return a.category.compareTo(b.category);
        }
        // Then by difficulty
        if (a.difficulty == 'beginner' && b.difficulty != 'beginner') return -1;
        if (a.difficulty != 'beginner' && b.difficulty == 'beginner') return 1;
        // Finally by name
        return a.name.compareTo(b.name);
      });
      
      notifyListeners();
    } catch (e) {
      print('Error loading store metadata: $e');
      rethrow;
    }
  }

  // Load unlocked packs from SharedPreferences
  Future<void> _loadUnlockedPacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedList = prefs.getStringList('unlocked_store_packs') ?? [];
      _unlockedPacks = unlockedList.toSet();
      
      // Update store packs with unlocked status
      _storePacks = _storePacks.map((pack) {
        return pack.copyWith(unlocked: _unlockedPacks.contains(pack.id));
      }).toList();
      
      notifyListeners();
    } catch (e) {
      print('Error loading unlocked packs: $e');
      rethrow;
    }
  }

  // Save unlocked packs to SharedPreferences
  Future<void> _saveUnlockedPacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('unlocked_store_packs', _unlockedPacks.toList());
    } catch (e) {
      print('Error saving unlocked packs: $e');
      rethrow;
    }
  }

  // Unlock a pack
  Future<bool> unlockPack(String packId) async {
    try {
      _unlockedPacks.add(packId);
      
      // Update store packs
      _storePacks = _storePacks.map((pack) {
        if (pack.id == packId) {
          return pack.copyWith(unlocked: true);
        }
        return pack;
      }).toList();
      
      await _saveUnlockedPacks();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Import a pack to the user's collection
  Future<bool> importPack(String packId, FlashcardProvider flashcardProvider) async {
    try {
      final pack = _storePacks.firstWhere((pack) => pack.id == packId);
      
      // Load the CSV file
      final csvString = await rootBundle.loadString('assets/data/store_packs/${pack.filename}');
      
      // Import using the existing import functionality
      final result = await flashcardProvider.importFromCSV(csvString);
      
      if (result['success'] > 0) {
        // Unlock the pack after successful import
        await unlockPack(packId);
        return true;
      } else {
        _setError('Failed to import pack: ${result['errors']?.join(', ')}');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Get packs by category
  List<StorePack> getPacksByCategory(String category) {
    return _storePacks.where((pack) => pack.category == category).toList();
  }

  // Get packs by difficulty
  List<StorePack> getPacksByDifficulty(String difficulty) {
    return _storePacks.where((pack) => pack.difficulty == difficulty).toList();
  }

  // Get unlocked packs
  List<StorePack> get unlockedPacksList {
    return _storePacks.where((pack) => pack.unlocked).toList();
  }

  // Get locked packs
  List<StorePack> get lockedPacksList {
    return _storePacks.where((pack) => !pack.unlocked).toList();
  }

  // Check if a pack is unlocked
  bool isPackUnlocked(String packId) {
    return _unlockedPacks.contains(packId);
  }

  // Get pack by ID
  StorePack? getPackById(String packId) {
    try {
      return _storePacks.firstWhere((pack) => pack.id == packId);
    } catch (e) {
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all unlocked packs (called when user clears all data)
  Future<void> clearAllUnlockedPacks() async {
    try {
      _unlockedPacks.clear();
      
      // Update store packs to show all as locked
      _storePacks = _storePacks.map((pack) {
        return pack.copyWith(unlocked: false);
      }).toList();
      
      await _saveUnlockedPacks();
      notifyListeners();
      print('Cleared all unlocked store packs');
    } catch (e) {
      print('Error clearing unlocked packs: $e');
    }
  }
}
