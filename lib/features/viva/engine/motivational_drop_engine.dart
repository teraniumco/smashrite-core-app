// lib/features/viva/engine/motivational_drop_engine.dart
//
// Pure functions — the engine passes its _dropsEmitted list in each call.
// No mutable state here.

import 'package:smashrite/features/viva/data/models/viva_question.dart';
import 'package:smashrite/features/viva/engine/viva_dialogue.dart';

class DropKeys {
  static const grounding     = 'grounding';
  static const firstSub      = 'first_sub';
  static const heaviest      = 'heaviest';
  static const midpoint      = 'midpoint';
  static const struggle      = 'struggle';
  static const finalQuestion = 'final_question';

  static const maxDropsPerSession = 4;
}

class MotivationalDropEngine {
  final VivaDialogue _dialogue;

  const MotivationalDropEngine(this._dialogue);

  bool _canDrop(List<String> emitted, String key) =>
      emitted.length < DropKeys.maxDropsPerSession &&
      !emitted.contains(key);

  String? evaluateGrounding(List<String> emitted) {
    if (!_canDrop(emitted, DropKeys.grounding)) return null;
    return _dialogue.groundingDrop;
  }

  String? evaluateFirstSub(
    List<String> emitted, {
    required bool isFirstCompound,
  }) {
    if (!isFirstCompound) return null;
    if (!_canDrop(emitted, DropKeys.firstSub)) return null;
    return _dialogue.firstSubDrop;
  }

  /// Returns (dropText, dropKey) or null.
  (String, String)? evaluateQuestionComplete(
    List<String> emitted, {
    required VivaQuestion completedQuestion,
    required List<VivaQuestion> allQuestions,
    required List<int> answeredIds,
  }) {
    if (emitted.length >= DropKeys.maxDropsPerSession) return null;

    // Heaviest question drop
    if (!emitted.contains(DropKeys.heaviest)) {
      final maxMarks = allQuestions.fold<double>(
          0, (m, q) => q.marks > m ? q.marks : m);
      if (completedQuestion.marks >= maxMarks && allQuestions.length > 1) {
        return (_dialogue.heaviestDrop, DropKeys.heaviest);
      }
    }

    // Final question drop — when one question remains after this
    if (!emitted.contains(DropKeys.finalQuestion)) {
      final allIds = allQuestions.map((q) => q.id).toSet();
      final newAnswered = {...answeredIds, completedQuestion.id};
      final remaining = allIds.difference(newAnswered).length;
      if (remaining == 1) {
        return (_dialogue.finalQuestionDrop, DropKeys.finalQuestion);
      }
    }

    return null;
  }

  String? evaluateMidpoint(
    List<String> emitted, {
    required double percentComplete,
  }) {
    if (!_canDrop(emitted, DropKeys.midpoint)) return null;
    if (percentComplete >= 70) return _dialogue.midpointDrop;
    return null;
  }

  String? evaluateAfterStruggle(
    List<String> emitted, {
    required bool wasLongStruggle,
  }) {
    if (!wasLongStruggle) return null;
    if (!_canDrop(emitted, DropKeys.struggle)) return null;
    return _dialogue.struggleDrop;
  }
}
