import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audioplayers/audioplayers.dart';
// Avoid ambiguous Card class by showing explicit imports:
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:flutter/material.dart' as material show Card;
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env vars for API keys
  await dotenv.load(fileName: ".env");

  // Hive init for local storage
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  await Hive.openBox('library');
  await Hive.openBox('progress');

  // Initialize Stripe
  Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  Stripe.merchantIdentifier = dotenv.env['STRIPE_MERCHANT_ID'] ?? '';
  await Stripe.instance.applySettings();

  runApp(const AudiobooksApp());
}

// PUBLIC_INTERFACE
class AudiobooksApp extends StatelessWidget {
  const AudiobooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: MaterialApp(
        title: 'Audiobook Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.light(
            primary: HexColor('#1E88E5'),
            secondary: HexColor('#43A047'),
            surface: Colors.white,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Color(0xFF1E88E5)),
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 20
            ),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 16, color: Colors.black),
          ),
          useMaterial3: true,
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  final List<Widget> pages = [
    const StorePage(),
    const LibraryPage(),
    const PlayerPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (idx) => setState(() => currentIndex = idx),
        backgroundColor: Colors.white,
        selectedItemColor: HexColor('#1E88E5'),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Store',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.headphones),
            label: 'Player',
          ),
        ],
      ),
    );
  }
}

/// Audiobook model
class Audiobook {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String description;
  final String audioUrl;
  final double price;

  Audiobook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
    required this.audioUrl,
    required this.price,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
    'description': description,
    'audioUrl': audioUrl,
    'price': price,
  };

  static Audiobook fromMap(Map<String, dynamic> map) => Audiobook(
    id: map['id'],
    title: map['title'],
    author: map['author'],
    coverUrl: map['coverUrl'],
    description: map['description'],
    audioUrl: map['audioUrl'],
    price: map['price'],
  );
}

/// Dummy data for store
List<Audiobook> dummyStoreBooks = [
  Audiobook(
    id: "the_universe",
    title: "The Universe",
    author: "Jane Wells",
    coverUrl: "https://covers.openlibrary.org/b/id/10958360-L.jpg",
    description: "Explore the cosmos in detail with this award-winning audiobook.",
    audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    price: 9.99,
  ),
  Audiobook(
    id: "time_machine",
    title: "The Time Machine",
    author: "H. G. Wells",
    coverUrl: "https://covers.openlibrary.org/b/id/8226096-L.jpg",
    description: "Travel through time in H.G. Wells' classic science fiction adventure.",
    audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
    price: 6.99,
  ),
];

/// Storage helpers
class StorageHelper {
  static final libraryBox = Hive.box('library');
  static final progressBox = Hive.box('progress');
  static Future<List<Audiobook>> getLibrary() async {
    final saved = libraryBox.get('library', defaultValue: []);
    if (saved is List) {
      return saved.map((e) => Audiobook.fromMap(Map<String, dynamic>.from(e))).toList();
    }
    return [];
  }

  static Future<void> addBook(Audiobook book) async {
    List<Audiobook> lib = await getLibrary();
    if (!lib.any((b) => b.id == book.id)) {
      lib.add(book);
      await libraryBox.put('library', lib.map((b) => b.toMap()).toList());
    }
  }

  static Future<void> removeBook(String id) async {
    List<Audiobook> lib = await getLibrary();
    lib.removeWhere((b) => b.id == id);
    await libraryBox.put('library', lib.map((b) => b.toMap()).toList());
  }

  static Future<double> getProgress(String bookId) async {
    final val = progressBox.get(bookId, defaultValue: 0.0);
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return 0.0;
  }

  static Future<void> saveProgress(String bookId, double position) async {
    await progressBox.put(bookId, position);
  }
}

/// Library provider
// PUBLIC_INTERFACE
class LibraryProvider extends ChangeNotifier {
  List<Audiobook> library = [];
  bool loading = true;

