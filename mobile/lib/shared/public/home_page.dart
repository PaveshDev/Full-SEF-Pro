import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final role = user?.role ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.repeat, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LoopWorth',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Give Waste Another Worth',
                  style: TextStyle(fontSize: 11, color: AppColors.slateLight),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (auth.isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () {
                  if (role == 'Admin') {
                    context.go('/admin');
                  } else if (role == 'CollectionAgent') {
                    context.go('/agent');
                  } else if (role == 'Partner') {
                    context.go('/partner');
                  } else {
                    context.go('/dashboard');
                  }
                },
                icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                label: const Text(
                  'Dashboard',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            )
          else ...[
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Sign In', style: TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                onPressed: () => context.push('/register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Get Started', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'AI-Assisted Circular Economy Platform',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Transform Electronic Waste Into Sustainable Value',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slateDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'LoopWorth orchestrates an intelligent multi-agent pipeline: Advisory Item Assessment, Recovery Plan Generation, Certified Partner Matching, and Physical Collection Logistics.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.slateLight,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.push(auth.isAuthenticated ? '/items/submit' : '/register'),
                        icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                        label: const Text(
                          'Submit Waste Item',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/login'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Explore Demo Portal', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 7-Step Recovery Loop
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: Column(
                children: [
                  const Text(
                    'The LoopWorth 7-Step Recovery Workflow',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slateDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Traceable, transparent, and verified across all participants',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                  ),
                  const SizedBox(height: 24),

                  _buildStepCard('STEP 01', 'Item Submission', 'Customer submits item specs, description, brand, model, and uploads photos.', Icons.inventory_2_outlined),
                  _buildStepCard('STEP 02', 'AI Advisory Assessment', 'Agent 1 inspects item details and condition to advise Donate or Recycle.', Icons.psychology_outlined),
                  _buildStepCard('STEP 03', 'Route Selection & Prep Plan', 'Customer selects route; Agent 2 provides step-by-step preparation and safety measures.', Icons.alt_route),
                  _buildStepCard('STEP 04', 'Human Admin Approval', 'Admin reviews recovery plan with Approve, Reject, or Request Revision controls.', Icons.shield_outlined),
                  _buildStepCard('STEP 05', 'AI Partner Matching', 'Agent 3 ranks pre-filtered certified recyclers and charities; customer selects recipient.', Icons.handshake_outlined),
                  _buildStepCard('STEP 06', 'Collection Logistics', 'Agent 4 optimizes pickup window and suggests agent; Admin assigns collection agent.', Icons.local_shipping_outlined),
                  _buildStepCard('STEP 07', 'Handover & Completion', 'Collection agent marks Collected then Delivered to Partner; Partner confirms intake and automated Brevo email is sent.', Icons.verified_outlined),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: Colors.white,
              child: Center(
                child: Text(
                  'LoopWorth © ${DateTime.now().year} — Give Waste Another Worth. All rights reserved.',
                  style: const TextStyle(fontSize: 11, color: AppColors.slateLight),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(String stepNumber, String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: AppColors.slateLight, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
