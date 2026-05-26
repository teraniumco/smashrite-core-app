import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';

class ServerInfoModal extends StatelessWidget {
  final ExamServer server;
  final VoidCallback onDisconnect;

  const ServerInfoModal({
    super.key,
    required this.server,
    required this.onDisconnect,
  });

  static const _deepBlue = Color(0xFF0F2B6D);

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF3F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _deepBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dns_rounded,
                    color: _deepBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Server Info',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
                const Spacer(),
                // Active connection badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Connected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Info card ────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                _infoRow(
                  context,
                  icon: Icons.storage_rounded,
                  label: 'Server Name',
                  value: server.name,
                  isFirst: true,
                ),
                Divider(height: 1, indent: 52, color: Colors.grey.shade100),
                _infoRow(
                  context,
                  icon: Icons.language_rounded,
                  label: 'Server Domain',
                  value: server.smashriteDomain,
                  copyValue: server.smashriteDomain,
                ),
                if (server.signalStrength != null) ...[
                  Divider(height: 1, indent: 52, color: Colors.grey.shade100),
                  _infoRow(
                    context,
                    icon: Icons.signal_wifi_4_bar_rounded,
                    label: 'Signal Strength',
                    value: '${server.signalStrength}%',
                    valueColor: _signalColor(server.signalStrength!),
                    isLast: true,
                  ),
                ],
              ],
            ),
          ),

          // ── Disconnect button ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDisconnect,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Disconnect from Server'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300, width: 1.5),
                  backgroundColor: Colors.red.shade50,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(top: false, child: const SizedBox(height: 16)),
        ],
      ),
    );
  }

  Color _signalColor(int strength) {
    if (strength >= 70) return Colors.green.shade600;
    if (strength >= 40) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? copyValue,
    Color? valueColor,
    bool isFirst = false,
    bool isLast  = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _deepBlue.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: _deepBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  )),
                const SizedBox(height: 2),
                Text(value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xFF1A1A2E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (copyValue != null)
            GestureDetector(
              onTap: () => _copyToClipboard(context, copyValue, label),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.copy_rounded,
                  size: 15, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }
}