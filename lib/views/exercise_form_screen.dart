import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/widgets/adaptive_time_picker.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/optional_field_sections.dart';

/// Optional addable markdown sections on [Exercise] (DESIGN-004).
enum _ExerciseSection {
  method,
  learningGoals,
  trainingFocus,
  orderFormat,
  executionTips,
  comms,
}

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

  final Map<_ExerciseSection, TextEditingController> _sectionControllers = {
    for (final s in _ExerciseSection.values) s: TextEditingController(),
  };
  final Map<_ExerciseSection, FocusNode> _sectionFocusNodes = {
    for (final s in _ExerciseSection.values) s: FocusNode(),
  };
  final Set<_ExerciseSection> _activeSections = {};

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
      _seedSection(_ExerciseSection.method, e.methodMd);
      _seedSection(_ExerciseSection.learningGoals, e.learningGoalsMd);
      _seedSection(_ExerciseSection.trainingFocus, e.trainingFocusMd);
      _seedSection(_ExerciseSection.orderFormat, e.orderFormatMd);
      _seedSection(_ExerciseSection.executionTips, e.executionTipsMd);
      _seedSection(_ExerciseSection.comms, e.commsMd);
    } else {
      _numberOfStationsController.text = _numberOfTeamsController.text;
    }
    super.initState();
  }

  void _seedSection(_ExerciseSection section, String? value) {
    if (value == null) return;
    _activeSections.add(section);
    _sectionControllers[section]!.text = value;
  }

  void _addSection(_ExerciseSection section) {
    setState(() => _activeSections.add(section));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sectionFocusNodes[section]?.requestFocus();
    });
  }

  void _removeSection(_ExerciseSection section) {
    setState(() {
      _activeSections.remove(section);
      _sectionControllers[section]?.clear();
    });
  }

  String _labelFor(_ExerciseSection section, AppLocalizations l) =>
      switch (section) {
        _ExerciseSection.method => l.briefSectionExerciseMethod,
        _ExerciseSection.learningGoals => l.briefSectionExerciseLearningGoals,
        _ExerciseSection.trainingFocus => l.briefSectionExerciseTrainingFocus,
        _ExerciseSection.orderFormat => l.briefSectionExerciseOrderFormat,
        _ExerciseSection.executionTips => l.briefSectionExerciseExecutionTips,
        _ExerciseSection.comms => l.briefSectionExerciseComms,
      };

  String? _readSection(_ExerciseSection section) {
    if (!_activeSections.contains(section)) return null;
    final value = _sectionControllers[section]!.text.trim();
    return value.isEmpty ? null : value;
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
      body: DismissKeyboard(
        child: SafeArea(
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

                  // Time fields. The three duration fields (execution,
                  // evaluation, rotation) always share one row — they are
                  // short minute values, mirroring the teams/stations/rounds
                  // row below. On wide layouts the start-time picker joins
                  // them on the same row; on narrow it sits on its own row
                  // above so the duration labels keep enough width to read.
                  _buildTimeSection(context, localizations),

                  SizedBox(height: 16.0),

                  if (_legacyOversizedCounters) ...[
                    MaterialBanner(
                      content: Text(
                        localizations.legacyOversizedExerciseNotice,
                      ),
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
                                    int.parse(
                                      _numberOfStationsController.text,
                                    )) {
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

                  const Divider(height: 32),

                  OptionalFieldSections<_ExerciseSection>(
                    sections: [
                      for (final section in _ExerciseSection.values)
                        OptionalFieldSection<_ExerciseSection>(
                          id: section,
                          label: _labelFor(section, localizations),
                          controller: _sectionControllers[section]!,
                          focusNode: _sectionFocusNodes[section],
                        ),
                    ],
                    activeIds: _activeSections,
                    onAdd: _addSection,
                    onRemove: _removeSection,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lays out the start-time picker and the three duration fields. Above
  /// [_kTimeRowThreshold] of available width all four share a single row;
  /// below it the start-time picker moves to its own row above the three
  /// duration fields so the floating labels keep enough width to render.
  static const double _kTimeRowThreshold = 560.0;

  Widget _buildTimeSection(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final startField = _buildStartTimeField(context, localizations);
        final durations = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDurationField(
                controller: _executionTimeController,
                label: localizations.executionTime,
                localizations: localizations,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: _buildDurationField(
                controller: _evaluationTimeController,
                label: localizations.evaluationTime,
                localizations: localizations,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: _buildDurationField(
                controller: _rotationTimeController,
                label: localizations.rotationTime,
                localizations: localizations,
              ),
            ),
          ],
        );

        if (constraints.maxWidth >= _kTimeRowThreshold) {
          // Four equal columns: start picker (flex 1) + the three-field
          // duration row (flex 3, each child 1/3 of that → all four equal).
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: startField),
              const SizedBox(width: 16.0),
              Expanded(flex: 3, child: durations),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            startField,
            const SizedBox(height: 16.0),
            durations,
          ],
        );
      },
    );
  }

  /// Start-time picker styled as a tappable field so it aligns with the
  /// sibling duration [TextFormField]s on the shared row.
  Widget _buildStartTimeField(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return InkWell(
      onTap: _pickStartTime,
      borderRadius: BorderRadius.circular(4.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: localizations.startTime,
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          // ADR-0037: themed bodyLarge instead of a hardcoded size.
          _startTime.formal(),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildDurationField({
    required TextEditingController controller,
    required String label,
    required AppLocalizations localizations,
  }) {
    return TextFormField(
      controller: controller,
      // Whole minutes only: digits keyboard plus an input formatter that
      // drops anything non-numeric, so the field can never hold a value the
      // validator would reject. The validator still guards paste/edge cases.
      keyboardType: const TextInputType.numberWithOptions(
        decimal: false,
        signed: false,
      ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          _isValidNumber(value) ? null : localizations.pleaseEnterAValidTime,
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await pickAdaptiveTime(context, initialTime: _startTime);
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
      final localizations = context.l10n;

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
          final confirmed = await confirmDestructive(
            context,
            title: localizations.confirmReduceStationsTitle,
            message: localizations.confirmReduceStationsBody(
              existingExercise.stations.length - numberOfStations,
            ),
            confirmLabel: localizations.yes,
          );
          if (!mounted) return;
          if (!confirmed) {
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

      // generateSchedule rebuilds the Exercise from its scalar inputs, so any
      // field not derived from those inputs is dropped unless we put it back
      // via copyWith. The sidecar markdown brief fields (outside JSON per
      // ADR-0022) and the ordering index (ADR-0035) are both rebuild-agnostic:
      // preserve the existing index on edit so the exercise keeps its place in
      // the list; a new exercise keeps the default and gets its index assigned
      // on save.
      final withBrief = newExercise.copyWith(
        index: existingExercise?.index ?? newExercise.index,
        methodMd: _readSection(_ExerciseSection.method),
        learningGoalsMd: _readSection(_ExerciseSection.learningGoals),
        trainingFocusMd: _readSection(_ExerciseSection.trainingFocus),
        orderFormatMd: _readSection(_ExerciseSection.orderFormat),
        executionTipsMd: _readSection(_ExerciseSection.executionTips),
        commsMd: _readSection(_ExerciseSection.comms),
      );

      // Return the exercise to the previous screen
      Navigator.of(context).pop(withBrief);
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
    for (final c in _sectionControllers.values) {
      c.dispose();
    }
    for (final f in _sectionFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }
}
