import 'dart:async';
import 'dart:io';

import 'package:llm_dart/llm_dart.dart';

Future<void> main() async {
  final openAI = await LLMBuilder()
      .openai()
      .apiKey(Platform.environment['OPENAI_API_KEY']!)
      .build();

  final cancelToken = CancelToken();

  final messages = [
    ChatMessage.user('Tell me a very long story about the history of the universe.'),
  ];

  print('Starting a long-running streaming chat request...');
  print('This request will be cancelled after 200 milliseconds.');

  // Schedule cancellation
  Timer(const Duration(milliseconds: 200), () {
    print('\n[Cancelling request...]');
    cancelToken.cancel('User decided to cancel the operation.');
  });

  try {
    final stream = openAI.chatStream(messages, cancelToken: cancelToken);

    await for (final event in stream) {
      if (event is TextDeltaEvent) {
        stdout.write(event.delta);
      }
    }
  } catch (e) {
    if (CancellationHelper.isCancelled(e)) {
      print('\n\nRequest was successfully cancelled.');
      final reason = CancellationHelper.getCancellationReason(e);
      if (reason != null) {
        print('Reason: $reason');
      }
    } else {
      print('\n\nAn unexpected error occurred: $e');
    }
  }
}