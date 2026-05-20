import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/services/shared_file_channel.dart';
import 'package:universal_io/io.dart';

class SharedFileWidget extends StatefulWidget {
  const SharedFileWidget({super.key, required this.child});

  final Widget child;

  @override
  State<SharedFileWidget> createState() => _SharedFileWidgetState();
}

class _SharedFileWidgetState extends State<SharedFileWidget> {
  final handled = <File>[];
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SharedFileChannel().files,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _handleDrillFile(snapshot.data!);
        }
        return widget.child;
      },
    );
  }

  void _handleDrillFile(File file) {
    if (file.path.endsWith('.drill')) {
      if (handled.contains(file)) return;
      handled.add(file);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Show bottom sheet for remote file
        GoRouter.of(context).go(path.normalize('/o/${file.path}'));
      });
    }
  }
}