  LibraryProvider() {
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    loading = true;
    notifyListeners();
    library = await StorageHelper.getLibrary();
    loading = false;
    notifyListeners();
  }

  Future<void> add(Audiobook book) async {
    await StorageHelper.addBook(book);
    await _loadLibrary();
  }

  Future<void> remove(String bookId) async {
    await StorageHelper.removeBook(bookId);
    await _loadLibrary();
  }

  bool isInLibrary(String id) => library.any((b) => b.id == id);
}


/// Store Page: Browsing and Buying Audiobooks
class StorePage extends StatelessWidget {
  const StorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final libProvider = Provider.of<LibraryProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Store"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 32),
        itemCount: dummyStoreBooks.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: ((context, i) {
          Audiobook book = dummyStoreBooks[i];
          return material.Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(book.coverUrl, width: 50, height: 70, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.book, size: 40)),
              ),
              title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(book.author, style: const TextStyle(color: Colors.grey)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("\$${book.price.toStringAsFixed(2)}", style: TextStyle(color: HexColor('#43A047'), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  libProvider.isInLibrary(book.id)
                  ? const Icon(Icons.check_circle, color: Colors.grey, size: 18)
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HexColor('#FFC107'),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        minimumSize: const Size(60, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        // Show loading
                        final nav = Navigator.of(context);
                        final scaf = ScaffoldMessenger.of(context);
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );
                        // For demo: simulate Stripe workflow -- always succeed after a moment
                        await Future.delayed(const Duration(seconds: 2));
                        // In a real app, here integrate with Stripe via a backend function/get PaymentIntent, etc.
                        await libProvider.add(book); // add to local library
                        nav.pop(); // dismiss loading
                        scaf.showSnackBar(
                          SnackBar(
                            backgroundColor: HexColor('#43A047'),
                            content: Text('Purchased "${book.title}"! Added to Library.'),
                          ),
                        );
                      },
                      child: const Text("Buy", style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              onTap: () => _showDetailDialog(context, book),
            ),
          );
        }),
      ),
    );
  }
  void _showDetailDialog(BuildContext context, Audiobook book) {
    showDialog(
      context: context,
      builder: (_) =>
        Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 6),
                  Text(book.author, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(book.coverUrl, width: 100, height: 130, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.book, size: 90))
                  ),
                  const SizedBox(height: 12),
                  Text(book.description, style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        )
    );
  }
}


