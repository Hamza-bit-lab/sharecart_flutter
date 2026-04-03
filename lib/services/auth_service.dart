import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sharecart/services/api_config.dart';
import 'package:sharecart/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'auth_token';
const _tokenTypeKey = 'auth_token_type';
const _guestTokenKey = 'guest_list_token';
const _guestListIdKey = 'guest_list_id';
const _cacheListsKey = 'offline_cache_lists';
const _cacheListDetailPrefix = 'offline_cache_list_';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  String? _token;
  String? _tokenType;
  String? _guestToken;
  int? _guestListId;
  bool _listsFromCache = false;
  bool _listDetailFromCache = false;

  String? get token => _token;
  bool get listsFromCache => _listsFromCache;
  bool get listDetailFromCache => _listDetailFromCache;
  String? get tokenType => _tokenType;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  bool get isGuestMode => _guestToken != null && _guestToken!.isNotEmpty;
  int? get guestListId => _guestListId;

  static bool isUnauthorizedError(Object? error) {
    return false; // Temporarily returning false for everything to see the raw error Trace!
  }

  Future<void> loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _tokenType = prefs.getString(_tokenTypeKey) ?? 'Bearer';
    _guestToken = prefs.getString(_guestTokenKey);
    final id = prefs.getInt(_guestListIdKey);
    _guestListId = id;
  }

  Future<void> _saveToken(String token, String tokenType) async {
    _token = token;
    _tokenType = tokenType;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_tokenTypeKey, tokenType);
    await _clearGuestToken();
  }

  Future<void> clearToken() async {
    _token = null;
    _tokenType = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenTypeKey);
  }

  Future<void> _saveGuestToken(String token, int listId) async {
    _guestToken = token;
    _guestListId = listId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestTokenKey, token);
    await prefs.setInt(_guestListIdKey, listId);
  }

  Future<void> clearGuestToken() async {
    _guestToken = null;
    _guestListId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestTokenKey);
    await prefs.remove(_guestListIdKey);
  }

  Future<void> _clearGuestToken() async {
    _guestToken = null;
    _guestListId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestTokenKey);
    await prefs.remove(_guestListIdKey);
  }

  Map<String, String> _baseHeaders() => const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Map<String, String> _authHeaders() {
    final headers = Map<String, String>.from(_baseHeaders());
    if (_token != null && _token!.isNotEmpty) {
      final type = _tokenType?.isNotEmpty == true ? _tokenType! : 'Bearer';
      headers['Authorization'] = '$type $_token';
    }
    return headers;
  }

  /// Headers for list/item APIs: use full auth token or guest token for that list.
  Map<String, String> _authHeadersForList(int? listId) {
    final headers = Map<String, String>.from(_baseHeaders());
    if (_token != null && _token!.isNotEmpty) {
      final type = _tokenType?.isNotEmpty == true ? _tokenType! : 'Bearer';
      headers['Authorization'] = '$type $_token';
      return headers;
    }
    if (_guestToken != null && _guestToken!.isNotEmpty && listId != null && listId == _guestListId) {
      headers['Authorization'] = 'Bearer $_guestToken';
      return headers;
    }
    return headers;
  }

  /// Registers a new user. On success saves token and returns user data.
  /// Throws [RegisterException] on validation or server error.
  Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/api/auth/register');
    final response = await http.post(
      uri,
      headers: _baseHeaders(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 201) {
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw RegisterException('Invalid response from server');
      }
      final token = data['token'] as String?;
      final tokenType = data['token_type'] as String? ?? 'Bearer';
      if (token == null || token.isEmpty) {
        throw RegisterException('No token in response');
      }
        await _saveToken(token, tokenType);
        registerFcmTokenWithBackend();
        final user = data['user'];
        return RegisterResult(success: true, user: user);
    }

    if (response.statusCode == 422) {
      final errors = body['errors'] as Map<String, dynamic>?;
      final message = body['message'] as String? ?? 'Validation failed';
      throw RegisterException(message, errors: errors);
    }

    final message = body['message'] as String? ?? 'Something went wrong';
    throw RegisterException(message);
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/api/auth/login');
    try {
      final response = await http.post(
        uri,
        headers: _baseHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      } catch (_) {
        rethrow;
      }

      if (response.statusCode == 200) {
        final data = body['data'] as Map<String, dynamic>?;
        if (data == null) throw LoginException('Invalid response from server');
        final token = data['token'] as String?;
        final tokenType = data['token_type'] as String? ?? 'Bearer';
        if (token == null || token.isEmpty) throw LoginException('No token in response');
        await _saveToken(token, tokenType);
        registerFcmTokenWithBackend();
        final user = data['user'];
        return LoginResult(success: true, user: user);
      }

      if (response.statusCode == 422) {
        final errors = body['errors'] as Map<String, dynamic>?;
        final message = body['message'] as String? ?? 'Invalid credentials';
        throw LoginException(message, errors: errors);
      }

      final message = body['message'] as String? ?? 'Something went wrong';
      throw LoginException(message);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> registerFcmTokenWithBackend() async {
    if (!isLoggedIn) return;
    try {
      final token = await getFcmToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('FCM: getToken() empty — cannot register with backend');
        return;
      }
      final uri = Uri.parse('$apiBaseUrl/api/fcm-token');
      final response = await http.post(
        uri,
        headers: _authHeaders(),
        body: jsonEncode({'token': token}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) debugPrint('FCM: token registered with backend (HTTP ${response.statusCode})');
        return;
      }
      if (kDebugMode) {
        debugPrint(
          'FCM: backend registration failed HTTP ${response.statusCode} — ${response.body}',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FCM: registerFcmTokenWithBackend error: $e');
        debugPrint('$st');
      }
    }
  }

  Future<Map<String, dynamic>> me() async {
    final uri = Uri.parse('$apiBaseUrl/api/auth/me');
    final response = await http.get(
      uri,
      headers: _authHeaders(),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>?;
      final user = data?['user'];
      if (user is Map<String, dynamic>) {
        return user;
      }
      throw Exception('Invalid user data from server');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }

    final message = body['message'] as String? ?? 'Failed to load profile';
    throw Exception(message);
  }

  Future<void> logout() async {
    final uri = Uri.parse('$apiBaseUrl/api/auth/logout');
    final response = await http.post(
      uri,
      headers: _authHeaders(),
    );

    await clearToken();

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      final message = body['message'] as String? ?? 'Logout failed';
      throw Exception(message);
    }
  }

  static ListsIndexResult _parseListsResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>? ?? {};
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final activeJson = data['active'] as List<dynamic>? ?? const [];
    final archivedJson = data['archived'] as List<dynamic>? ?? const [];
    final active = activeJson
        .whereType<Map<String, dynamic>>()
        .map(ListSummary.fromJson)
        .toList(growable: false);
    final archived = archivedJson
        .whereType<Map<String, dynamic>>()
        .map(ListSummary.fromJson)
        .toList(growable: false);
    return ListsIndexResult(active: active, archived: archived);
  }

  /// Fetches all lists the user can access (owned + shared) using /lists.
  /// Returns active and archived summaries. On network failure returns cached data if available.
  Future<ListsIndexResult> fetchLists() async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/lists');
      final response = await http.get(
        uri,
        headers: _authHeaders(),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

      if (response.statusCode == 200) {
        _listsFromCache = false;
        final result = _parseListsResponse(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheListsKey, response.body);
        return result;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearToken();
        throw Exception('Unauthorized');
      }

      final message = body['message'] as String? ?? 'Failed to load lists';
      throw Exception(message);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheListsKey);
      if (cached != null && cached.isNotEmpty) {
        _listsFromCache = true;
        return _parseListsResponse(cached);
      }
      rethrow;
    }
  }

  Future<JoinByCodeResult> joinByCode(String code, {String? name}) async {
    final wasLoggedIn = isLoggedIn;
    final uri = Uri.parse('$apiBaseUrl/api/lists/join-code');
    final payload = <String, dynamic>{'code': code.trim().toUpperCase()};
    if (name != null && name.trim().isNotEmpty) payload['name'] = name.trim();
    final response = await http.post(
      uri,
      headers: wasLoggedIn ? _authHeaders() : _baseHeaders(),
      body: jsonEncode(payload),
    );

    final resp = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
    if (response.statusCode != 200) {
      final msg = resp['message'] as String? ?? 'Invalid or expired code';
      throw Exception(msg);
    }

    final data = resp['data'] as Map<String, dynamic>? ?? {};
    final listJson = data['list'] as Map<String, dynamic>? ?? {};
    final list = ListDetail.fromJson(listJson);
    final accessToken = data['access_token'] as String?;
    final isGuest = accessToken != null && accessToken.isNotEmpty;

    if (isGuest && !wasLoggedIn) {
      await _saveGuestToken(accessToken, list.id);
    }

    return JoinByCodeResult(list: list, isGuest: isGuest);
  }

  Future<ListDetail> fetchListDetail(int id) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/lists/$id');
      final response = await http.get(
        uri,
        headers: _authHeadersForList(id),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

      if (response.statusCode == 200) {
        _listDetailFromCache = false;
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final listJson = data['list'] as Map<String, dynamic>? ?? {};
        final detail = ListDetail.fromJson(listJson);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_cacheListDetailPrefix$id', response.body);
        return detail;
      }

      if (response.statusCode == 401) {
        throw Exception('Auth-401: The backend returned 401 Unauthenticated for this list.');
      }
      if (response.statusCode == 403) {
        throw Exception('Auth-403: The backend returned 403 Forbidden for this list.');
      }

      final message = body['message'] as String? ?? 'Failed to load list. Code: ${response.statusCode}';
      throw Exception(message);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$_cacheListDetailPrefix$id');
      if (cached != null && cached.isNotEmpty) {
        _listDetailFromCache = true;
        final json = jsonDecode(cached) as Map<String, dynamic>? ?? {};
        final data = json['data'] as Map<String, dynamic>? ?? {};
        final listJson = data['list'] as Map<String, dynamic>? ?? {};
        return ListDetail.fromJson(listJson);
      }
      rethrow;
    }
  }

  /// GET /api/lists/icons — list of recommended icons (emojis) for lists.
  Future<List<String>> fetchListIcons() async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/icons');
    final response = await http.get(uri, headers: _authHeaders());
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final icons = data['icons'] as List<dynamic>? ?? [];
      return icons.whereType<String>().toList();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }
    return ['🛒', '🏠', '🎉', '🛍️', '📋', '🥗', '🍎', '🧾'];
  }

  /// Creates a new list via POST /lists. Returns the created list detail (201).
  Future<ListDetail> createList(String name, {String? dueDate, String? icon}) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists');
    final payload = <String, dynamic>{'name': name};
    if (dueDate != null && dueDate.isNotEmpty) payload['due_date'] = dueDate;
    if (icon != null && icon.isNotEmpty) payload['icon'] = icon;

    final response = await http.post(
      uri,
      headers: _authHeaders(),
      body: jsonEncode(payload),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 201) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final listJson = data['list'] as Map<String, dynamic>? ?? {};
      return ListDetail.fromJson(listJson);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }

    if (response.statusCode == 422) {
      final errors = body['errors'] as Map<String, dynamic>?;
      final msg = body['message'] as String? ?? 'Validation failed';
      final firstError = _firstValidationError(errors);
      throw Exception(firstError ?? msg);
    }

    final message = body['message'] as String? ?? 'Failed to create list';
    throw Exception(message);
  }

  /// Nudge collaborators: POST /api/lists/{listId}/ping. Updates last_ping_at on the list.
  Future<void> pingList(int listId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/ping');
    final response = await http.post(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Nudge failed');
  }

  /// Updates list name, due_date or icon via PATCH /lists/{id}.
  Future<ListDetail> updateList(int listId, {String? name, String? dueDate, String? icon}) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId');
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (dueDate != null) payload['due_date'] = dueDate;
    if (icon != null) payload['icon'] = icon;
    if (payload.isEmpty) return fetchListDetail(listId);

    final response = await http.patch(
      uri,
      headers: _authHeadersForList(listId),
      body: jsonEncode(payload),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final listJson = data['list'] as Map<String, dynamic>? ?? {};
      return ListDetail.fromJson(listJson);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }
    if (response.statusCode == 422) {
      final firstError = _firstValidationError(body['errors'] as Map<String, dynamic>?);
      throw Exception(firstError ?? 'Validation failed');
    }
    throw Exception(body['message'] as String? ?? 'Failed to update list');
  }

  /// Archives a list via POST /lists/{id}/archive.
  Future<ListSummary> archiveList(int listId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/archive');
    final response = await http.post(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final listJson = data['list'] as Map<String, dynamic>? ?? {};
      return ListSummary.fromJson(listJson);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to archive list');
  }

  /// Restores an archived list via POST /lists/{id}/restore.
  Future<ListSummary> restoreList(int listId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/restore');
    final response = await http.post(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final listJson = data['list'] as Map<String, dynamic>? ?? {};
      return ListSummary.fromJson(listJson);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to restore list');
  }

  /// Share list with user by email. POST /lists/{listId}/share. Auth only.
  Future<void> shareList(int listId, String email) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/share');
    final response = await http.post(
      uri,
      headers: _authHeaders(),
      body: jsonEncode({'email': email.trim()}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
    if (response.statusCode == 200) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }
    if (response.statusCode == 404) {
      throw Exception(body['message'] as String? ?? 'User not found.');
    }
    if (response.statusCode == 422) {
      throw Exception(body['message'] as String? ?? 'Cannot share with this user.');
    }
    throw Exception(body['message'] as String? ?? 'Failed to share list');
  }

  /// Remove collaborator. DELETE /lists/{listId}/share/{userId}. Auth only.
  Future<void> unshareList(int listId, int userId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/share/$userId');
    final response = await http.delete(uri, headers: _authHeaders());
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
    if (response.statusCode == 200 || response.statusCode == 204) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }
    if (response.statusCode == 422) {
      throw Exception(body['message'] as String? ?? 'Cannot remove this user.');
    }
    throw Exception(body['message'] as String? ?? 'Failed to remove access');
  }

  /// Deletes a list via DELETE /lists/{id}.
  Future<void> deleteList(int listId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId');
    final response = await http.delete(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200 || response.statusCode == 204) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to delete list');
  }

  /// Leaves a list via POST /lists/{listId}/leave.
  /// - Logged-in users: uses auth token.
  /// - Guests: uses guest token only for the guest list id.
  Future<void> leaveList(int listId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/leave');
    final response = await http.post(uri, headers: _authHeadersForList(listId));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
    } catch (_) {
      body = const <String, dynamic>{};
    }

    if (response.statusCode == 200) return;

    if (response.statusCode == 401) {
      // Token/session expired or guest token invalid.
      if (isGuestMode) {
        await clearGuestToken();
      } else {
        await clearToken();
      }
      throw Exception('Unauthorized');
    }

    // 403 is also used for business rules (e.g. owner cannot leave), so don't clear tokens.
    final message = body['message'] as String? ?? 'Failed to leave list';
    throw Exception(message);
  }

  /// Fetch suggested item names. GET /suggestions?q=&limit=&context=
  /// Requires auth; returns empty list for guest or on error.
  Future<List<String>> fetchSuggestions(String q, {int limit = 10, List<String>? contextItems}) async {
    if (!isLoggedIn) return [];
    var uri = Uri.parse('$apiBaseUrl/api/suggestions').replace(
      queryParameters: {
        'q': q,
        'limit': limit.clamp(1, 50).toString(),
        if (contextItems != null && contextItems.isNotEmpty)
          'context': contextItems.take(20).join(','),
      },
    );
    try {
      final response = await http.get(uri, headers: _authHeaders());
      final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      if (response.statusCode != 200) return [];
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final list = data['suggestions'] as List<dynamic>? ?? [];
      return list.map((e) {
        if (e is String) return e;
        if (e is Map<String, dynamic>) return e['name'] as String?;
        return null;
      }).whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Frequent items from your history (excluding names already on this list).
  /// GET /lists/{listId}/predictive-suggestions — requires auth; guest / error → [].
  Future<List<String>> fetchPredictiveSuggestions(int listId) async {
    if (!isLoggedIn) return [];
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/predictive-suggestions');
    try {
      final response = await http.get(uri, headers: _authHeadersForList(listId));
      final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      if (response.statusCode != 200) return [];
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final list = data['suggestions'] as List<dynamic>? ?? [];
      return list.map((e) {
        if (e is String) return e;
        if (e is Map<String, dynamic>) return e['name'] as String?;
        return null;
      }).whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Add an item to a list via POST /lists/{listId}/items.
  Future<ListDetail> storeListItem(int listId, String name, {int quantity = 1}) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/items');
    final response = await http.post(
      uri,
      headers: _authHeadersForList(listId),
      body: jsonEncode({'name': name, 'quantity': quantity}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 201) {
      return fetchListDetail(listId);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    if (response.statusCode == 422) {
      final firstError = _firstValidationError(body['errors'] as Map<String, dynamic>?);
      throw Exception(firstError ?? 'Validation failed');
    }
    throw Exception(body['message'] as String? ?? 'Failed to add item');
  }

  /// Update an item (name, quantity, or completed) via PATCH /lists/{listId}/items/{itemId}.
  Future<ListDetail> updateListItem(int listId, int itemId, {String? name, int? quantity, bool? completed}) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/items/$itemId');
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (quantity != null) payload['quantity'] = quantity;
    if (completed != null) payload['completed'] = completed;
    if (payload.isEmpty) return fetchListDetail(listId);

    final response = await http.patch(
      uri,
      headers: _authHeadersForList(listId),
      body: jsonEncode(payload),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      return fetchListDetail(listId);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to update item');
  }

  /// Claim an item (I'll buy this) via POST /lists/{listId}/items/{itemId}/claim.
  Future<ListDetail> claimListItem(int listId, int itemId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/items/$itemId/claim');
    final response = await http.post(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      return fetchListDetail(listId);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to claim item');
  }

  /// Delete an item via DELETE /lists/{listId}/items/{itemId}.
  Future<ListDetail> deleteListItem(int listId, int itemId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/items/$itemId');
    final response = await http.delete(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200 || response.statusCode == 204) {
      return fetchListDetail(listId);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to delete item');
  }

  /// Toggle out-of-stock flag via POST /lists/{listId}/items/{itemId}/out-of-stock.
  Future<ListDetail> toggleItemOutOfStock(int listId, int itemId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/items/$itemId/out-of-stock');
    final response = await http.post(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      return fetchListDetail(listId);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    if (response.statusCode == 404) {
      throw Exception(body['message'] as String? ?? 'Item not found');
    }
    throw Exception(body['message'] as String? ?? 'Failed to update stock status');
  }

  /// GET /lists/{listId}/items/{itemId}/messages — item mini-chat thread.
  Future<List<ItemMessage>> fetchItemMessages(int listId, int itemId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/items/$itemId/messages');
    final response = await http.get(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final raw = data['messages'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ItemMessage.fromJson)
          .toList();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    if (response.statusCode == 404) {
      throw Exception(body['message'] as String? ?? 'Item not found');
    }
    throw Exception(body['message'] as String? ?? 'Failed to load messages');
  }

  /// POST /lists/{listId}/items/{itemId}/messages — body: { "message": "..." }.
  Future<ItemMessage> postItemMessage(int listId, int itemId, String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message cannot be empty');
    }
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/items/$itemId/messages');
    final response = await http.post(
      uri,
      headers: _authHeadersForList(listId),
      body: jsonEncode({'message': trimmed}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 201) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final m = data['message'] as Map<String, dynamic>? ?? {};
      return ItemMessage.fromJson(m);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    if (response.statusCode == 404) {
      throw Exception(body['message'] as String? ?? 'Item not found');
    }
    if (response.statusCode == 422) {
      final first = _firstValidationError(body['errors'] as Map<String, dynamic>?);
      throw Exception(first ?? body['message'] as String? ?? 'Validation failed');
    }
    throw Exception(body['message'] as String? ?? 'Failed to send message');
  }

  /// Reorder list items. Backend must support POST /api/lists/{listId}/items/reorder
  /// with body: { "item_ids": [1, 2, 3, ...] } (ordered list of item ids).
  Future<ListDetail> reorderListItems(int listId, List<int> itemIds) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/items/reorder');
    final response = await http.post(
      uri,
      headers: _authHeadersForList(listId),
      body: jsonEncode({'item_ids': itemIds}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      return fetchListDetail(listId);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to reorder items');
  }

  /// Fetch global templates (GET /api/templates). Requires auth.
  Future<List<TemplateSummary>> fetchTemplates() async {
    final uri = Uri.parse('$apiBaseUrl/api/templates');
    final response = await http.get(uri, headers: _authHeaders());
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final list = data['templates'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(TemplateSummary.fromJson)
          .toList();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to load templates');
  }

  /// Apply template to list (POST /api/templates/{template}/apply/{list}). Requires full auth.
  Future<ListDetail> applyTemplate(int templateId, int listId) async {
    final uri = Uri.parse('$apiBaseUrl/api/templates/$templateId/apply/$listId');
    final response = await http.post(uri, headers: _authHeaders());
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      return fetchListDetail(listId);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to apply template');
  }

  /// GET /api/lists/{listId}/payments — list payments for a list (auth: list member or guest).
  Future<List<ListPayment>> fetchListPayments(int listId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/payments');
    final response = await http.get(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final list = data['payments'] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ListPayment.fromJson)
          .toList();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to load payments');
  }

  /// POST /api/lists/{listId}/payments — add a payment (auth: list member or guest).
  Future<ListPayment> addListPayment(int listId, double amount, {String? currency}) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/payments');
    final payload = <String, dynamic>{'amount': amount};
    if (currency != null && currency.isNotEmpty) payload['currency'] = currency;

    final response = await http.post(
      uri,
      headers: _authHeadersForList(listId),
      body: jsonEncode(payload),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 201) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final paymentJson = data['payment'] as Map<String, dynamic>? ?? data;
      return ListPayment.fromJson(paymentJson);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    if (response.statusCode == 422) {
      final msg = body['message'] as String? ?? _firstValidationError(body['errors'] as Map<String, dynamic>?) ?? 'Validation failed';
      throw Exception(msg);
    }
    throw Exception(body['message'] as String? ?? 'Failed to add payment');
  }

  /// PATCH /api/lists/{listId}/payments/{paymentId} — update a payment.
  Future<ListPayment> updateListPayment(int listId, int paymentId, double amount, {String? currency}) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/payments/$paymentId');
    final payload = <String, dynamic>{'amount': amount};
    if (currency != null && currency.isNotEmpty) payload['currency'] = currency;

    final response = await http.patch(
      uri,
      headers: _authHeadersForList(listId),
      body: jsonEncode(payload),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final paymentJson = data['payment'] as Map<String, dynamic>? ?? data;
      return ListPayment.fromJson(paymentJson);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    if (response.statusCode == 422) {
      final msg = body['message'] as String? ?? _firstValidationError(body['errors'] as Map<String, dynamic>?) ?? 'Validation failed';
      throw Exception(msg);
    }
    throw Exception(body['message'] as String? ?? 'Failed to update payment');
  }

  /// DELETE /api/lists/{listId}/payments/{paymentId} — remove a payment.
  Future<void> deleteListPayment(int listId, int paymentId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/payments/$paymentId');
    final response = await http.delete(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200 || response.statusCode == 204) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to delete payment');
  }

  /// GET /api/lists/{listId}/settlement — settlement (who owes whom, equal split).
  Future<SettlementResult> fetchSettlement(int listId) async {
    final uri = Uri.parse('$apiBaseUrl/api/lists/$listId/settlement');
    final response = await http.get(uri, headers: _authHeadersForList(listId));
    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

    if (response.statusCode == 200) {
      final data = body['data'] as Map<String, dynamic>? ?? {};
      return SettlementResult.fromJson(data);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (isGuestMode) await clearGuestToken();
      throw Exception('Unauthorized');
    }
    throw Exception(body['message'] as String? ?? 'Failed to load settlement');
  }

  static String? _firstValidationError(Map<String, dynamic>? errors) {
    if (errors == null || errors.isEmpty) return null;
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty && value.first is String) {
        return value.first as String;
      }
    }
    return null;
  }
}

class RegisterResult {
  final bool success;
  final dynamic user;

  RegisterResult({required this.success, this.user});
}

class RegisterException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  RegisterException(this.message, {this.errors});

  /// First validation message for a field, or null.
  String? fieldError(String field) {
    final list = errors?[field];
    if (list is List && list.isNotEmpty && list.first is String) {
      return list.first as String;
    }
    return null;
  }

  /// All validation messages flattened (e.g. for SnackBar).
  String get displayMessage {
    if (errors != null && errors!.isNotEmpty) {
      final list = <String>[];
      for (final value in errors!.values) {
        if (value is List) {
          for (final e in value) {
            if (e is String) list.add(e);
          }
        }
      }
      if (list.isNotEmpty) return list.join(' ');
    }
    return message;
  }

  @override
  String toString() => message;
}

class LoginResult {
  final bool success;
  final dynamic user;

  LoginResult({required this.success, this.user});
}

class LoginException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  LoginException(this.message, {this.errors});

  String? fieldError(String field) {
    final list = errors?[field];
    if (list is List && list.isNotEmpty && list.first is String) {
      return list.first as String;
    }
    return null;
  }

  String get displayMessage {
    if (errors != null && errors!.isNotEmpty) {
      final list = <String>[];
      for (final value in errors!.values) {
        if (value is List) {
          for (final e in value) {
            if (e is String) list.add(e);
          }
        }
      }
      if (list.isNotEmpty) return list.join(' ');
    }
    return message;
  }

  @override
  String toString() => message;
}

class TemplateSummary {
  final int id;
  final String name;
  final int itemsCount;

  TemplateSummary({
    required this.id,
    required this.name,
    required this.itemsCount,
  });

  factory TemplateSummary.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? [];
    return TemplateSummary(
      id: _asInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      itemsCount: items.length,
    );
  }
}

class ListSummary {
  final int id;
  final String name;
  final String? dueDate;
  final String? archivedAt;
  final int itemsCount;
  final String joinCode;
  final String? icon;

  ListSummary({
    required this.id,
    required this.name,
    required this.dueDate,
    required this.archivedAt,
    required this.itemsCount,
    required this.joinCode,
    this.icon,
  });

  factory ListSummary.fromJson(Map<String, dynamic> json) {
    return ListSummary(
      id: _asInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      dueDate: json['due_date'] as String?,
      archivedAt: json['archived_at'] as String?,
      itemsCount: _asInt(json['items_count']) ?? 0,
      joinCode: json['join_code'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }
}

class JoinByCodeResult {
  final ListDetail list;
  final bool isGuest;

  JoinByCodeResult({required this.list, required this.isGuest});
}

class ListsIndexResult {
  final List<ListSummary> active;
  final List<ListSummary> archived;

  ListsIndexResult({required this.active, required this.archived});
}

class ListDetail {
  final int id;
  final String name;
  final String? dueDate;
  final String? archivedAt;
  final String joinCode;
  final String? icon;
  final Map<String, dynamic> owner;
  final List<Map<String, dynamic>> sharedWith;
  final List<String> joinedByCode;
  final List<ListItem> items;

  ListDetail({
    required this.id,
    required this.name,
    required this.dueDate,
    required this.archivedAt,
    required this.joinCode,
    this.icon,
    required this.owner,
    required this.sharedWith,
    required this.joinedByCode,
    required this.items,
  });

  factory ListDetail.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return ListDetail(
      id: _asInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      dueDate: json['due_date'] as String?,
      archivedAt: json['archived_at'] as String?,
      joinCode: json['join_code'] as String? ?? '',
      icon: json['icon'] as String?,
      owner: (json['owner'] as Map<String, dynamic>?) ?? const {},
      sharedWith: (json['shared_with'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      joinedByCode: (json['joined_by_code'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      items: itemsJson
          .whereType<Map<String, dynamic>>()
          .map(ListItem.fromJson)
          .toList(growable: false),
    );
  }

  ListDetail copyWith({List<ListItem>? items}) {
    return ListDetail(
      id: id,
      name: name,
      dueDate: dueDate,
      archivedAt: archivedAt,
      joinCode: joinCode,
      icon: icon,
      owner: owner,
      sharedWith: sharedWith,
      joinedByCode: joinedByCode,
      items: items ?? this.items,
    );
  }
}

class ListItem {
  final int id;
  final String name;
  final int quantity;
  final bool completed;
  final String? section;
  final String? completedByName;
  final int? claimedByUserId;
  final String? claimedByName;
  final String? claimedAt;
  /// When true, item is marked unavailable at the store (API: `is_out_of_stock`).
  final bool isOutOfStock;

  ListItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.completed,
    required this.section,
    required this.completedByName,
    this.claimedByUserId,
    this.claimedByName,
    this.claimedAt,
    this.isOutOfStock = false,
  });

  bool get isClaimed => claimedByUserId != null || (claimedByName != null && claimedByName!.isNotEmpty);

  factory ListItem.fromJson(Map<String, dynamic> json) {
    final completedBy = json['completed_by'];
    String? completedByName;
    if (completedBy is Map<String, dynamic>) {
      completedByName = completedBy['name'] as String?;
    }
    completedByName ??= json['completed_by_name'] as String?;

    final claimedById = json['claimed_by_user_id'];
    final claimedByUid = claimedById == null ? null : (claimedById is int ? claimedById : (claimedById is num ? claimedById.toInt() : int.tryParse(claimedById.toString())));

    final oos = json['is_out_of_stock'];
    final isOos = oos == true || oos == 1 || oos == '1';

    return ListItem(
      id: _asInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      quantity: _asInt(json['quantity']) ?? 1,
      completed: json['completed'] == true || json['completed'] == 1,
      section: json['section'] as String?,
      completedByName: completedByName,
      claimedByUserId: claimedByUid,
      claimedByName: json['claimed_by_name'] as String?,
      claimedAt: json['claimed_at'] as String?,
      isOutOfStock: isOos,
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
  }
  return int.tryParse(value.toString());
}

/// A single message in item-level mini-chat (substitutions / notes).
class ItemMessage {
  final int id;
  final String text;
  final int? userId;
  final String userName;
  final DateTime? createdAt;

  ItemMessage({
    required this.id,
    required this.text,
    this.userId,
    required this.userName,
    this.createdAt,
  });

  factory ItemMessage.fromJson(Map<String, dynamic> json) {
    final uid = json['user_id'];
    int? userId;
    if (uid is int) {
      userId = uid;
    } else if (uid is num) {
      userId = uid.toInt();
    }

    final rawName = json['user_name'];
    String userName;
    if (rawName is String) {
      userName = rawName;
    } else if (rawName != null) {
      userName = rawName.toString();
    } else {
      userName = 'Guest';
    }

    final rawId = json['id'];
    final id = rawId is int ? rawId : (rawId is num ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0);

    final rawMsg = json['message'];
    final text = rawMsg is String ? rawMsg : rawMsg?.toString() ?? '';

    DateTime? createdAt;
    final rawAt = json['created_at'];
    if (rawAt is String && rawAt.isNotEmpty) {
      createdAt = DateTime.tryParse(rawAt);
    }

    return ItemMessage(
      id: id,
      text: text,
      userId: userId,
      userName: userName,
      createdAt: createdAt,
    );
  }
}

class ListPayment {
  final int id;
  final int listId;
  final int? userId;
  final double amount;
  final String? currency;
  final String? paidAt;
  final String? userName;

  ListPayment({
    required this.id,
    required this.listId,
    this.userId,
    required this.amount,
    this.currency,
    this.paidAt,
    this.userName,
  });

  factory ListPayment.fromJson(Map<String, dynamic> json) {
    String? name;
    final payer = json['payer'];
    if (payer is Map<String, dynamic>) {
      name = payer['name'] as String?;
    }
    if (name == null || name.isEmpty) {
      final user = json['user'];
      if (user is Map<String, dynamic>) {
        name = user['name'] as String?;
      }
      name ??= json['user_name'] as String?;
    }

    double parseAmount(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
      return 0;
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return ListPayment(
      id: (json['id'] is int) ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      listId: parseInt(json['list_id']) ?? 0,
      userId: parseInt(json['user_id']),
      amount: parseAmount(json['amount']),
      currency: json['currency'] as String?,
      paidAt: json['paid_at']?.toString(),
      userName: name,
    );
  }
}

class SettlementParticipant {
  final String name;
  final double spent;
  final double balance; // positive = gets back, negative = owes

  SettlementParticipant({required this.name, required this.spent, required this.balance});

  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  factory SettlementParticipant.fromJson(Map<String, dynamic> json) {
    return SettlementParticipant(
      name: json['name']?.toString() ?? 'Unknown',
      spent: _parseDouble(json['spent']),
      balance: _parseDouble(json['balance']),
    );
  }
}

class SettlementResult {
  final double totalSpent;
  final double fairShare;
  final List<SettlementParticipant> participants;

  SettlementResult({
    required this.totalSpent,
    required this.fairShare,
    required this.participants,
  });

  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  factory SettlementResult.fromJson(Map<String, dynamic> json) {
    final list = json['participants'] as List<dynamic>? ?? [];
    return SettlementResult(
      totalSpent: _parseDouble(json['total_spent']),
      fairShare: _parseDouble(json['fair_share']),
      participants: list
          .whereType<Map<String, dynamic>>()
          .map(SettlementParticipant.fromJson)
          .toList(),
    );
  }
}
