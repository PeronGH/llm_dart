import 'package:dio/dio.dart';

import '../../core/llm_error.dart';
import 'client.dart';
import 'config.dart';

/// ElevenLabs Models capability implementation
///
/// This module handles model-related functionality for ElevenLabs providers,
/// including listing available models and getting model information.
class ElevenLabsModels {
  final ElevenLabsClient client;
  final ElevenLabsConfig config;

  ElevenLabsModels(this.client, this.config);

  /// Get available models
  Future<List<Map<String, dynamic>>> getModels(
      {CancelToken? cancelToken}) async {
    if (config.apiKey.isEmpty) {
      throw const AuthError('Missing ElevenLabs API key');
    }

    try {
      final models = await client.getList('models', cancelToken: cancelToken);
      return models.cast<Map<String, dynamic>>();
    } catch (e) {
      if (e is LLMError) rethrow;
      throw GenericError('Unexpected error: $e');
    }
  }

  /// Get user subscription info
  Future<Map<String, dynamic>> getUserInfo({CancelToken? cancelToken}) async {
    if (config.apiKey.isEmpty) {
      throw const AuthError('Missing ElevenLabs API key');
    }

    try {
      return await client.getJson('user', cancelToken: cancelToken);
    } catch (e) {
      if (e is LLMError) rethrow;
      throw GenericError('Unexpected error: $e');
    }
  }

  /// Get model information by ID
  Future<Map<String, dynamic>?> getModelInfo(String modelId,
      {CancelToken? cancelToken}) async {
    final models = await getModels(cancelToken: cancelToken);

    for (final model in models) {
      if (model['model_id'] == modelId) {
        return model;
      }
    }

    return null;
  }

  /// Check if a model supports TTS
  Future<bool> modelSupportsTTS(String modelId,
      {CancelToken? cancelToken}) async {
    final modelInfo = await getModelInfo(modelId, cancelToken: cancelToken);
    if (modelInfo == null) return false;

    final canDoTTS = modelInfo['can_do_text_to_speech'] as bool?;
    return canDoTTS ?? false;
  }

  /// Check if a model supports STT
  Future<bool> modelSupportsSTT(String modelId,
      {CancelToken? cancelToken}) async {
    final modelInfo = await getModelInfo(modelId, cancelToken: cancelToken);
    if (modelInfo == null) return false;

    final canDoSTT = modelInfo['can_do_voice_conversion'] as bool?;
    return canDoSTT ?? false;
  }

  /// Get recommended TTS models
  Future<List<String>> getRecommendedTTSModels(
      {CancelToken? cancelToken}) async {
    final models = await getModels(cancelToken: cancelToken);
    final ttsModels = <String>[];

    for (final model in models) {
      final canDoTTS = model['can_do_text_to_speech'] as bool?;
      if (canDoTTS == true) {
        final modelId = model['model_id'] as String?;
        if (modelId != null) {
          ttsModels.add(modelId);
        }
      }
    }

    return ttsModels;
  }

  /// Get recommended STT models
  Future<List<String>> getRecommendedSTTModels(
      {CancelToken? cancelToken}) async {
    final models = await getModels(cancelToken: cancelToken);
    final sttModels = <String>[];

    for (final model in models) {
      final canDoSTT = model['can_do_voice_conversion'] as bool?;
      if (canDoSTT == true) {
        final modelId = model['model_id'] as String?;
        if (modelId != null) {
          sttModels.add(modelId);
        }
      }
    }

    return sttModels;
  }

  /// Get model capabilities
  Future<Map<String, bool>> getModelCapabilities(String modelId,
      {CancelToken? cancelToken}) async {
    final modelInfo = await getModelInfo(modelId, cancelToken: cancelToken);
    if (modelInfo == null) {
      return {
        'tts': false,
        'stt': false,
        'voice_conversion': false,
        'voice_cloning': false,
      };
    }

    return {
      'tts': modelInfo['can_do_text_to_speech'] as bool? ?? false,
      'stt': modelInfo['can_do_voice_conversion'] as bool? ?? false,
      'voice_conversion':
          modelInfo['can_do_voice_conversion'] as bool? ?? false,
      'voice_cloning': modelInfo['can_be_finetuned'] as bool? ?? false,
    };
  }

  /// Get model languages
  Future<List<String>> getModelLanguages(String modelId,
      {CancelToken? cancelToken}) async {
    final modelInfo = await getModelInfo(modelId, cancelToken: cancelToken);
    if (modelInfo == null) return [];

    final languages = modelInfo['languages'] as List<dynamic>?;
    return languages?.cast<String>() ?? [];
  }

  /// Get model description
  Future<String?> getModelDescription(String modelId,
      {CancelToken? cancelToken}) async {
    final modelInfo = await getModelInfo(modelId, cancelToken: cancelToken);
    return modelInfo?['description'] as String?;
  }

  /// Check if model is available for current subscription
  Future<bool> isModelAvailable(String modelId,
      {CancelToken? cancelToken}) async {
    try {
      final userInfo = await getUserInfo(cancelToken: cancelToken);
      final subscription = userInfo['subscription'] as Map<String, dynamic>?;

      if (subscription == null) return false;

      final tier = subscription['tier'] as String?;
      final modelInfo = await getModelInfo(modelId, cancelToken: cancelToken);

      if (modelInfo == null) return false;

      // Basic availability check - in practice, this would depend on
      // the specific subscription tier and model requirements
      return tier != null;
    } catch (e) {
      return false;
    }
  }
}
