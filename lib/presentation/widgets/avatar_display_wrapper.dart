import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'avatar_display.dart' if (dart.library.html) 'avatar_display_web.dart';

// Re-export the platform-specific implementation
export 'avatar_display.dart' if (dart.library.html) 'avatar_display_web.dart';
