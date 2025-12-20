class PostModel {
  final int idPost;
  final int idUser;
  final String content;
  final List<String> media;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserInfo user;
  final bool isLiked;
  final int likeCount;
  final int commentCount;

  PostModel({
    required this.idPost,
    required this.idUser,
    required this.content,
    required this.media,
    this.latitude,
    this.longitude,
    this.locationName,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      idPost: json['id_post'] as int,
      idUser: json['id_user'] as int,
      content: json['content'] as String,
      media: (json['media'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      latitude: json['latitude'] != null 
          ? (json['latitude'] as num).toDouble() 
          : null,
      longitude: json['longitude'] != null 
          ? (json['longitude'] as num).toDouble() 
          : null,
      locationName: json['location_name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
      isLiked: json['isLiked'] as bool? ?? false,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
    );
  }
}

class UserInfo {
  final int idUser;
  final String nama;
  final String username;
  final String? role;

  UserInfo({
    required this.idUser,
    required this.nama,
    required this.username,
    this.role,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      idUser: json['id_user'] as int,
      nama: json['nama'] as String,
      username: json['username'] as String,
      role: json['role'] as String?,
    );
  }
}

class CommentModel {
  final int idComment;
  final int idPost;
  final int idUser;
  final String content;
  final DateTime createdAt;
  final UserInfo user;

  CommentModel({
    required this.idComment,
    required this.idPost,
    required this.idUser,
    required this.content,
    required this.createdAt,
    required this.user,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      idComment: json['id_comment'] as int,
      idPost: json['id_post'] as int,
      idUser: json['id_user'] as int,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
