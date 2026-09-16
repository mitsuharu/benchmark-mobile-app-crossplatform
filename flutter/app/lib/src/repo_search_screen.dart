import 'dart:async';

import 'package:flutter/material.dart';

import 'app_channel.dart';
import 'bench_marker.dart';
import 'github_client.dart';
import 'palette.dart';

/// Keywords that can be pushed into the screen while it is open.
const presetKeywords = ['expo', 'swift', 'kotlin'];

/// The second screen: searches GitHub for the keyword the home screen handed
/// over and lists the repositories.
class RepoSearchScreen extends StatefulWidget {
  const RepoSearchScreen({
    super.key,
    required this.initialKeyword,
    required this.client,
    required this.channel,
    this.marker,
  });

  /// Handed over by the home screen when it opened this screen.
  final String initialKeyword;
  final GitHubClient client;
  final AppChannel channel;
  final BenchMarker? marker;

  @override
  State<RepoSearchScreen> createState() => _RepoSearchScreenState();
}

class _RepoSearchScreenState extends State<RepoSearchScreen> {
  late String _keyword = widget.initialKeyword;
  List<Repository> _repositories = const [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<RepoSearchCommand>? _commands;

  BenchMarker get _marker => widget.marker ?? BenchMarker.instance;

  @override
  void initState() {
    super.initState();
    _marker.markAfterFrame('searchFirstFrame');
    // The keyword passed in only arrives while the screen is being created,
    // so replacing it on an open screen comes over the channel.
    _commands = widget.channel.commands.listen((command) {
      switch (command) {
        case SetKeyword(:final keyword):
          setState(() {
            _keyword = keyword;
            _repositories = const [];
            _error = null;
          });
          _marker.markAfterFrame('keywordApplied');
      }
    });
  }

  @override
  void dispose() {
    _commands?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    _marker.mark('searchTapped');
    final keyword = _keyword;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await widget.client.searchRepositories(keyword);
      if (!mounted) return;
      setState(() => _repositories = results);
      if (results.isNotEmpty) {
        _marker.markAfterFrame('searchRendered');
      }
      // Hand the results back to the home screen.
      widget.channel.post(
        SearchSucceeded(keyword, results.map(SearchedRepository.of).toList()),
      );
    } catch (e) {
      final message = e is GitHubException ? e.message : e.toString();
      if (!mounted) return;
      setState(() {
        _repositories = const [];
        _error = message;
      });
      widget.channel.post(SearchFailed(keyword, message));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GitHub Repositories',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'keyword: $_keyword',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Palette.subtitle,
                    ),
                  ),
                ],
              ),
            ),
            // Replacing the keyword on the open screen goes over the channel,
            // the same path the other implementations take.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  for (final preset in presetKeywords)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: () {
                          _marker.mark('commandSent');
                          widget.channel.send(SetKeyword(preset));
                        },
                        child: Text(preset),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: _isLoading ? '検索中...' : 'リポジトリを検索',
                      onPressed: _isLoading ? null : _search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionButton(
                    label: 'ホームに戻る',
                    secondary: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Palette.error),
                ),
              ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _repositories.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_repositories.isEmpty) {
      return _error == null
          ? const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Text(
                'ボタンを押すと検索結果が表示されます。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.placeholder),
              ),
            )
          : const SizedBox.shrink();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: _repositories.length,
      itemBuilder: (context, index) =>
          RepositoryRow(repository: _repositories[index]),
    );
  }
}

class RepositoryRow extends StatelessWidget {
  const RepositoryRow({super.key, required this.repository});

  final Repository repository;

  @override
  Widget build(BuildContext context) {
    final language = repository.language;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.secondary, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              repository.fullName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (repository.description != null) ...[
              const SizedBox(height: 4),
              Text(
                repository.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Palette.description,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '★ ${groupThousands(repository.stars)}'
              '${language != null ? ' · $language' : ''}',
              style: const TextStyle(fontSize: 12, color: Palette.subtitle),
            ),
          ],
        ),
      ),
    );
  }
}
