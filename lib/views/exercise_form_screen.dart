import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/utils/time_utils.dart';

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({super.key, this.exercise, this.numberOfTeams});

  final Exercise? exercise;
  final int? numberOfTeams;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
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

  @override
  void initState() {
    final e = widget.exercise;
    if (e != null) {
      _startTime = e.startTime;
      _nameController.text = e.name;
      _numberOfTeamsController.text = (widget.numberOfTeams ?? e.numberOfTeams)
          .toString();
      _numberOfRoundsController.text = e.numberOfRounds.toString();
      _executionTimeController.text = e.executionTime.toString();
      _evaluationTimeController.text = e.evaluationTime.toString();
      _rotationTimeController.text = e.rotationTime.toString();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Exercise Name
                  Expanded(
                    child: TextFormField(
                      autofocus: true,
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: localizations.exerciseName,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? localizations.pleaseEnterAName
                          : null,
                    ),
                  ),

                  SizedBox(width: 16.0),

                  // Start Time Picker
                  Expanded(
                    child: GestureDetector(
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
                  ),
                ],
              ),

              SizedBox(height: 16.0),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Execution Time
                  Expanded(
                    child: TextFormField(
                      controller: _executionTimeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.executionTime,
                      ),
                      validator: (value) => _isValidNumber(value)
                          ? null
                          : localizations.pleaseEnterAValidTime,
                    ),
                  ),

                  SizedBox(width: 16.0),

                  // Evaluation Time
                  Expanded(
                    child: TextFormField(
                      controller: _evaluationTimeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.evaluationTime,
                      ),
                      validator: (value) => _isValidNumber(value)
                          ? null
                          : localizations.pleaseEnterAValidTime,
                    ),
                  ),

                  SizedBox(width: 16.0),

                  // Rotation Time
                  Expanded(
                    child: TextFormField(
                      controller: _rotationTimeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.rotationTime,
                      ),
                      validator: (value) => _isValidNumber(value)
                          ? null
                          : localizations.pleaseEnterAValidTime,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.0),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Number of Rounds
                  Expanded(
                    child: TextFormField(
                      controller: _numberOfRoundsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.numberOfRounds,
                      ),
                      validator: (value) {
                        if (_isValidNumber(value)) {
                          if (_isValidNumber(_numberOfTeamsController.text)) {
                            return int.parse(_numberOfTeamsController.text) >
                                    int.parse(value!)
                                ? localizations.mustBeEqualToOrLessThanNumberOf(
                                    localizations.team(2).toLowerCase(),
                                  )
                                : null;
                          }
                        }
                        return localizations.pleaseEnterAValidNumber;
                      },
                    ),
                  ),

                  SizedBox(width: 16.0),

                  // Number of Teams
                  Expanded(
                    child: TextFormField(
                      controller: _numberOfTeamsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.numberOfTeams,
                      ),
                      validator: (value) {
                        if (_isValidNumber(value)) {
                          if (_isValidNumber(_numberOfRoundsController.text)) {
                            return int.parse(_numberOfRoundsController.text) <
                                    int.parse(value!)
                                ? localizations.mustBeEqualToOrLessThanNumberOf(
                                    localizations.round(2).toLowerCase(),
                                  )
                                : null;
                          }
                        }
                        return localizations.pleaseEnterAValidNumber;
                      },
                    ),
                  ),
                ],
              ),
            ],
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
  void _saveExercise() {
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
      final numberOfRounds = int.parse(_numberOfRoundsController.text);
      final executionTime = int.parse(_executionTimeController.text);
      final evaluationTime = int.parse(_evaluationTimeController.text);
      final rotationTime = int.parse(_rotationTimeController.text);

      // Generate exercise with user input
      final newExercise = ExerciseX.generateSchedule(
        name: name,
        startTime: _startTime,
        uuid: widget.exercise?.uuid,
        numberOfTeams: numberOfTeams,
        numberOfRounds: numberOfRounds,
        executionTime: executionTime,
        evaluationTime: evaluationTime,
        rotationTime: rotationTime,
        stations: widget.exercise?.stations ?? [],
        localizations: AppLocalizations.of(context)!,
      );

      // Return the exercise to the previous screen
      Navigator.of(context).pop(newExercise);
    }
  }

  bool _isValidNumber(String? value) {
    return value != null && int.tryParse(value) != null && int.parse(value) > 0;
  }

  @override
  void dispose() {
    _numberOfRoundsController.dispose();
    _numberOfTeamsController.dispose();
    _nameController.dispose();
    _evaluationTimeController.dispose();
    _rotationTimeController.dispose();
    _executionTimeController.dispose();
    super.dispose();
  }
}
