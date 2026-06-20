import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeepLinkNotifier extends Notifier<Uri?> {
  @override
  Uri? build() => null;

  void setUri(Uri? uri) {
    state = uri;
  }
}

final deepLinkProvider = NotifierProvider<DeepLinkNotifier, Uri?>(DeepLinkNotifier.new);
