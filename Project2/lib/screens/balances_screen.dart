import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class BalancesScreen extends StatelessWidget {
  const BalancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.balancesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppState>().loadBalances();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your WIC Benefits'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: !app.balancesLoaded
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _buildBalancesList(context, app),
    );
  }

  Widget _buildBalancesList(BuildContext context, AppState app) {
    final balanceEntries = app.balances.entries.toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.red.shade50, Colors.white],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: balanceEntries.length,
        itemBuilder: (context, index) {
          final entry = balanceEntries[index];
          final category = entry.key;
          final allowed = entry.value['allowed'] ?? 0;
          final used = entry.value['used'] ?? 0;
          final remaining = allowed - used;

          final fractionUsed = (allowed == 0) ? 0.0 : used / allowed;

          // Determine status and color
          Color statusColor;
          IconData statusIcon;
          String statusText;

          if (remaining == 0) {
            statusColor = Colors.red.shade700;
            statusIcon = Icons.cancel_outlined;
            statusText = 'Limit Reached';
          } else if (fractionUsed > 0.8) {
            statusColor = Colors.red.shade400;
            statusIcon = Icons.warning_amber_rounded;
            statusText = 'Low';
          } else if (used == 0) {
            statusColor = Colors.grey.shade600;
            statusIcon = Icons.info_outline;
            statusText = 'Unused';
          } else {
            statusColor = Colors.red.shade600;
            statusIcon = Icons.check_circle_outline;
            statusText = 'Available';
          }

          return Card(
            elevation: 2.0,
            margin: const EdgeInsets.only(bottom: 10.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with Category and Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            category,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: statusColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Compact Usage Statistics
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactStatBox(
                            context,
                            'Used',
                            used.toString(),
                            Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactStatBox(
                            context,
                            'Left',
                            remaining.toString(),
                            statusColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactStatBox(
                            context,
                            'Total',
                            allowed.toString(),
                            Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Compact Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: fractionUsed,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(fractionUsed * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactStatBox(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
