class EmotionMapping {
  static const List<String> emotions = [
    'happy',
    'shy',
    'angry',
    'sad',
    'surprised',
    'neutral',
  ];

  static const Map<String, String> displayNames = {
    'happy': '开心',
    'shy': '害羞',
    'angry': '生气',
    'sad': '难过',
    'surprised': '惊讶',
    'neutral': '平静',
  };

  static const Map<String, String> emojis = {
    'happy': '😊',
    'shy': '😳',
    'angry': '😠',
    'sad': '😢',
    'surprised': '😲',
    'neutral': '😐',
  };

  /// Live2D Cubism expression parameters for each emotion.
  /// These maps define which parameters to set for the live2d model.
  static const Map<String, Map<String, double>> expressionParams = {
    'happy': {
      'ParamMouthForm': 0.8,
      'ParamEyeLOpen': 0.9,
      'ParamEyeROpen': 0.9,
      'ParamBrowLY': 0.3,
      'ParamBrowRY': 0.3,
      'ParamMouthOpenY': 0.4,
      'ParamCheek': 0.6,
    },
    'shy': {
      'ParamMouthForm': 0.3,
      'ParamEyeLOpen': 0.6,
      'ParamEyeROpen': 0.6,
      'ParamBrowLY': 0.5,
      'ParamBrowRY': 0.5,
      'ParamMouthOpenY': 0.1,
      'ParamCheek': 0.8,
      'ParamEyeBallX': 0.2,
      'ParamEyeBallY': 0.2,
    },
    'angry': {
      'ParamMouthForm': -0.5,
      'ParamEyeLOpen': 0.8,
      'ParamEyeROpen': 0.8,
      'ParamBrowLY': -0.6,
      'ParamBrowRY': -0.6,
      'ParamMouthOpenY': 0.2,
      'ParamCheek': 0.0,
    },
    'sad': {
      'ParamMouthForm': -0.3,
      'ParamEyeLOpen': 0.5,
      'ParamEyeROpen': 0.5,
      'ParamBrowLY': 0.6,
      'ParamBrowRY': 0.6,
      'ParamMouthOpenY': 0.0,
      'ParamCheek': 0.0,
      'ParamEyeBallY': -0.3,
    },
    'surprised': {
      'ParamMouthForm': 0.2,
      'ParamEyeLOpen': 1.0,
      'ParamEyeROpen': 1.0,
      'ParamBrowLY': -0.4,
      'ParamBrowRY': -0.4,
      'ParamMouthOpenY': 0.7,
      'ParamCheek': 0.2,
    },
    'neutral': {
      'ParamMouthForm': 0.0,
      'ParamEyeLOpen': 0.7,
      'ParamEyeROpen': 0.7,
      'ParamBrowLY': 0.0,
      'ParamBrowRY': 0.0,
      'ParamMouthOpenY': 0.0,
      'ParamCheek': 0.0,
      'ParamEyeBallX': 0.0,
      'ParamEyeBallY': 0.0,
    },
  };

  /// Returns the Live2D expression parameters for the given [emotion].
  /// Defaults to 'neutral' if the emotion is not found.
  static Map<String, double> getParams(String emotion) {
    return Map<String, double>.from(
      expressionParams[emotion] ?? expressionParams['neutral']!,
    );
  }

  /// Returns the Chinese display name for the given [emotion].
  static String getDisplayName(String emotion) {
    return displayNames[emotion] ?? emotion;
  }

  /// Returns the emoji icon for the given [emotion].
  static String getEmoji(String emotion) {
    return emojis[emotion] ?? '😐';
  }

  /// Validates whether [emotion] is in the supported emotions list.
  static bool isValidEmotion(String emotion) {
    return emotions.contains(emotion);
  }

  /// Returns the closest matching emotion from a given string,
  /// useful for fuzzy matching from AI responses.
  static String closestMatch(String text) {
    final lower = text.toLowerCase();
    for (final emotion in emotions) {
      if (lower.contains(emotion)) {
        return emotion;
      }
    }
    return 'neutral';
  }
}
