import 'package:flutter/material.dart';
import '../maoyan_service.dart';
import '../movie_model.dart';
import '../core/api_exception.dart';
import 'cinema_detail_page.dart';

class MovieDetailPage extends StatefulWidget {
  final int movieId;
  final String title;

  const MovieDetailPage({
    super.key,
    required this.movieId,
    required this.title,
  });

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late MaoyanService _maoyanService;
  MovieDetailModel? _movie;
  List<CinemaModel> _cinemas = [];
  bool _isLoading = true;
  bool _isCinemasLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _maoyanService = MaoyanService();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final movie = await _maoyanService.getMovieDetail(widget.movieId);
      setState(() {
        _movie = movie;
        _isLoading = false;
      });

      // 只有成功获取电影详情后才获取影院
      if (movie != null) {
        _fetchCinemas();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e is ApiException ? e.message : '加载失败';
      });
    }
  }

  Future<void> _fetchCinemas() async {
    setState(() => _isCinemasLoading = true);
    try {
      final cinemas = await _maoyanService.getCinemasForMovie(
        movieId: widget.movieId,
      );
      setState(() {
        _cinemas = cinemas;
        _isCinemasLoading = false;
      });
    } catch (e) {
      setState(() => _isCinemasLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchData, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_movie == null) {
      return const Center(child: Text('暂无电影详情'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section with poster and basic info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _movie!.img,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          width: 120,
                          height: 180,
                          color: Colors.grey[400],
                        ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _movie!.nm,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '评分: ${_movie!.sc}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('类别: ${_movie!.cat}'),
                      const SizedBox(height: 4),
                      Text('地区: ${_movie!.src}'),
                      const SizedBox(height: 4),
                      Text('时长: ${_movie!.dur}分钟'),
                      const SizedBox(height: 4),
                      Text('上映: ${_movie!.rt}'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cast section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '主演',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_movie!.star),
              ],
            ),
          ),

          // Story section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '剧情简介',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_movie!.dra, style: const TextStyle(height: 1.5)),
              ],
            ),
          ),

          // Cinemas section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '正在上映的影院',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_isCinemasLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_cinemas.isEmpty)
                  const Text('暂无影院排片信息')
                else
                  ..._cinemas
                      .take(10)
                      .map((cinema) => _buildCinemaItem(cinema)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinemaItem(CinemaModel cinema) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        title: Text(
          cinema.nm,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(cinema.addr, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              '起步价: ¥${cinema.sellPrice}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CinemaDetailPage(
                    cinemaId: cinema.id,
                    cinemaName: cinema.nm,
                  ),
            ),
          );
        },
      ),
    );
  }
}
