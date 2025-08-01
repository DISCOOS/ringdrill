import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/station_widget.dart' show StationWidget;

class TeamScreen extends StatefulWidget {
  final int teamIndex;
  final Exercise exercise;

  const TeamScreen({
    super.key,
    required this.teamIndex,
    required this.exercise,
  });

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  int currentIndex = 0;

  @override
  void initState() {
    currentIndex = widget.teamIndex;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Team ${widget.teamIndex + 1}')),
      body: StreamBuilder(
        stream: ExerciseService().events,
        initialData: _initialData(),
        builder: (context, asyncSnapshot) {
          final event = asyncSnapshot.data!;
          currentIndex = widget.exercise.stationIndex(
            widget.teamIndex,
            event.currentRound,
          );
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
                          title: StationWidget(
                            event: event,
                            stationIndex: widget.exercise.stationIndex(
                              widget.teamIndex,
                              index,
                            ),
                            exercise: widget.exercise,
                            roundIndex: index,
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