/// Library Page: List of Purchased
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final libProvider = Provider.of<LibraryProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Library"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: libProvider.loading
        ? const Center(child: CircularProgressIndicator())
        : libProvider.library.isEmpty
          ? const Center(child: Text("No audiobooks purchased yet."))
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 32),
              itemCount: libProvider.library.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, idx) {
                Audiobook book = libProvider.library[idx];
                return material.Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(book.coverUrl, width: 50, height: 70, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.book, size: 40)),
                    ),
                    title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(book.author, style: const TextStyle(color: Colors.grey)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: () async {
                        final scaffold = ScaffoldMessenger.of(context);
                        await libProvider.remove(book.id);
                        scaffold.showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.redAccent,
                            content: Text('Removed "${book.title}" from Library.'),
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      // Set current book in player
                      Provider.of<PlayerProvider>(context, listen: false).setCurrentBook(book);
                      // Switch to Player
                      // DefaultTabController.of(context)?.animateTo(2); // This doesn't work without DefaultTabController
                      // Instead: show a SnackBar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Go to Player tab to listen.'))
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// Player provider for managing playback state and progress
// PUBLIC_INTERFACE
class PlayerProvider extends ChangeNotifier {
  Audiobook? currentBook;
  AudioPlayer? _audioPlayer;
  bool playing = false;
  Duration position = Duration.zero;
  Duration? total;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durationSub;

  PlayerProvider();

  void setCurrentBook(Audiobook book) async {
    if (currentBook?.id != book.id) {
      await stop();
      currentBook = book;
      // Restore previous position
      final progS = await StorageHelper.getProgress(book.id);
      await _initAudioPlayer(book, progS);
      notifyListeners();
    }
  }

  Future<void> _initAudioPlayer(Audiobook book, double initialSeconds) async {
    _audioPlayer = AudioPlayer();
    _posSub = _audioPlayer!.onPositionChanged.listen((d) async {
      position = d;
      if (currentBook != null) {
        await StorageHelper.saveProgress(currentBook!.id, d.inSeconds.toDouble());
      }
      notifyListeners();
    });
    _durationSub = _audioPlayer!.onDurationChanged.listen((d) {
      total = d;
      notifyListeners();
    });
    _stateSub = _audioPlayer!.onPlayerStateChanged.listen((state) {
      playing = state == PlayerState.playing;
      notifyListeners();
    });
    await _audioPlayer!.setSource(UrlSource(book.audioUrl));
    // Wait for duration or 1 sec.
    await Future.delayed(const Duration(seconds: 1));
    if (initialSeconds > 0) {
      await _audioPlayer!.seek(Duration(seconds: initialSeconds.toInt()));
    }
    playing = false;
    notifyListeners();
  }

  Future<void> play() async {
    if (_audioPlayer == null && currentBook != null) {
      await _initAudioPlayer(currentBook!, 0);
    }
    await _audioPlayer?.resume();
  }

  Future<void> pause() async {
    await _audioPlayer?.pause();
  }

  Future<void> skip(int seconds) async {
    final cur = position.inSeconds + seconds;
    await _audioPlayer?.seek(Duration(seconds: cur.clamp(0, (total?.inSeconds ?? 0))));
  }

  Future<void> stop() async {
    await _audioPlayer?.stop();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _posSub?.cancel(); _stateSub?.cancel(); _durationSub?.cancel();
    position = Duration.zero;
    total = null;
    playing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _posSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }
}


/// PlayerPage UI
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  String _fmt(Duration? d) {
    if (d == null) return "00:00:00";
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final book = player.currentBook;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Player"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: book == null
      ? const Center(child: Text("Select a book from your Library to play.", style: TextStyle(fontSize: 17)))
      : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 18.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(book.coverUrl,
                width: 170, height: 230, fit: BoxFit.cover,
                errorBuilder: (_,__,___) => Container(color: Colors.grey.shade200, width: 170, height: 230, child: const Icon(Icons.book, size: 90))
              ),
            ),
            const SizedBox(height: 16),
            Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22), textAlign: TextAlign.center),
            Text(book.author, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 18),
            Slider(
              value: player.position.inSeconds.toDouble(),
              min: 0,
              max: player.total?.inSeconds.toDouble() ?? 1,
              thumbColor: HexColor('#1E88E5'),
              activeColor: HexColor('#1E88E5'),
              inactiveColor: Colors.grey.withAlpha((0.3 * 255).toInt()),
              onChanged: (value) async {
                await player._audioPlayer?.seek(Duration(seconds: value.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(player.position), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                Text(_fmt(player.total), style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  color: HexColor('#1E88E5'),
                  iconSize: 38,
                  onPressed: player.currentBook == null ? null : () { player.skip(-15); },
                ),
                const SizedBox(width: 24),
                CircleAvatar(
                  backgroundColor: HexColor('#1E88E5'),
                  radius: 36,
                  child: IconButton(
                    icon: Icon(
                      player.playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white, size: 36,
                    ),
                    onPressed: player.currentBook == null
                      ? null
                      : () { player.playing ? player.pause() : player.play(); },
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.forward_10),
                  color: HexColor('#1E88E5'),
                  iconSize: 38,
                  onPressed: player.currentBook == null ? null : () { player.skip(15); },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

/// Utility for Hex colors
class HexColor extends Color {
  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
  static int _getColorFromHex(String hexColor) {
    String hc = hexColor.toUpperCase().replaceAll("#", "");
    if (hc.length == 6) { hc = "FF$hc"; }
    return int.parse(hc, radix: 16);
  }
}
