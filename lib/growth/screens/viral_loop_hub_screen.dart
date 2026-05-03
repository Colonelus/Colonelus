import 'package:flutter/material.dart';

import '../services/viral_loop_service.dart';

class ViralLoopHubScreen extends StatefulWidget {
  final String secretId;
  final String previewText;

  const ViralLoopHubScreen({
    super.key,
    required this.secretId,
    required this.previewText,
  });

  @override
  State<ViralLoopHubScreen> createState() => _ViralLoopHubScreenState();
}

class _ViralLoopHubScreenState extends State<ViralLoopHubScreen> {
  bool _busy = false;
  bool _claimBusy = false;
  bool _qualifyBusy = false;
  String _status = '';

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await ViralLoopService.instance.shareSecret(
        secretId: widget.secretId,
        previewText: widget.previewText,
        source: 'viral_loop_hub',
      );
      if (mounted) {
        setState(() {
          _status = 'Paylaşım hazır.';
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Paylaşım oluşturulamadı.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _claim() async {
    setState(() {
      _claimBusy = true;
      _status = '';
    });
    try {
      final ok = await ViralLoopService.instance.claimPendingShareAttribution(
        trigger: 'hub_claim',
      );
      if (mounted) {
        setState(() {
          _status = ok ? 'Davet bağlantısı işlendi.' : 'Bekleyen bağlantı bulunamadı.';
          _claimBusy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'İşlem başarısız oldu.';
          _claimBusy = false;
        });
      }
    }
  }

  Future<void> _qualify() async {
    setState(() {
      _qualifyBusy = true;
      _status = '';
    });
    try {
      final ok = await ViralLoopService.instance.qualifyPendingShareAttribution(
        trigger: 'hub_qualify',
      );
      if (mounted) {
        setState(() {
          _status = ok ? 'Ödül akışı tetiklendi.' : 'Bekleyen growth kaydı bulunamadı.';
          _qualifyBusy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Ödül akışı başlatılamadı.';
          _qualifyBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Büyüme Motoru'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Text(widget.previewText),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _share,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sırrı Paylaş'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _claimBusy ? null : _claim,
              child: _claimBusy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Bekleyen Linki İşle'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _qualifyBusy ? null : _qualify,
              child: _qualifyBusy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Qualified Reward Tetikle'),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Text(
                _status,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}