import 'dart:async';

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
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _linkSubscription = SharedFileChannel().links.listen(_handleSharedLink);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

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

  void _handleSharedLink(Uri uri) {
    // No dedup guard here (unlike _handleDrillFile's `handled` list): this
    // callback is wired via StreamSubscription.listen(), which delivers each
    // native event exactly once, so there is no rebuild-multiplication risk
    // to guard against. A Set-based guard would (and did) permanently
    // blacklist a link after its first use for the life of the app process,
    // silently no-opping a legitimate re-share/reinstall of the same plan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Reuses the same /i/:slug and /o/ handling app_router.dart already
      // wires up for App Links, so a link shared via the OS share sheet
      // installs/opens exactly like tapping the link directly.
      GoRouter.of(context).go(uri.path);
    });
  }
}
