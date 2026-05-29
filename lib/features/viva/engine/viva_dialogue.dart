// Viva's authored response library.
//
// Rules from the personality document:
//  - Minimum 5 variants per state to prevent repetition
//  - No "Wrong", "Incorrect", "Hurry up", or urgency language
//  - No hollow praise ("Great job!", "Amazing!")
//  - Measured, specific affirmation only
//  - Short sentences for encouragement/transitions
//  - Nigerian student context: warmth of respected senior, not Western edtech
//  - "Let's" signals partnership — not "you must"
//  - Silence is part of Viva's personality — not every action needs a response

import 'dart:math';

class VivaDialogue {
  static final Random _random = Random();

  /// A tracker per session to prevent repeating the same variant.
  /// Key = state name, Value = list of indices already used.
  final Map<String, List<int>> _usedIndices = {};

  /// Pick a variant from a list without repeating until all are exhausted.
  String _pick(String stateKey, List<String> variants) {
    final used = _usedIndices[stateKey] ?? [];
    final available = List.generate(variants.length, (i) => i)
        .where((i) => !used.contains(i))
        .toList();

    if (available.isEmpty) {
      // All variants used — reset and start over
      _usedIndices[stateKey] = [];
      return _pick(stateKey, variants);
    }

    final index = available[_random.nextInt(available.length)];
    _usedIndices[stateKey] = [...used, index];
    return variants[index];
  }

  // ── Opening ───────────────────────────────────────────────────────────────

  String get grounding => _pick('grounding', [
    "Welcome. I'm Viva, and I'll be with you through your examination today.\n\nWe'll take this one question at a time. There's no rush.\n\nWhen you're ready, let's begin.",
    "Welcome. I'm Viva.\n\nI'll guide you through each question. You set the pace — I'll keep things moving.\n\nLet's begin when you're ready.",
    "I'm Viva. I'll be with you through this examination.\n\nOne question at a time. Read carefully before you respond.\n\nTake a breath. Let's begin.",
    "Welcome. I'm Viva — your examination companion today.\n\nWe'll move through the questions together, one at a time.\n\nWhen you're ready, let's start.",
    "I'm Viva. I'll walk you through your examination.\n\nThere's no rush here. Read everything carefully before you respond.\n\nReady when you are.",
  ]);

  // ── Scan overview ─────────────────────────────────────────────────────────

  String scanRequired(int questionCount) =>
      _pick('scan_required', [
        "Take your time reading through the $questionCount questions. Begin when you're ready.",
        "Read through all $questionCount questions before we start. There's no pressure to rush.",
        "Here are your $questionCount questions. Read each one fully, then we'll begin together.",
        "Take a moment to read through the questions. $questionCount in total. Let me know when you're ready.",
        "These are your $questionCount questions. Read through them at your own pace.",
      ]);

  String scanOptional(int required, int total, {int? optionalCount}) {
    final groupNote = optionalCount != null && optionalCount != total
        ? ' (choose $required of the $optionalCount optional)'
        : '';
    return _pick('scan_optional', [
      'Read through all $total questions below$groupNote, then lock your selection to begin.',
      'There are $total questions. $required ${required == 1 ? 'is' : 'are'} optional — choose which one to answer.',
      'Review the $total questions in this section. You must answer $required from the optional group.',
    ]);
  }

  // ── Start choice ──────────────────────────────────────────────────────────

  String get startChoice => _pick('start_choice', [
    "Which question would you like to start with?",
    "Where would you like to begin?",
    "Choose your starting question.",
    "Which one first?",
    "Start with whichever feels right.",
  ]);

  // ── Question intro (single / compound) ───────────────────────────────────

  String get questionIntroSingle => _pick('q_intro_single', [
    "Here's your question. Read through it fully before you start.",
    "Take your time with this one.",
    "Read through this carefully before you respond.",
    "Here it is. No rush — read it fully first.",
    "Here's the question. Take a moment with it.",
  ]);

