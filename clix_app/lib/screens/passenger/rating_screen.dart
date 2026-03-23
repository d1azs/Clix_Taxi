import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

/// Екран "Як пройшла поїздка?" — оцінка водія після завершення.
class RatingScreen extends StatefulWidget {
  final OrderModel order;

  const RatingScreen({super.key, required this.order});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isComplaint = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _isSubmitting = true);
    try {
      await ApiService().createReview(
        orderId: widget.order.id,
        rating: _rating,
        comment: _commentController.text.trim(),
        isComplaint: _isComplaint,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.order.driverInfo?.fullName ?? 'Водія';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            // Аватар водія
            CircleAvatar(
              radius: 40,
              backgroundColor: CLIXTheme.primary.withValues(alpha: 0.1),
              child: const Icon(
                Icons.person,
                size: 40,
                color: CLIXTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Як пройшла поїздка?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Оцініть водія $driverName',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // Зірки рейтингу
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      size: 44,
                      color: index < _rating
                          ? CLIXTheme.warning
                          : CLIXTheme.divider,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Коментар
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Залишити коментар (необов\'язково)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CLIXTheme.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Скарга
            CheckboxListTile(
              value: _isComplaint,
              onChanged: (val) => setState(() => _isComplaint = val ?? false),
              title: const Text('Це скарга'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: CLIXTheme.error,
            ),

            const Spacer(),

            // Кнопка відправки
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _rating > 0 && !_isSubmitting ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Надіслати'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
