import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/time_utils.dart';

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({super.key, this.exercise, this.numberOfTeams});

  final Exercise? exercise;
  final int? numberOfTeams;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  static const int _maxCounterValue = 12;

  final _formKey = GlobalKey<FormState>();

  TimeOfDay _startTime = _initStartTime();

  static TimeOfDay _initStartTime() {
    final now = DateTime.now();
    return TimeOfDay(
      hour: now.minute > 30 ? (now.hour + 1) % 24 : now.hour,
      minute: now.minute > 30 ? 0 : 30,
    );
  } // Default start time

  // Form field controllers
  final TextEditingController _nameController = TextEditingController(text: "");
  final TextEditingController _numberOfTeamsController = TextEditingController(
    text: "4",
  );
  final TextEditingController _numberOfStationsController =
      TextEditingController(text: "4");
  final TextEditingController _numberOfRoundsController = TextEditingController(
    text: "4",
  );
  final TextEditingController _executionTimeController = TextEditingController(
    text: "15",
  );
  final TextEditingController _evaluationTimeController = TextEditingController(
    text: "10",
  );
  final TextEditingController _rotationTimeController = TextEditingController(
    text: "5",
  );

  bool _stationsTracksTeams = true;
  bool _legacyOversizedCounters = false;

  @override
  void initState() {
    final e = widget.exercise;
    if (e != null) {
      _startTime = e.startTime.toMaterial();
      _nameController.text = e.name;
      _numberOfTeamsController.text = (widget.numberOfTeams ?? e.numberOfTeams)
          .toString();
      _numberOfStationsController.text = e.stations.length.toString();
      _numberOfRoundsController.text = e.numberOfRounds.toString();
      _executionTimeController.text = e.executionTime.toString();
      _evaluationTimeController.text = e.evaluationTime.toString();
      _rotationTimeController.text = e.rotationTime.toString();
      _stationsTracksTeams = false;
      _legacyOversizedCounters =
          (widget.numberOfTeams ?? e.numberOfTeams) > _maxCounterValue ||
          e.stations.length > _maxCounterValue ||
          e.numberOfRounds > _maxCounterValue;
    } else {
      _numberOfStationsController.text = _numberOfTeamsController.text;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.exercise == null
              ? localizations.createExercise
              : localizations.editExercise,
        ),
        actions: [
          ElevatedButton(
            onPressed: _saveExercise,
            child: Text(localizations.save),
          ),
        ],
        actionsPadding: EdgeInsets.only(right: 16.0),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Exercise Name
                TextFormField(
                  autofocus: true,
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: localizations.exerciseName,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? localizations.pleaseEnterAName
                      : null,
                ),

                SizedBox(height: 16.0),

                // Start Time Picker
                GestureDetector(
                  onTap: _pickStartTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.only(top: 8),
                      label: Text(localizations.startTime),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _startTime.formal(),
                            style: TextStyle(fontSize: 16.0),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: _pickStartTime,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.0),

                // Execution Time
                TextFormField(
                  controller: _executionTimeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: localizations.executionTime,
                  ),
                  validator: (value) => _isValidNumber(value)
                      ? null
                      : localizations.pleaseEnterAValidTime,
                ),

                SizedBox(height: 16.0),

                // Evaluation Time
                TextFormField(
                  controller: _evaluationTimeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: localizations.evaluationTime,
                  ),
                  validator: (value) => _isValidNumber(value)
                      ? null
                      : localizations.pleaseEnterAValidTime,
                ),

                SizedBox(height: 16.0),

                // Rotation Time
                TextFormField(
                  controller: _rotationTimeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: localizations.rotationTime,
                  ),
                  validator: (value) => _isValidNumber(value)
                      ? null
                      : localizations.pleaseEnterAValidTime,
                ),

                SizedBox(height: 16.0),

                if (_legacyOversizedCounters) ...[
                  MaterialBanner(
                    content: Text(localizations.legacyOversizedExerciseNotice),
                    actions: const [SizedBox.shrink()],
                    padding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 8,
                    ),
                    leading: const Icon(Icons.info_outline),
                  ),
                  SizedBox(height: 16.0),
                ],

                Row(
                  children: [
                    // Number of Teams
                    Expanded(
                      child: TextFormField(
                        controller: _numberOfTeamsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: localizations.numberOfTeams,
                        ),
                        onChanged: (value) {
                          if (_stationsTracksTeams) {
                            _numberOfStationsController.text = value;
                          }
                          setState(() {});
                        },
                        validator: (value) {
                          final counterError = _validateCounter(
                            value,
                            localizations,
                          );
                          if (counterError != null) return counterError;
                          if (_isValidNumber(
                                _numberOfStationsController.text,
                              ) &&
                              int.parse(value!) >
                                  int.parse(_numberOfStationsController.text)) {
                            return localizations
                                .mustBeEqualToOrLessThanNumberOf(
                                  localizations.station(2).toLowerCase(),
                                );
                          }
                          return null;
                        },
                      ),
                    ),

                    SizedBox(width: 16.0),

                    // Number of Stations
                    Expanded(
                      child: TextFormField(
                        controller: _numberOfStationsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: localizations.numberOfStations,
                        ),
                        onChanged: (_) {
                          _stationsTracksTeams = false;
                          setState(() {});
                        },
                        validator: (value) {
                          final counterError = _validateCounter(
                            value,
                            localizations,
                          );
                          if (counterError != null) return counterError;
                          if (_isValidNumber(_numberOfTeamsController.text) &&
                              int.parse(value!) <
                                  int.parse(_numberOfTeamsController.text)) {
                            return localizations
                                .mustBeEqualToOrGreaterThanNumberOf(
                                  localizations.team(2).toLowerCase(),
                                );
                          }
                          return null;
                        },
                      ),
                    ),

                    SizedBox(width: 16.0),

                    // Number of Rounds
                    Expanded(
                      child: TextFormField(
                        controller: _numberOfRoundsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: localizations.numberOfRounds,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) =>
                            _validateCounter(value, localizations),
                      ),
                    ),
                  ],
                ),
                ?_buildStationsRoundNote(localizations),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  // Validate and add the exercise
  Future<void> _saveExercise() async {
    final String? validationError = ExerciseX.sanitizeExerciseName(
      _nameController.text,
    );

    if (validationError != null) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          dismissDirection: DismissDirection.endToStart,
          content: Text(validationError),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final numberOfTeams = int.parse(_numberOfTeamsController.text);
      final numberOfStations = int.parse(_numberOfStationsController.text);
      final numberOfRounds = int.parse(_numberOfRoundsController.text);
      final executionTime = int.parse(_executionTimeController.text);
      final evaluationTime = int.parse(_evaluationTimeController.text);
      final rotationTime = int.parse(_rotationTimeController.text);
      final localizations = AppLocalizations.of(context)!;

      final existingExercise = widget.exercise;
      if (existingExercise != null &&
          numberOfStations < existingExercise.stations.length) {
        final droppedStations = existingExercise.stations.asMap().entries.where(
          (entry) => entry.key >= numberOfStations,
        );
        final dropsUserVisibleContent = droppedStations.any((entry) {
          final station = entry.value;
          final defaultName = '${localizations.station(1)} ${entry.key + 1}';
          return station.name != defaultName ||
              (station.description?.isNotEmpty ?? false) ||
              station.position != null;
        });

        if (dropsUserVisibleContent) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(localizations.confirmReduceStationsTitle),
              content: Text(
                localizations.confirmReduceStationsBody(
                  existingExercise.stations.length - numberOfStations,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(localizations.yes),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (confirmed != true) {
            return;
          }
        }
      }

      // Generate exercise with user input
      final newExercise = ProgramService.generateSchedule(
        name: name,
        startTime: _startTime,
        uuid: widget.exercise?.uuid,
        numberOfTeams: numberOfTeams,
        numberOfStations: numberOfStations,
        numberOfRounds: numberOfRounds,
        executionTime: executionTime,
        evaluationTime: evaluationTime,
        rotationTime: rotationTime,
        stations: widget.exercise?.stations ?? [],
        localizations: localizations,
      );

      // Return the exercise to the previous screen
      Navigator.of(context).pop(newExercise);
    }
  }

  bool _isValidNumber(String? value) {
    return value != null && int.tryParse(value) != null && int.parse(value) > 0;
  }

  String? _validateCounter(String? value, AppLocalizations localizations) {
    if (!_isValidNumber(value)) {
      return localizations.pleaseEnterAValidNumber;
    }
    if (int.parse(value!) > _maxCounterValue) {
      return localizations.mustBeEqualToOrLessThanNumberOf(
        _maxCounterValue.toString(),
      );
    }
    return null;
  }

  Widget? _buildStationsRoundNote(AppLocalizations localizations) {
    final numberOfRounds = int.tryParse(_numberOfRoundsController.text);
    final numberOfStations = int.tryParse(_numberOfStationsController.text);
    if (numberOfRounds == null ||
        numberOfStations == null ||
        numberOfRounds <= 0 ||
        numberOfStations <= 0 ||
        numberOfRounds == numberOfStations) {
      return null;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final text = numberOfRounds > numberOfStations
        ? localizations.stationsRevisitNote(numberOfRounds, numberOfStations)
        : localizations.stationsUnderCoverageNote(
            numberOfRounds,
            numberOfStations,
          );
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.tertiary),
      ),
    );
  }

  @override
  void dispose() {
    _numberOfRoundsController.dispose();
    _numberOfTeamsController.dispose();
    _numberOfStationsController.dispose();
    _nameController.dispose();
    _evaluationTimeController.dispose();
    _rotationTimeController.dispose();
    _executionTimeController.dispose();
    super.dispose();
  }
}
