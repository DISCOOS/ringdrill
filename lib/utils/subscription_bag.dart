import 'dart:async';

import 'package:flutter/widgets.dart';

mixin SubscriptionBag<T extends StatefulWidget> on State<T> {
  final _subscriptions = <StreamSubscription<dynamic>>[];

  void listen<S>(Stream<S> stream, void Function(S) onData) {
    _subscriptions.add(stream.listen(onData));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
