import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/earning_model.dart';

/// Tracks delivery-agent earnings and payouts in Cloud Firestore.
///
/// Each delivered order produces an [EarningModel] record in the `earnings`
/// collection, keyed by the agent. The service exposes a live stream of an
/// agent's history plus aggregate totals over an optional date range.
///
/// All Firestore calls are wrapped in try/catch and rethrow a descriptive
/// [Exception] so UI layers can surface a graceful message. Date filtering for
/// totals is done client-side to avoid requiring a composite Firestore index.
class EarningsService {
  final FirebaseFirestore _firestore;

  EarningsService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Persists a single earning / payout record.
  ///
  /// Note: Normal delivery earnings are created automatically and securely by
  /// the trusted backend Cloud Function upon order delivery. This method is
  /// retained for admin payouts, manual adjustments, or testing.
  Future<void> logEarning(EarningModel earning) async {
    try {
      await _firestore
          .collection('earnings')
          .doc(earning.id)
          .set(earning.toFirestore());
    } catch (e) {
      throw Exception('Failed to log earning for order ${earning.orderId}: $e');
    }
  }

  /// Live stream of a specific agent's earnings, newest first.
  Stream<List<EarningModel>> getAgentEarnings(String agentId) {
    if (agentId.trim().isEmpty) {
      return Stream.value(const []);
    }
    return _firestore
        .collection('earnings')
        .where('agentId', isEqualTo: agentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => EarningModel.fromFirestore(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)))
        .handleError((e) =>
            throw Exception('Failed to load earnings for agent $agentId: $e'));
  }

  /// Sums the agent's take within an optional [startDate]/[endDate] window.
  ///
  /// The agent's earnings are `amountEarned + tipAmount`; [deliveryFee] is
  /// tracked separately and excluded from the total. Returns `0.0` when there
  /// are no matching records.
  Future<double> getTotalEarnings(
    String agentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (agentId.trim().isEmpty) {
      return 0.0;
    }
    try {
      final snap = await _firestore
          .collection('earnings')
          .where('agentId', isEqualTo: agentId)
          .get();

      final earnings = snap.docs
          .map((d) => EarningModel.fromFirestore(d.data(), d.id))
          .where((e) {
        if (startDate != null && e.timestamp.isBefore(startDate)) return false;
        if (endDate != null && e.timestamp.isAfter(endDate)) return false;
        return true;
      });

      var total = 0.0;
      for (final e in earnings) {
        total += e.amountEarned + e.tipAmount;
      }
      return total;
    } catch (e) {
      throw Exception(
          'Failed to calculate total earnings for agent $agentId: $e');
    }
  }
}

/// Provides a singleton [EarningsService].
final earningsServiceProvider =
    Provider<EarningsService>((ref) => EarningsService());

/// Convenience Riverpod stream of an agent's earnings history.
final agentEarningsStreamProvider =
    StreamProvider.family<List<EarningModel>, String>((ref, agentId) {
  return ref.watch(earningsServiceProvider).getAgentEarnings(agentId);
});
