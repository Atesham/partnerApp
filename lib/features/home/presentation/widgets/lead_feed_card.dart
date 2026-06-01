import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/lead_model.dart';

class LeadFeedCard extends StatelessWidget {
  final LeadModel lead;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  const LeadFeedCard({
    super.key, required this.lead, required this.onAccept, required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.border.withOpacity(0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAccept,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.recycling_rounded, color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lead.areaName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(_timeAgo(lead.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${lead.estimatedPayout.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                      const Text('est. payout', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ]),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: AppTheme.divider),
                const SizedBox(height: 14),

                // Details row
                Row(
                  children: [
                    _chip(Icons.social_distance_rounded, '2.3 km', AppTheme.info),
                    const SizedBox(width: 8),
                    _chip(Icons.scale_rounded, '~${lead.estimatedWeight.toStringAsFixed(0)} kg', AppTheme.warning),
                    const SizedBox(width: 8),
                    _chip(Icons.schedule_rounded, lead.pickupSlot.length > 10 ? 'Today' : lead.pickupSlot, AppTheme.textSecondary),
                  ],
                ),

                const SizedBox(height: 12),

                // Category chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: lead.scrapCategories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                        child: Text(cat, style: const TextStyle(color: AppTheme.primaryDark, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    )).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onIgnore,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(0, 44), padding: EdgeInsets.zero,
                        ),
                        child: const Text('Ignore', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(0, 44), padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.flash_on_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Accept Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
