import 'package:flutter/material.dart';
import '../models/templates/template_block.dart';
import '../models/exercises/exercise.dart';

class StrengthRoutineProvider extends ChangeNotifier {
  final List<TemplateBlock> _blocks = [];
  DateTime? _lastAddedTimestamp;

  List<TemplateBlock> get blocks => List.unmodifiable(_blocks);
  DateTime? get lastAddedTimestamp => _lastAddedTimestamp;

  void addExercise({
    required Exercise exercise,
    required int sets,
    required int reps,
    required double weight,
    List<String>? selectedVariations,
  }) {
    final block = TemplateBlock(
      id: DateTime.now().toString(),
      name: exercise.name,
      type: 'strength',
      exerciseId: exercise.id,
      sets: sets,
      reps: reps,
      weight: weight,
      selectedVariations: selectedVariations,
      order: _blocks.length,
    );
    _blocks.add(block);
    _lastAddedTimestamp = DateTime.now();
    notifyListeners();
  }

  void addBlock(TemplateBlock block) {
    _blocks.add(block);
    _lastAddedTimestamp = DateTime.now();
    notifyListeners();
  }

  void removeBlock(String id) {
    _blocks.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  void reorderBlocks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final TemplateBlock item = _blocks.removeAt(oldIndex);
    _blocks.insert(newIndex, item);
    notifyListeners();
  }
  
  void clear() {
    _blocks.clear();
    notifyListeners();
  }
}
