import 'package:ai_gameshow/src/env.dart';
import 'package:ai_gameshow/src/models/chat_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

part 'chat_provider.g.dart';

@Riverpod(keepAlive: true)
class Chat extends _$Chat {
  late final GenerativeModel model;
  late final ChatSession chat;
  late final ScrollController scrollController;
  late final TextEditingController textController;
  late final FocusNode textFieldFocus;

  @override
  ChatState build() {
    init();
    return ChatState();
  }

  void init() {
    model = GenerativeModel(
      model: "gemini-pro",
      apiKey: API_KEY,
    );

    chat = model.startChat();
    scrollController = ScrollController();
    textController = TextEditingController();
    textFieldFocus = FocusNode();

    Future.delayed(Duration(milliseconds: 100), () {
      _createInitialPrompt();
    });
  }

  Future<void> sendChatMessage([String? message]) async {
    _clearError();

    message ??= textController.text.trim();

    if (message.isEmpty) {
      _handleError("Please add your message");
      return;
    }

    _startLoading();

    try {
      final response = await chat.sendMessage(Content.text(message));
      final text = response.text;

      if (text == null) {
        _handleError("No response from API.");
        return;
      }

      if (text.contains("✅")) {
        _addCorrectAnswer();
      } else if (text.contains("❌")) {
        _addIncorrectAnswer();
      }

      _scrollDown();
    } catch (e, st) {
      if (kDebugMode) {
        print("Error $e");
        print(st);
      }
      _handleError(e.toString());
    } finally {
      _endLoading();
      textController.clear();
      textFieldFocus.requestFocus();
    }
  }

  Future<void> _createInitialPrompt() async {
    const prompt = """
        Hello gemini. You are a game show host. You'll first respond with something to welcome them to the game show and ask them what category to choose a question from. Either: Geography, History, Science, or Literature.
        They will then respond with a choice of one of those categories.
        If they don't pick a valid category, remind them of the categories and they'll try again. Once they pick a category, you'll ask them a random question from that category.
        Then they will answer and you will determine if it's correct or not as well as asking them to choose another category. This continues.
        For correct responses, please include a checkmark emoji (✅) in your response. If incorrect, add ❌.
        Although this is multiple choice, please don't include things like "A.", "B." etc, just have each option on a new line.

        """;

    await sendChatMessage(prompt);

    state = state.copyWith(ready: true);
  }

  void _startLoading() {
    state = state.copyWith(loading: true);
  }

  void _endLoading() {
    state = state.copyWith(loading: false);
  }

  void _addCorrectAnswer() {
    state = state.copyWith(correctAnswers: state.correctAnswers + 1);
  }

  void _addIncorrectAnswer() {
    state = state.copyWith(incorrectAnswers: state.incorrectAnswers + 1);
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 750,
        ),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  void _handleError(String error) {
    state = state.copyWith(error: error);
  }

  void _clearError() {
    state = state.copyWith(error: null);
  }
}