  String questionIntroCompound(int partCount) =>
      _pick('q_intro_compound', [
        "This question has $partCount parts. We'll take them one at a time.",
        "There are $partCount parts to this question. I'll guide you through each one.",
        "$partCount parts. Let's work through them together, step by step.",
        "This one has $partCount parts. We'll move through them in order.",
        "Read through the question. It has $partCount parts — I'll walk you through each.",
      ]);

  // ── Sub-question transitions ──────────────────────────────────────────────

  String get subQuestionTransition => _pick('sub_transition', [
    "Good. Let's move to the next part.",
    "Noted. Here's the next part.",
    "Alright. Moving on.",
    "Received. Next part.",
    "Noted. Let's continue.",
  ]);

  // ── Essay prompts ─────────────────────────────────────────────────────────

  String essayPrompt({int? minWords, int? maxWords}) {
    final constraint = minWords != null && maxWords != null
        ? " Aim for $minWords–$maxWords words."
        : minWords != null
            ? " Write at least $minWords words."
            : maxWords != null
                ? " Keep it under $maxWords words."
                : "";

    return _pick('essay_prompt', [
      "Structure your response however feels natural. A clear argument matters more than length.$constraint",
      "Start with your main point, then support it.$constraint",
      "Write what you know. Clarity matters more than volume.$constraint",
      "Make your case clearly.$constraint",
      "Take your time. Structure first, then write.$constraint",
    ]);
  }

  // ── Calculation prompts ────────────────────────────────────────────────────

  String get workingNotesPrompt => _pick('working_notes', [
    "Type your rough working here if it helps — this is optional.",
    "You can use this space for working notes. It's optional.",
    "Rough working goes here if you'd like — not required.",
    "Feel free to jot your working here. Optional.",
    "Working notes here, if you want them.",
  ]);

  String get finalAnswerPrompt => _pick('final_answer', [
    "Now enter your final answer. Include units where relevant.",
    "Enter your final answer with units.",
    "What is your final answer? Include units.",
    "State your final answer clearly, with units.",
    "Final answer with units.",
  ]);

  // ── Diagram prompts ───────────────────────────────────────────────────────

  String diagramPrompt(List<String> checklist) {
    final items = checklist.isNotEmpty
        ? "\n\nYour diagram should include:\n${checklist.map((c) => "· $c").join("\n")}"
        : "";

    return _pick('diagram_prompt', [
      "Draw your diagram on paper, then photograph it when you're ready.$items",
      "Sketch your diagram carefully, then capture a clear photo.$items",
      "Take your time with the diagram. Accuracy matters more than speed.$items",
      "Draw it out, then photograph it.$items",
      "Diagram on paper first. Then we'll capture it.$items",
    ]);
  }

  // ── Photo code display ────────────────────────────────────────────────────

  String photoCodeInstruction(String questionLabel) =>
      _pick('photo_code', [
        "Write this on your paper before you draw:\n\nYour student ID · $questionLabel · and the code shown below.\n\nThen photograph your workings.",
        "Before you capture, write your student ID, question $questionLabel, and the code below on your paper.",
        "Write your ID, question label ($questionLabel), and this code on the paper. Then take the photo.",
        "Paper first: student ID · $questionLabel · code below. Then photograph.",
        "Note your student ID, $questionLabel, and this code on the paper before capturing.",
      ]);

  // ── Photo confirmation ────────────────────────────────────────────────────

  String get photoConfirmed => _pick('photo_confirmed', [
    "Received. That's the workings captured.",
    "Got it. Photo received.",
    "Received.",
    "Captured. ✓",
    "Photo received. Let's continue.",
  ]);

  // ── Essay / final answer confirmation ────────────────────────────────────

  String essayConfirmed(int wordCount) => _pick('essay_confirmed', [
    "Noted. $wordCount words received.",
    "Response received.",
    "Got it.",
    "Received.",
    "Noted.",
  ]);

  String get finalAnswerConfirmed => _pick('final_answer_confirmed', [
    "Noted.",
    "Got it.",
    "Received.",
    "Final answer noted.",
    "Recorded.",
  ]);

  // ── Question complete ─────────────────────────────────────────────────────

