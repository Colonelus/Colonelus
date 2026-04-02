import 'package:flutter/material.dart';

import 'viral_loop_models.dart';

class SecretShareRewardBanner extends StatelessWidget {
  final SecretShareQualifyResult result;

  const SecretShareRewardBanner({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.ok || !result.rewarded) {
      return const SizedBox.shrink();
    }
    final text = result.rewardAmount > 0
        ? 'Ödül alındı: ${result.rewardAmount} ${result.rewardType}'
        : 'Ödül alındı';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.green.withValues(alpha: 0.12),
      ),
      child: Text(text),
    );
  }
}
