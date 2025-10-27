import 'package:dart_rss/domain/rss_feed.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models/article.dart';
import 'widgets/article_card.dart';

void main() {
  runApp(const NewsApp());
}

class NewsApp extends StatelessWidget {
  const NewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Berita Indonesia',
      theme: ThemeData(
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const NewsHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NewsHomePage extends StatefulWidget {
  const NewsHomePage({super.key});

  @override
  State<NewsHomePage> createState() => _NewsHomePageState();
}

class _NewsHomePageState extends State<NewsHomePage> {
  final ScrollController _scrollController = ScrollController();
  final List<Article> _articles = [];
  bool _isLoading = false;
  bool _hasError = false;
  bool _showBackToTop = false;

  String _selectedSource = 'Kompas';

  final Map<String, String> rssSources = {
    'Kompas': 'https://rss.kompas.com/nasional',
    'CNN Indonesia': 'https://www.cnnindonesia.com/nasional/rss',
    'Tempo': 'https://rss.tempo.co/nasional',
  };

  @override
  void initState() {
    super.initState();
    _fetchTopHeadlines();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.offset > 300 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
    } else if (_scrollController.offset <= 300 && _showBackToTop) {
      setState(() => _showBackToTop = false);
    }
  }

  Future<void> _fetchTopHeadlines() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final rssUrl = rssSources[_selectedSource]!;

    try {
      final response = await http.get(
        Uri.parse(rssUrl),
        headers: {'User-Agent': 'Mozilla/5.0 (Flutter RSS App)'},
      );

      if (response.statusCode == 200) {
        final feed = RssFeed.parse(response.body);

        setState(() {
          _articles
            ..clear()
            ..addAll(
              feed.items.map((item) {
                final link = (item.link != null && item.link!.isNotEmpty)
                    ? item.link!
                    : (item.guid ?? '');
                return Article(
                  title: item.title ?? '(Tanpa judul)',
                  description: item.description ?? '',
                  url: link,
                  urlToImage: item.enclosure?.url ?? '',
                  source: _selectedSource,
                  publishedAt: item.pubDate ?? '',
                );
              }),
            );
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      elevation: 3,
      backgroundColor: Colors.white,
      title: Row(
        children: [
          const Icon(Icons.newspaper, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(
            'Berita Indonesia',
            style: TextStyle(
              color: Colors.blue.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedSource,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
            items: rssSources.keys
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedSource = val);
                _fetchTopHeadlines();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchTopHeadlines,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
              ? _buildErrorView()
              : _articles.isEmpty
              ? _buildEmptyView()
              : _buildListView(),
        ),
      ),
    ),
    floatingActionButton: _showBackToTop
        ? FloatingActionButton(
            backgroundColor: Colors.blueAccent,
            onPressed: () => _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            ),
            tooltip: 'Kembali ke atas',
            child: const Icon(Icons.arrow_upward),
          )
        : null,
  );

  Widget _buildListView() => ListView.builder(
    controller: _scrollController,
    physics: const AlwaysScrollableScrollPhysics(),
    itemCount: _articles.length,
    itemBuilder: (context, i) => ArticleCard(article: _articles[i]),
  );

  Widget _buildErrorView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
        SizedBox(height: 12),
        Text('Gagal memuat berita. Tarik untuk mencoba lagi.'),
      ],
    ),
  );

  Widget _buildEmptyView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.article_outlined, color: Colors.grey, size: 60),
        SizedBox(height: 12),
        Text('Tidak ada berita tersedia.'),
      ],
    ),
  );
}
