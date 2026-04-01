import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ShareSheet extends StatelessWidget {
  final String shareUrl;

  const ShareSheet({super.key, required this.shareUrl});

  static void show(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ShareSheet(shareUrl: url),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Share',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Scrollable Icons Row
          Stack(
            alignment: Alignment.centerRight,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildShareOption(
                      icon: FontAwesomeIcons.whatsapp,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () => _launchUrl('https://wa.me/?text=$shareUrl'),
                    ),
                    _buildShareOption(
                      icon: FontAwesomeIcons.facebookF,
                      label: 'Facebook',
                      color: const Color(0xFF1877F2),
                      onTap: () => _launchUrl('https://www.facebook.com/sharer/sharer.php?u=$shareUrl'),
                    ),
                    _buildShareOption(
                      icon: FontAwesomeIcons.xTwitter,
                      label: 'X',
                      color: Colors.black,
                      onTap: () => _launchUrl('https://twitter.com/intent/tweet?url=$shareUrl'),
                    ),
                    _buildShareOption(
                      icon: FontAwesomeIcons.envelope,
                      label: 'Email',
                      color: Colors.grey[700]!,
                      onTap: () => _launchUrl('mailto:?body=$shareUrl'),
                    ),
                    _buildShareOption(
                      icon: FontAwesomeIcons.redditAlien,
                      label: 'Reddit',
                      color: const Color(0xFFFF4500),
                      onTap: () => _launchUrl('https://www.reddit.com/submit?url=$shareUrl'),
                    ),
                    _buildShareOption(
                      icon: FontAwesomeIcons.pinterest,
                      label: 'Pint',
                      color: const Color(0xFFE60023),
                      onTap: () => _launchUrl('https://pinterest.com/pin/create/button/?url=$shareUrl'),
                    ),
                    const SizedBox(width: 40), // Spacing for the arrow
                  ],
                ),
              ),
              // Next Arrow (Decorative to match reference)
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 24),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.chevron_right, color: Colors.black, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Link Copy Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        shareUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _copyToClipboard(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065FD4), // YouTube blue
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Copy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareOption({
    required dynamic icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FaIcon(icon as dynamic, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

