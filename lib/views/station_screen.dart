import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/team_state_widget.dart';

class StationScreen extends StatefulWidget {
  final int stationIndex;
  final Exercise exercise;

  const StationScreen({
    super.key,
    required this.stationIndex,
    required this.exercise,
  });

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  int currentIndex = 0;

  @override
  void initState() {
    currentIndex = widget.stationIndex;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.stations[widget.stationIndex].name),
      ),
      body: StreamBuilder(
        stream: ExerciseService().events,
        initialData: _initialData(),
        builder: (context, asyncSnapshot) {
          final event = asyncSnapshot.data!;
          currentIndex = widget.stationIndex;
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
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: TeamStateWidget(
                            event: event,
                            roundIndex: index,
                            teamIndex: widget.exercise.teamIndex(
                              widget.stationIndex,
                              index,
                            ),
                            exercise: widget.exercise,
                            mainAxisAlignment: MainAxisAlignment.start,
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

  ExerciseEvent _initialData() {
    final last = ExerciseService().last;
    if (last?.exercise == widget.exercise) return last!;
    return ExerciseEvent.pending(widget.exercise);
  }
}
