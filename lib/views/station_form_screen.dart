import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/position_form_field.dart';

class StationFormScreen extends StatefulWidget {
  const StationFormScreen({
    super.key,
    required this.station,
    this.markers = const [],
  });

  final Station station;
  final List<(Object, String, LatLng)> markers;

  @override
  State<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends State<StationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  LatLng? _position;

  // Form field controllers
  final TextEditingController _nameController = TextEditingController(
    text: "Station",
  );
  final TextEditingController _descriptionController = TextEditingController(
    text: "",
  );

  @override
  void initState() {
    _nameController.text = widget.station.name;
    _descriptionController.text = widget.station.description?.toString() ?? "";
    _position = widget.station.position;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.editStation),
        actions: [
          ElevatedButton(
            onPressed: _saveStation,
            child: Text(localizations.save),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  // Exercise Name
                  Expanded(
                    child: TextFormField(
                      autofocus: true,
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: localizations.stationName,
                        hintText: localizations.stationNameHint,
                      ),
                      validator: (value) =>
                          value != null && value.trim().isNotEmpty
                          ? null
                          : localizations.pleaseEnterAName,
                    ),
                  ),

                  SizedBox(width: 8),

                  // Position
                  SizedBox(
                    width: 230,
                    child: Container(
                      decoration: BoxDecoration(
                        border: BoxBorder.all(color: Colors.grey.shade700),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0).copyWith(left: 8.0),
                        child: PositionFormField(
                          initialValue: _position,
                          markers: widget.markers,
                          onSaved: (position) => _position = position,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 15,
                decoration: InputDecoration(
                  labelText: localizations.stationDescription,
                  hintText: localizations.stationDescriptionHint,
                  hintMaxLines: 10,
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveStation() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState!.save();
      final name = _nameController.text.trim();
      final description = _descriptionController.text;

      final newStation = widget.station.copyWith(
        name: name,
        position: _position,
        description: description.isEmpty ? null : description,
      );

      Navigator.of(context).pop(newStation);
    }
  }
}
