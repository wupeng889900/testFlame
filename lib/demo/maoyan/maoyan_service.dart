import 'core/api_client.dart';
import 'movie_model.dart';

class MaoyanService {
  final ApiClient _client;
  // 使用目前国内公认比较稳定的 netstart 镜像
  static const String defaultBaseUrl = 'https://apis.netstart.cn/maoyan';

  MaoyanService({String? baseUrl})
    : _client = ApiClient(baseUrl: baseUrl ?? defaultBaseUrl);

  /// 获取正在热映列表 (包含前 100 条)
  Future<List<MovieModel>> getHotMovies({int limit = 100}) async {
    try {
      final response = await _client.get('/index/movieOnInfoList');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        List<MovieModel> allMovies = [];

        if (data['movieList'] != null) {
          final List<dynamic> movieData = data['movieList'];
          allMovies.addAll(movieData.map((m) => MovieModel.fromJson(m)));
        }

        final List<dynamic>? movieIds = data['movieIds'];
        if (allMovies.length < limit &&
            movieIds != null &&
            movieIds.length > allMovies.length) {
          // 接口限制：moreComingList 单次最多只能请求 10 个 ID
          final remainingIds = movieIds.sublist(
            allMovies.length,
            movieIds.length > limit ? limit : movieIds.length,
          );

          // 分片请求，每组 10 个
          for (var i = 0; i < remainingIds.length; i += 10) {
            final chunk = remainingIds.sublist(
              i,
              (i + 10) > remainingIds.length ? remainingIds.length : (i + 10),
            );

            if (chunk.isNotEmpty) {
              try {
                final moreResponse = await _client.get(
                  '/index/moreComingList',
                  queryParameters: {'movieIds': chunk.join(',')},
                );

                if (moreResponse.statusCode == 200 &&
                    moreResponse.data['coming'] != null) {
                  final List<dynamic> moreMovieData =
                      moreResponse.data['coming'];
                  allMovies.addAll(
                    moreMovieData.map((m) => MovieModel.fromJson(m)),
                  );
                }
              } catch (e) {
                print('Chunk fetch error: $e');
                // 个别分片失败继续拉取下一个分片
              }
            }
          }
        }

        return allMovies.take(limit).toList();
      }
      return [];
    } catch (e) {
      print('Maoyan fetch error: $e');
      rethrow;
    }
  }

  /// 搜索电影
  Future<List<MovieModel>> searchMovies(String keyword) async {
    try {
      final response = await _client.get(
        '/search/movies',
        queryParameters: {'keyword': keyword, 'ci': 1},
      );

      if (response.statusCode == 200) {
        final dynamic data = response.data;
        // 搜索结果在 data['value'] 数组中
        if (data is Map && data['value'] != null) {
          final List<dynamic> list = data['value'];
          return list.map((m) => MovieModel.fromJson(m)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Maoyan search error: $e');
      return [];
    }
  }

  /// 获取电影详情
  Future<MovieDetailModel?> getMovieDetail(int movieId) async {
    try {
      final response = await _client.get(
        '/movie/detail',
        queryParameters: {'movieId': movieId},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        if (data['movie'] != null) {
          return MovieDetailModel.fromJson(data['movie']);
        }
      }
      return null;
    } catch (e) {
      print('Maoyan detail fetch error: $e');
      rethrow;
    }
  }

  /// 获取上映该电影的影院列表
  Future<List<CinemaModel>> getCinemasForMovie({
    required int movieId,
    int cityId = 1,
    String? showDate,
  }) async {
    try {
      final date = showDate ?? DateTime.now().toString().split(' ')[0];
      final response = await _client.get(
        '/movie/select/cinemas',
        queryParameters: {
          'movieId': movieId,
          'cityId': cityId,
          'showDate': date,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        if (data['cinemas'] != null) {
          final List<dynamic> cinemaData = data['cinemas'];
          return cinemaData.map((c) => CinemaModel.fromJson(c)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Maoyan cinemas fetch error: $e');
      return [];
    }
  }

  /// 获取影院详情
  Future<CinemaDetailModel?> getCinemaDetail(int cinemaId) async {
    try {
      final response = await _client.get(
        '/cinema/detail',
        queryParameters: {'cinemaId': cinemaId},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        if (data['cinemaDetail'] != null) {
          return CinemaDetailModel.fromJson(data['cinemaDetail']);
        }
      }
      return null;
    } catch (e) {
      print('Maoyan cinema detail error: $e');
      return null;
    }
  }
}
