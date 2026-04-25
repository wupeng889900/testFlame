class MovieModel {
  final int id;
  final String nm; // 电影名称
  final String img; // 图片 URL
  final String sc; // 评分
  final String star; // 主演
  final String showInfo; // 上映信息
  final String rt; // 上映日期

  MovieModel({
    required this.id,
    required this.nm,
    required this.img,
    required this.sc,
    required this.star,
    required this.showInfo,
    required this.rt,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    // 适配不同的接口字段名 (nm/name, img/poster, sc/score)
    String nm = json['nm'] ?? json['name'] ?? '未知电影';
    String imageUrl = json['img'] ?? json['poster'] ?? '';
    String sc = json['sc']?.toString() ?? json['score']?.toString() ?? '0.0';
    String rt = json['rt'] ?? json['release'] ?? '';
    String showInfo = json['showInfo'] ?? json['pubDesc'] ?? json['catogary'] ?? '';

    // 处理图片 URL 占位符
    if (imageUrl.contains('/w.h/')) {
      imageUrl = imageUrl.replaceAll('/w.h/', '/170.230/');
    }

    return MovieModel(
      id: json['id'] ?? 0,
      nm: nm,
      img: imageUrl,
      sc: sc,
      star: json['star'] ?? '',
      showInfo: showInfo,
      rt: rt,
    );
  }
}

class CinemaModel {
  final int id;
  final String nm; // 影院名称
  final String addr; // 地址
  final String sellPrice; // 起步价
  final String dist; // 距离 (如果有)

  CinemaModel({
    required this.id,
    required this.nm,
    required this.addr,
    required this.sellPrice,
    this.dist = '',
  });

  factory CinemaModel.fromJson(Map<String, dynamic> json) {
    return CinemaModel(
      id: json['id'] ?? 0,
      nm: json['nm'] ?? '',
      addr: json['addr'] ?? '',
      sellPrice: json['sellPrice']?.toString() ?? '0',
      dist: json['dist'] ?? '',
    );
  }
}

class CinemaDetailModel {
  final int id;
  final String nm;
  final String addr;
  final String tel;
  final List<String> featureTags;

  CinemaDetailModel({
    required this.id,
    required this.nm,
    required this.addr,
    required this.tel,
    required this.featureTags,
  });

  factory CinemaDetailModel.fromJson(Map<String, dynamic> json) {
    List<String> tags = [];
    if (json['featureTags'] != null) {
      final List<dynamic> tagData = json['featureTags'];
      tags = tagData.map((t) => t['tag']?.toString() ?? '').where((t) => t.isNotEmpty).toList();
    }

    return CinemaDetailModel(
      id: json['id'] ?? 0,
      nm: json['nm'] ?? '',
      addr: json['addr'] ?? '',
      tel: json['tel'] ?? '',
      featureTags: tags,
    );
  }
}

class MovieDetailModel {
  final int id;
  final String nm; // 电影名称
  final String img; // 图片 URL
  final String sc; // 评分
  final String dra; // 剧情简介
  final String cat; // 类别
  final String star; // 主演
  final String rt; // 上映日期
  final String src; // 地区
  final String dur; // 时长

  MovieDetailModel({
    required this.id,
    required this.nm,
    required this.img,
    required this.sc,
    required this.dra,
    required this.cat,
    required this.star,
    required this.rt,
    required this.src,
    required this.dur,
  });

  factory MovieDetailModel.fromJson(Map<String, dynamic> json) {
    String imageUrl = json['img'] ?? '';
    if (imageUrl.contains('/w.h/')) {
      imageUrl = imageUrl.replaceAll('/w.h/', '/170.230/');
    }

    return MovieDetailModel(
      id: json['id'] ?? 0,
      nm: json['nm'] ?? '',
      img: imageUrl,
      sc: json['sc']?.toString() ?? '0.0',
      dra: json['dra'] ?? '暂无简介',
      cat: json['cat'] ?? '',
      star: json['star'] ?? '',
      rt: json['rt'] ?? '',
      src: json['src'] ?? '',
      dur: json['dur']?.toString() ?? '',
    );
  }
}

