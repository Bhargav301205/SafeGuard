import 'dart:math';

/// Lightweight on-device ML classifier for false-positive crash reduction.
///
/// Implements inference using parameters trained in `ml/train_classifier.py`.
/// Evaluates peak G-force, rotational velocity, speed drop, and post-impact
/// motion variance to distinguish genuine crashes from benign spikes (phone drops, running).
class MlCrashClassifier {
  MlCrashClassifier._();
  static final MlCrashClassifier instance = MlCrashClassifier._();

  // Trained parameters from ml/model_weights.json
  static const List<double> _means = [
    2.892,
    185.6,
    22.84,
    0.5,
  ];

  static const List<double> _stds = [
    1.2515,
    124.212,
    21.465,
    0.468,
  ];

  static const List<double> _weights = [
    1.2008,
    1.2867,
    1.2130,
    -0.9389,
  ];

  static const double _bias = -0.6659;
  static const double _threshold = 0.50;

  /// Predicts probability that the sensor snapshot is a genuine crash [0.0 - 1.0].
  double predictCrashProbability({
    required double peakG,
    double? angularVelocityDps,
    double? speedDropKmh,
    double postImpactVariance = 0.05,
  }) {
    final gyro = angularVelocityDps ?? 0.0;
    final speed = speedDropKmh ?? 0.0;

    final x0 = (peakG - _means[0]) / _stds[0];
    final x1 = (gyro - _means[1]) / _stds[1];
    final x2 = (speed - _means[2]) / _stds[2];
    final x3 = (postImpactVariance - _means[3]) / _stds[3];

    final z = (x0 * _weights[0]) +
        (x1 * _weights[1]) +
        (x2 * _weights[2]) +
        (x3 * _weights[3]) +
        _bias;

    // Sigmoid function
    return 1.0 / (1.0 + exp(-z.clamp(-15.0, 15.0)));
  }

  /// Returns true if the ML classifier confirms the event as a genuine crash.
  bool isGenuineCrash({
    required double peakG,
    double? angularVelocityDps,
    double? speedDropKmh,
    double postImpactVariance = 0.05,
  }) {
    final prob = predictCrashProbability(
      peakG: peakG,
      angularVelocityDps: angularVelocityDps,
      speedDropKmh: speedDropKmh,
      postImpactVariance: postImpactVariance,
    );
    return prob >= _threshold;
  }
}
