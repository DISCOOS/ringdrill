import 'package:flutter/material.dart';
import 'package:pretty_date_time/pretty_date_time.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';

class SupervisorViewScreen extends StatefulWidget {
  final int teamIndex;
  final Exercise exercise;

  const SupervisorViewScreen({
    super.key,
    required this.teamIndex,
    required this.exercise,
  });

  @override
  State<SupervisorViewScreen> createState() => _SupervisorViewScreenState();
}

class _SupervisorViewScreenState extends State<SupervisorViewScreen> {
  int currentIndex = 0;

  @override
  void initState() {
    currentIndex = widget.teamIndex;
    super.initState();
  }

  String formatTimeOfDay(TimeOfDay time) {
    return ExerciseX.formatTime(time);
  }

  int stationIndex(int index) {
    return widget.exercise.stationIndex(widget.teamIndex, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Team ${widget.teamIndex + 1}')),
      body: StreamBuilder(
        stream: ExerciseService().events,
        initialData:
            ExerciseService().last ?? ExerciseEvent.from(widget.exercise),
        builder: (context, asyncSnapshot) {
          final event = asyncSnapshot.data!;
          currentIndex = stationIndex(event.currentRound);
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.exercise.name} (${event.state})',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      event.isPending
                          ? prettyDateTime(
                            DateTimeX.fromSeconds(event.remainingTime.abs()),
                          )
                          : '${event.remainingTime} min',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Schedule Details
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.exercise.schedule.length,
                    itemBuilder: (context, index) {
                      final round = widget.exercise.schedule[index];
                      final station =
                          widget.exercise.stations[stationIndex(index)];
                      return Card(
                        color:
                            !event.isDone && station.index == currentIndex
                                ? Theme.of(context).colorScheme.primaryFixed
                                : null,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            '${widget.exercise.stations[stationIndex(index)].name}: '
                            '${formatTimeOfDay(round[0])} | '
                            '${formatTimeOfDay(round[1])} | '
                            '${formatTimeOfDay(round[2])}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
