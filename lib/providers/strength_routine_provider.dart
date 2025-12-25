import 'package:flutter/material.dart';
import '../models/templates/template_block.dart';
import '../models/exercises/exercise.dart';

class StrengthRoutineProvider extends ChangeNotifier {
  final List<TemplateBlock> _blocks = [];

  List<TemplateBlock> get blocks => List.unmodifiable(_blocks);

  void addExercise({
    required Exercise exercise,
    required int sets,
    required int reps,
    required double weight,
  }) {
    final block = TemplateBlock(
      id: DateTime.now().toString(),
      name: exercise.name,
      type: 'strength',
      exerciseId: exercise.id,
      sets: sets,
      reps: reps,
      weight: weight,
      order: _blocks.length,
    );
    _blocks.add(block);
    notifyListeners();
  }

  void addBlock(TemplateBlock block) {
    _blocks.add(block);
    notifyListeners();
  }

  void removeBlock(String id) {
    _blocks.removeWhere((b) => b.id == id);
    notifyListeners();
  }
  
  void clear() {
    _blocks.clear();
    notifyListeners();
  }
}
