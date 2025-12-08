import 'package:flutter/material.dart';
import 'package:pacelifter/models/race.dart';
import 'package:intl/intl.dart';

class RaceListScreen extends StatelessWidget {
  final List<Race> races;

  const RaceListScreen({super.key, required this.races});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('모든 레이스'),
      ),
      body: ListView.builder(
        itemCount: races.length,
        itemBuilder: (context, index) {
          final race = races[index];
          final now = DateTime.now();
          final dDay = race.raceDate.difference(now).inDays + 1;
          final totalTrainingDays = race.raceDate.difference(race.trainingStartDate).inDays;
          final trainingDaysPassed = now.difference(race.trainingStartDate).inDays;
          final progress = totalTrainingDays > 0 ? (trainingDaysPassed / totalTrainingDays).clamp(0.0, 1.0) : 0.0;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        race.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'D-${dDay > 0 ? dDay : 'Day'}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '훈련 기간: ${DateFormat('yyyy.MM.dd').format(race.trainingStartDate)} ~ ${DateFormat('yyyy.MM.dd').format(race.raceDate)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('훈련 진행률: ${(progress * 100).toStringAsFixed(0)}%'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
