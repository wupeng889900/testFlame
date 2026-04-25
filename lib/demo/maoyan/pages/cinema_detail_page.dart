import 'package:flutter/material.dart';
import '../maoyan_service.dart';
import '../movie_model.dart';

class CinemaDetailPage extends StatefulWidget {
  final int cinemaId;
  final String cinemaName;

  const CinemaDetailPage({
    super.key,
    required this.cinemaId,
    required this.cinemaName,
  });

  @override
  State<CinemaDetailPage> createState() => _CinemaDetailPageState();
}

class _CinemaDetailPageState extends State<CinemaDetailPage> {
  late MaoyanService _maoyanService;
  CinemaDetailModel? _cinema;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _maoyanService = MaoyanService();
    _fetchCinemaDetail();
  }

  Future<void> _fetchCinemaDetail() async {
    setState(() => _isLoading = true);
    try {
      final cinema = await _maoyanService.getCinemaDetail(widget.cinemaId);
      setState(() {
        _cinema = cinema;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cinemaName),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cinema == null) {
      return const Center(child: Text('暂无影院详情'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _cinema!.nm,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _cinema!.addr,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(_cinema!.tel, style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '影院特色',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cinema!.featureTags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                tag,
                style: TextStyle(color: Colors.red[900], fontSize: 12),
              ),
            )).toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('在线选座 (Demo)'),
            ),
          ),
        ],
      ),
    );
  }
}
