import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import '../../data/models/item_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceBillingResult {
  final ItemModel item;
  final int quantity;

  VoiceBillingResult({required this.item, required this.quantity});
}

class VoiceBillingService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  final Map<String, int> _tamilNumbers = {
    'ஒன்னு': 1,
    'ஒரு': 1,
    'ரெண்டு': 2,
    'இரண்டு': 2,
    'மூணு': 3,
    'மூன்று': 3,
    'நாலு': 4,
    'நான்கு': 4,
    'அஞ்சு': 5,
    'ஐந்து': 5,
    'ஆறு': 6,
    'ஏழு': 7,
    'எட்டு': 8,
    'ஒன்பது': 9,
    'பத்து': 10,
  };

  final Map<String, int> _englishNumbers = {
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
  };

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speechToText.initialize();
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required String localeId,
  }) async {
    await _speechToText.listen(
      onResult: (result) => onResult(result.recognizedWords),
      localeId: localeId,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  List<VoiceBillingResult> parseSpeech(String text, List<ItemModel> availableItems) {
    final results = <VoiceBillingResult>[];
    final words = text.toLowerCase().split(' ');
    
    int currentQty = 1;

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      
      // 1. Try to parse as a digit or number word
      final parsedInt = int.tryParse(word);
      if (parsedInt != null) {
        currentQty = parsedInt;
        continue;
      }

      if (_tamilNumbers.containsKey(word)) {
        currentQty = _tamilNumbers[word]!;
        continue;
      }

      if (_englishNumbers.containsKey(word)) {
        currentQty = _englishNumbers[word]!;
        continue;
      }

      // 2. Try to match as an item name or alias
      // We look for the word inside the item name or its Tamil equivalent
      // e.g. "Tea (டீ)" matches "tea" or "டீ"
      for (final item in availableItems) {
        final itemNameLower = item.name.toLowerCase();
        
        // Simple heuristic: if word appears in the item name
        // (Improving this would require more complex NLP or better alias mapping)
        if (itemNameLower.contains(word) && word.length > 2) {
          results.add(VoiceBillingResult(item: item, quantity: currentQty));
          currentQty = 1; // Reset for next item
          break;
        }
      }
    }

    return results;
  }
}

final voiceBillingServiceProvider = Provider((ref) => VoiceBillingService());
