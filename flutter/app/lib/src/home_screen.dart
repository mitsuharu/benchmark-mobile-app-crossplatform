import 'dart:async';

import 'package:flutter/material.dart';

import 'app_channel.dart';
import 'bench_marker.dart';
import 'github_client.dart';
import 'repo_search_screen.dart';

const defaultKeyword = 'expo';

/// The first screen: the keyword is typed here and handed to the search
/// screen, and the results come back over [AppChannel].
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.channel,
    required this.apiBaseUrl,
    this.marker,
    this.createClient,
  });

  final AppChannel channel;
  final String apiBaseUrl;
  final BenchMarker? marker;

  /// Makes the API client for a visit. Tests replace it.
  final GitHubClient Function(String apiBaseUrl)? createClient;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _keyword = TextEditingController(text: defaultKeyword);
  String? _lastKeyword;
  List<SearchedRepository> _repositories = const [];
  String? _error;
  StreamSubscription<RepoSearchEvent>? _events;

  BenchMarker get _marker => widget.marker ?? BenchMarker.instance;

  /// The keyword handed to the search screen when it is created.
  String get effectiveKeyword {
    final trimmed = _keyword.text.trim();
    return trimmed.isEmpty ? defaultKeyword : trimmed;
  }

  @override
  void initState() {
    super.initState();
    _marker.markAfterFrame('homeFirstFrame', launch: true);
    _events = widget.channel.events.listen((event) {
      switch (event) {
        case SearchSucceeded(:final keyword, :final repositories):
          _marker.mark('resultsReceived');
          setState(() {
            _lastKeyword = keyword;
            _repositories = repositories;
            _error = null;
          });
        case SearchFailed(:final keyword, :final message):
          setState(() {
            _lastKeyword = keyword;
            _repositories = const [];
            _error = message;
          });
      }
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _keyword.dispose();
    super.dispose();
  }

  void _openSearch() {
    _marker.mark('searchOpenTapped');
    final createClient =
        widget.createClient ?? (baseUrl) => GitHubClient(baseUrl: baseUrl);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RepoSearchScreen(
          initialKeyword: effectiveKeyword,
          client: createClient(widget.apiBaseUrl),
          channel: widget.channel,
          marker: widget.marker,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('検索ワード', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'keywordField',
              child: TextField(
                controller: _keyword,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'keyword',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              identifier: 'openSearch',
              child: FilledButton.icon(
                onPressed: _openSearch,
                icon: const Icon(Icons.search),
                label: const Text('検索画面を開く'),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '検索画面から受け取った結果',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._buildResults(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults() {
    final error = _error;
    if (error != null) {
      return [Text(error, style: const TextStyle(color: Color(0xFFB91C1C)))];
    }
    final lastKeyword = _lastKeyword;
    if (lastKeyword == null) {
      return const [
        Text('まだ結果を受け取っていません', style: TextStyle(color: Color(0xFF6B7280))),
      ];
    }
    return [
      Text('keyword: $lastKeyword'),
      Text('件数: ${_repositories.length}'),
      for (final repository in _repositories.take(3)) ...[
        const Divider(),
        Text(
          repository.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          '★ ${repository.stars}'
          '${repository.language != null ? ' · ${repository.language}' : ''}',
        ),
      ],
    ];
  }
}
