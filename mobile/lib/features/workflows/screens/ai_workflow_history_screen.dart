import 'package:flutter/material.dart';
import '../../../../app/app_shell.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';

class AIWorkflowHistoryScreen extends StatefulWidget {
  const AIWorkflowHistoryScreen({super.key});

  @override
  State<AIWorkflowHistoryScreen> createState() => _AIWorkflowHistoryScreenState();
}

class _AIWorkflowHistoryScreenState extends State<AIWorkflowHistoryScreen> {
  final _dio = ApiClient().dio;
  List<dynamic> _workflows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkflows();
  }

  Future<void> _loadWorkflows() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/admin/workflows');
      if (mounted) {
        setState(() {
          _workflows = res.data as List;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load AI workflow history.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'AI Agent Workflows',
      action: IconButton(
        icon: const Icon(Icons.refresh, color: AppColors.slateDark),
        tooltip: 'Refresh',
        onPressed: _loadWorkflows,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWorkflows,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multi-Agent Execution Audit',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slateDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Inspect structured inputs, outputs, and status across Agents 1 to 4',
                          style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.roseLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.rose.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.rose, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 13))),
                          ],
                        ),
                      ),

                    if (_workflows.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(36),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.memory, size: 48, color: AppColors.primary),
                            SizedBox(height: 14),
                            Text(
                              'No AI workflows recorded yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slateDark),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Workflows are initiated automatically when items are submitted and progress through the agents.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.slateLight),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _workflows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final wf = _workflows[idx] as Map<String, dynamic>;
                          final steps = (wf['steps'] as List?) ?? [];
                          final itemName = wf['itemName'] ?? 'Item';
                          final itemId = (wf['itemId'] ?? '').toString();
                          final shortId = itemId.length > 8 ? '${itemId.substring(0, 8)}...' : itemId;
                          final stage = wf['currentStage'] ?? '';
                          final status = wf['status'] ?? '';
                          final dateStr = wf['createdAt'] != null
                              ? DateTime.tryParse(wf['createdAt'])?.toLocal().toString().split('.')[0] ?? ''
                              : '';

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              itemName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.slateDark,
                                              ),
                                            ),
                                            Text(
                                              'ID: $shortId',
                                              style: const TextStyle(fontSize: 11, color: AppColors.slateLight),
                                            ),
                                          ],
                                        ),
                                      ),
                                      StatusBadge(status: status),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySubtle,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          stage,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${steps.length} steps completed',
                                        style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                      ),
                                      if (dateStr.isNotEmpty)
                                        Text(
                                          '• $dateStr',
                                          style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showTraceModal(wf),
                                      icon: const Icon(Icons.visibility_outlined, size: 16),
                                      label: const Text('Inspect Trace', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showTraceModal(Map<String, dynamic> wf) {
    final steps = (wf['steps'] as List?) ?? [];
    final objective = wf['objective'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Agent Execution Trace',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slateDark,
                            ),
                          ),
                          if (objective.isNotEmpty)
                            Text(
                              'Objective: $objective',
                              style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: steps.isEmpty
                        ? const Center(
                            child: Text(
                              'No steps recorded in this workflow.',
                              style: TextStyle(color: AppColors.slateLight),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: steps.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final step = steps[i] as Map<String, dynamic>;
                              final agentName = step['agentName'] ?? 'Agent';
                              final status = step['executionStatus'] ?? '';
                              final stepName = step['stepName'] ?? '';
                              final input = step['inputSummary'];
                              final output = step['outputSummary'];
                              final error = step['errorMessage'];
                              final timeStr = step['startedAt'] != null
                                  ? DateTime.tryParse(step['startedAt'])?.toLocal().toString().split('.')[0] ?? ''
                                  : '';

                              final isSuccess = status == 'Succeeded';
                              final isFail = status == 'Failed';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          agentName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: AppColors.slateDark,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSuccess
                                                ? AppColors.emeraldLight
                                                : isFail
                                                    ? AppColors.roseLight
                                                    : AppColors.amberLight,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isSuccess
                                                  ? AppColors.emerald
                                                  : isFail
                                                      ? AppColors.rose
                                                      : AppColors.amber,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Step: $stepName • $timeStr',
                                      style: const TextStyle(fontSize: 11, color: AppColors.slateLight),
                                    ),
                                    if (input != null && input.toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Input: $input',
                                        style: const TextStyle(fontSize: 12, color: AppColors.slateLight),
                                      ),
                                    ],
                                    if (output != null && output.toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Text(
                                          'Output: $output',
                                          style: const TextStyle(fontSize: 12, color: AppColors.slateDark),
                                        ),
                                      ),
                                    ],
                                    if (error != null && error.toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.roseLight,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.rose.withAlpha(50)),
                                        ),
                                        child: Text(
                                          'Error: $error',
                                          style: const TextStyle(fontSize: 12, color: AppColors.rose),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
