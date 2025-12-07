import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../services/ai_service.dart';

final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

final aiKeysProvider = StateNotifierProvider<AIKeysNotifier, AIKeys>((ref) {
  return AIKeysNotifier();
});

/// Tracks whether API keys have been loaded from storage
final aiKeysLoadedProvider = StateProvider<bool>((ref) => false);

final selectedAIProviderProvider = StateProvider<AIProvider>((ref) {
  return AIProvider.openai;
});

class AIKeys {
  final String? openAI;
  final String? anthropic;
  final String? gemini;

  AIKeys({this.openAI, this.anthropic, this.gemini});
  
  bool get hasAnyKey => openAI != null || anthropic != null || gemini != null;

  AIKeys copyWith({String? openAI, String? anthropic, String? gemini}) {
    return AIKeys(
      openAI: openAI ?? this.openAI,
      anthropic: anthropic ?? this.anthropic,
      gemini: gemini ?? this.gemini,
    );
  }
}

class AIKeysNotifier extends StateNotifier<AIKeys> {
  Box<String>? _box;
  final bool _useHive;
  bool _isLoaded = false;
  
  bool get isLoaded => _isLoaded;

  /// Standard constructor - uses Hive for persistence (main window only)
  AIKeysNotifier() : _useHive = true, super(AIKeys()) {
    _init();
  }
  
  /// Factory constructor for separate windows - no Hive access
  /// Pass the API keys directly since Hive is locked by main process
  AIKeysNotifier.withKeys(AIKeys keys) : _useHive = false, _isLoaded = true, super(keys);

  Future<void> _init() async {
    if (!_useHive) {
      _isLoaded = true;
      return;
    }
    try {
      _box = await Hive.openBox<String>('ai_keys');
      await _loadKeys();
      _isLoaded = true;
      print('AIKeysNotifier: Keys loaded successfully');
    } catch (e) {
      print('AIKeysNotifier: Hive init failed: $e');
      _isLoaded = true; // Mark as loaded even on error so UI isn't stuck
    }
  }

  Future<void> _loadKeys() async {
    if (_box == null) return;

    state = AIKeys(
      openAI: _box!.get('openai'),
      anthropic: _box!.get('anthropic'),
      gemini: _box!.get('gemini'),
    );
  }

  Future<void> saveKeys({String? openAI, String? anthropic, String? gemini}) async {
    if (_box == null) return;

    if (openAI != null) await _box!.put('openai', openAI);
    if (anthropic != null) await _box!.put('anthropic', anthropic);
    if (gemini != null) await _box!.put('gemini', gemini);

    state = AIKeys(
      openAI: openAI ?? state.openAI,
      anthropic: anthropic ?? state.anthropic,
      gemini: gemini ?? state.gemini,
    );
  }

  Future<void> clearKey(String provider) async {
    if (_box == null) return;

    await _box!.delete(provider);
    
    switch (provider) {
      case 'openai':
        state = state.copyWith(openAI: null);
        break;
      case 'anthropic':
        state = state.copyWith(anthropic: null);
        break;
      case 'gemini':
        state = state.copyWith(gemini: null);
        break;
    }
  }
}

// Model selection for each provider
final selectedModelProvider = StateProvider<Map<AIProvider, String>>((ref) {
  return {
    AIProvider.openai: 'gpt-4o-mini',
    AIProvider.anthropic: 'claude-3-5-sonnet-20241022',
    AIProvider.gemini: 'gemini-2.0-flash-exp',
  };
});

// Available models for each provider
final availableModels = {
  AIProvider.openai: [
    {'id': 'gpt-4o', 'name': 'GPT-4o (Best)', 'cost': '\$\$\$'},
    {'id': 'gpt-4o-mini', 'name': 'GPT-4o Mini (Recommended)', 'cost': '\$'},
    {'id': 'gpt-3.5-turbo', 'name': 'GPT-3.5 Turbo (Cheapest)', 'cost': '\$'},
  ],
  AIProvider.anthropic: [
    {'id': 'claude-3-5-sonnet-20241022', 'name': 'Claude 3.5 Sonnet (Best)', 'cost': '\$\$'},
    {'id': 'claude-3-opus-20240229', 'name': 'Claude 3 Opus', 'cost': '\$\$\$'},
    {'id': 'claude-3-haiku-20240307', 'name': 'Claude 3 Haiku (Cheapest)', 'cost': '\$'},
  ],
  AIProvider.gemini: [
    {'id': 'gemini-2.0-flash-exp', 'name': 'Gemini 2.0 Flash (Free)', 'cost': 'Free'},
    {'id': 'gemini-1.5-pro', 'name': 'Gemini 1.5 Pro', 'cost': '\$'},
  ],
};
