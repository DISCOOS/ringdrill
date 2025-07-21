import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';

class SupervisorScreen extends StatefulWidget {
  final int teamIndex;
  final Exercise exercise;

  const SupervisorScreen({
    super.key,
    required this.teamIndex,
    required this.exercise,
  });

  @override
  State<SupervisorScreen> createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen> {
  int currentIndex = 0;

  @override
  void initState() {
    currentIndex = widget.teamIndex;
    super.initState();
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
                          ? DateTimeX.fromMinutes(event.remainingTime).formal()
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
                            '${round[0].formal()} | '
                            '${round[1].formal()} | '
                            '${round[2].formal()}',
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
