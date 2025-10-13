import 'dart:io';

import 'package:test/test.dart';
import 'package:llm_dart/llm_dart.dart';
import 'dart:async';

void main() {
  group('Cancellation Integration Tests', () {
    test('Cancelling a stream throws CancelledError', () async {
      final openAI = await LLMBuilder()
          .openai()
          .apiKey(Platform.environment['OPENAI_API_KEY']!)
          .build();

      final cancelToken = CancelToken();

      final messages = [
        ChatMessage(
            role: ChatRole.user,
            content: 'Tell me a long story.',
            messageType: const TextMessage()),
      ];

      final stream = openAI.chatStream(messages, cancelToken: cancelToken);
      final completer = Completer<void>();

      stream.listen(
        (event) {},
        onError: (err) {
          if (err is CancelledError) {
            completer.complete();
          } else {
            completer.completeError(err);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError('Stream completed without cancellation');
          }
        },
      );

      Timer(const Duration(milliseconds: 100), () {
        cancelToken.cancel('User cancelled');
      });

      await expectLater(completer.future, completes);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}