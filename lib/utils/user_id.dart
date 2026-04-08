import 'package:supabase_flutter/supabase_flutter.dart';

/// 現在のユーザーのIDを取得する
/// 匿名ログイン後は必ずcurrentUserがnullではないことが保証される
String get userId {
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser == null) {
    throw Exception('User is not logged in. Make sure signInAnonymously() is called.');
  }
  return currentUser.id;
}

/// 現在のユーザーを取得する
User? get currentUser => Supabase.instance.client.auth.currentUser;