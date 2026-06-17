import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _messageController = TextEditingController();
  final String _supportNumber = '916379723465';
  final String _supportEmail = 'support@viyantech.com';

  Future<void> _launchWhatsApp(String message) async {
    final whatsappUrl = Uri.parse(
      'https://wa.me/$_supportNumber?text=${Uri.encodeComponent(message)}',
    );
    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _launchEmail(String subject, String body) async {
    final emailUrl = Uri.parse(
      'mailto:$_supportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(emailUrl);
    } catch (_) {}
  }

  Future<void> _launchCall() async {
    final callUrl = Uri.parse('tel:+$_supportNumber');
    try {
      await launchUrl(callUrl);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              primaryColor.withValues(alpha: 0.01),
              primaryColor.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Contact Cards
                const Text(
                  'Quick Contact',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildContactCard(
                      icon: Icons.chat_bubble_rounded,
                      label: 'WhatsApp',
                      subLabel: 'Chat now',
                      color: Colors.green,
                      onTap: () => _launchWhatsApp("Hi Viyan Billing Support, I need assistance with..."),
                    ),
                    const SizedBox(width: 12),
                    _buildContactCard(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      subLabel: 'Send query',
                      color: Colors.blue,
                      onTap: () => _launchEmail("Viyan Billing Support Request", "Describe your problem here..."),
                    ),
                    const SizedBox(width: 12),
                    _buildContactCard(
                      icon: Icons.phone_rounded,
                      label: 'Call',
                      subLabel: 'Call support',
                      color: Colors.purple,
                      onTap: _launchCall,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // FAQs Section
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                _buildFAQTile(
                  question: 'How do I add a new item?',
                  answer: 'Go to the Items tab and tap the "+ Add Item" button at the bottom right. Fill in the details and click Save.',
                ),
                _buildFAQTile(
                  question: 'How do I manage/adjust stock levels?',
                  answer: 'Open the drawer and tap on "Stock Management". You can search for any item and use the plus (+) or minus (-) buttons to quickly update the stock count.',
                ),
                _buildFAQTile(
                  question: 'Can I print invoices?',
                  answer: 'Yes, navigate to "Printer Settings" in the drawer. Connect your thermal receipt printer via Bluetooth or WiFi to print sales tickets.',
                ),
                _buildFAQTile(
                  question: 'How do I change the app language?',
                  answer: 'Go to the Profile tab, locate the "Language" preference toggle under Preferences, and switch between English (EN) and Tamil (தமிழ்).',
                ),

                const SizedBox(height: 28),

                // Submit a ticket Form
                const Text(
                  'Send us a message',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _messageController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Describe your issue or feedback...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: primaryColor, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          fillColor: Colors.grey[50],
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          final msg = _messageController.text;
                          if (msg.isNotEmpty) {
                            _launchWhatsApp("Support Request:\n\n$msg");
                            _messageController.clear();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Send via WhatsApp',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String label,
    required String subLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQTile({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          iconColor: Theme.of(context).colorScheme.primary,
          collapsedIconColor: Colors.grey[400],
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              answer,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
