import 'package:flutter/material.dart';

import 'referral_service.dart';

class EnterReferralCodeScreen extends StatefulWidget {
  const EnterReferralCodeScreen({super.key, ReferralService? service}) : _service = service;

  final ReferralService? _service;

  @override
  State<EnterReferralCodeScreen> createState() => _EnterReferralCodeScreenState();
}

class _EnterReferralCodeScreenState extends State<EnterReferralCodeScreen> {
  late final ReferralService _service;
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? ReferralService();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await _service.bindReferralCode(code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Davet kodu gir')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Davet kodu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