  String questionComplete(String label) => _pick('question_complete', [
    "You've answered Question $label. Well done for working through it.",
    "That's Question $label done.",
    "Question $label complete.",
    "Question $label finished. Let's keep going.",
    "Done with Question $label.",
  ]);

  // ── Between questions ─────────────────────────────────────────────────────

  String get nextQuestionChoice => _pick('next_choice', [
    "Which question would you like next?",
    "What's next?",
    "Choose your next question.",
    "Which one next?",
    "Next question — your choice.",
  ]);

  // ── Context hint (carry-forward) ───────────────────────────────────────────

  String contextHint(String label, String value) =>
      "Using your $label answer: $value. You'll need that here.";

  // ── Submission ────────────────────────────────────────────────────────────

  String get submitPrompt => _pick('submit_prompt', [
    "All questions answered. Review your responses or submit when you're ready.",
    "That's everything. Ready to submit?",
    "You've completed all the questions. Submit when you're satisfied.",
    "All done. Take a final look, or submit.",
    "All questions answered. When you're ready, let's submit.",
  ]);

  // ── Exam complete ─────────────────────────────────────────────────────────

  String get examComplete => _pick('exam_complete', [
    "You've answered all your questions. Well done for staying with it.",
    "Your responses have been submitted. That took focus — respect.",
    "This examination is complete. Whatever happens next, you showed up and gave your answer. That matters.",
    "Done. Your responses are in.",
    "Examination complete. You stayed with it throughout.",
  ]);

  // ════════════════════════════════════════════════════════════════════════
  // MOTIVATIONAL DROPS
  // Deployed at specific moments only. Max 4 per exam. Never generic.
  // ════════════════════════════════════════════════════════════════════════

  /// Drop 1 — grounding (before first question opens)
  String get groundingDrop => _pick('drop_grounding', [
    "I'll take you through each question one at a time. Read carefully before you respond.",
    "One question at a time. That's all this is.",
    "Read everything carefully. We'll get through this together.",
    "Stay with each question as it comes.",
    "There's no shortcut here — just you and the questions. Let's go.",
  ]);

  /// Drop 2 — after first sub-question of compound
  String get firstSubDrop => _pick('drop_first_sub', [
    "Good. One part done — the structure is the same for the rest. Stay with it.",
    "First part done. Same structure from here.",
    "You've got the rhythm now. Keep going.",
    "One down. The rest follow the same pattern.",
    "That's the first part. You know what to expect now.",
  ]);

  /// Drop 3 — after the heaviest question (most marks)
  String get heaviestDrop => _pick('drop_heaviest', [
    "That was the heaviest question. What's left is lighter. You're doing well.",
    "The hardest one is done. The rest is clearer from here.",
    "You've answered the biggest question. Keep the same energy.",
    "That one asked the most of you. The rest is lighter.",
    "Heaviest question done. Finish strong.",
  ]);

  /// Drop 4 — at 70%+ marks submitted
  String get midpointDrop => _pick('drop_midpoint', [
    "You're past the halfway point. Keep the same pace.",
    "More than halfway. You're moving well.",
    "Past halfway — good. Don't change anything.",
    "You've answered most of the marks. Keep going.",
    "Over halfway. Stay focused and finish.",
  ]);

  /// Drop 5 — after long struggle then response
  String get struggleDrop => _pick('drop_struggle', [
    "You worked through that. That takes something.",
    "That took thinking. You stayed with it.",
    "You found your way through. Well done.",
    "That wasn't easy. You got there.",
    "You pushed through. That's what matters.",
  ]);

  /// Drop 6 — final question
  String get finalQuestionDrop => _pick('drop_final', [
    "This is your last question. Finish strong.",
    "One question left. Give it what you've got.",
    "Last one. Same focus you've had all along.",
    "Final question. You've come this far.",
    "Last question. Make it count.",
  ]);

  // ── Encouragement (for when student is stuck) ──────────────────────────────

  String get stuckPrompt => _pick('stuck', [
    "Take the time you need.",
    "Start with whatever comes to mind first.",
    "There's no perfect place to start — just begin.",
    "Start with what you know, even if it feels incomplete.",
    "Even a partial answer is a start. Begin there.",
  ]);
}
