import 'package:flutter/material.dart';
import 'package:ringdrill/services/exercise_service.dart';

const kPhaseExecution = Color(0xFF1D9E75);
const kPhaseEvaluation = Color(0xFF378ADD);
const kPhaseRotation = Color(0xFFBA7517);

Color colorForPhase(ExercisePhase phase) => switch (phase) {
      ExercisePhase.execution => kPhaseExecution,
      ExercisePhase.evaluation => kPhaseEvaluation,
      ExercisePhase.rotation => kPhaseRotation,
      _ => Colors.grey,
    };

IconData iconForPhase(ExercisePhase phase) => switch (phase) {
      ExercisePhase.execution => Icons.local_fire_department,
      ExercisePhase.evaluation => Icons.fact_check,
      ExercisePhase.rotation => Icons.swap_horiz,
      _ => Icons.hourglass_empty,
    };
