import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────
// DESIGN SYSTEM
// ─────────────────────────────────────────────────────────────
class AppColors {
  static const bg = Color(0xFF121212);
  static const accent = Color(0xFF1ED760);
  static const surface = Color(0xFF282828);
  static const overlay = Color(0x14FFFFFF); // white @ 0.08
  static const muted = Color(0xFFB3B3B3);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.bg,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: Colors.white, displayColor: Colors.white),
  );
}

// ─────────────────────────────────────────────────────────────
// MODELS
// [BIND: SPOTIFY] Replace these with models parsed from the Spotify Web API:
//   GET /v1/me/playlists            -> Playlist list (Discover shelf / Library)
//   GET /v1/playlists/{id}/tracks   -> Track list
//   GET /v1/me/player/recently-played -> Recent Activity grid
// Add `String? localPath` to Track: the absolute path of the downloaded .m4a
// in the app Documents directory (null = not synced yet).
// `color` is a placeholder; later derive it from the artwork (e.g. palette_generator).
// ─────────────────────────────────────────────────────────────
class Track {
  final String id, title, artist;
  final Duration duration;
  final Color color;
  const Track(this.id, this.title, this.artist, this.duration, this.color);
}

class Playlist {
  final String id, title, description;
  final Color color;
  final IconData icon;
  const Playlist(this.id, this.title, this.description, this.color, this.icon);
}

const kTracks = <Track>[
  Track('t1', 'Midnight Drive', 'Neon Harbor', Duration(minutes: 3, seconds: 42), Color(0xFF6A3DE8)),
  Track('t2', 'Paper Planes', 'Lena Marsh', Duration(minutes: 2, seconds: 58), Color(0xFFE8553D)),
  Track('t3', 'Low Tide', 'The Quiet Hours', Duration(minutes: 4, seconds: 11), Color(0xFF1E88A8)),
  Track('t4', 'Golden Hour', 'Sol & Vale', Duration(minutes: 3, seconds: 20), Color(0xFFE0A526)),
  Track('t5', 'Static Bloom', 'Mira Okoye', Duration(minutes: 3, seconds: 5), Color(0xFFB0306A)),
  Track('t6', 'Runway Lights', 'Kite Season', Duration(minutes: 3, seconds: 47), Color(0xFF2E9E6B)),
];

const kRecent = <Playlist>[
  Playlist('r1', 'Liked Songs', '', Color(0xFF4A3FD0), Icons.favorite),
  Playlist('r2', 'Travel Mix', '', Color(0xFFE8553D), Icons.flight),
  Playlist('r3', 'Focus Flow', '', Color(0xFF1E88A8), Icons.headphones),
  Playlist('r4', 'Night Drive', '', Color(0xFF6A3DE8), Icons.nightlight_round),
  Playlist('r5', 'Throwbacks', '', Color(0xFFE0A526), Icons.history),
  Playlist('r6', 'Daily Mix 1', '', Color(0xFF2E9E6B), Icons.auto_awesome),
];

const kDiscover = <Playlist>[
  Playlist('d1', 'Chill Vibes', 'Slow beats and soft synths for winding down after a long day.', Color(0xFF3D7BE8), Icons.spa),
  Playlist('d2', 'Road Trip', 'Windows down, volume up. Sing-alongs for the long highway stretches.', Color(0xFFE8843D), Icons.directions_car),
  Playlist('d3', 'Deep Focus', 'Instrumental textures to keep you locked in while you study or code.', Color(0xFF2E9E6B), Icons.psychology),
  Playlist('d4', 'Indie Mornings', 'Gentle guitars and warm vocals to ease into the day.', Color(0xFFB0306A), Icons.wb_sunny),
  Playlist('d5', 'Late Night Lo-fi', 'Dusty drums and mellow keys, perfect for after midnight.', Color(0xFF6A3DE8), Icons.bedtime),
];

// ─────────────────────────────────────────────────────────────
// PLAYER CONTROLLER (single source of truth for all playback UI)
// [BIND: AUDIO] This is where the `audioplayers` AudioPlayer lives.
// Currently a Timer simulates progress. To go real:
//   final _ap = AudioPlayer();
//   togglePlay -> _ap.pause() / _ap.resume()
//   playAt     -> _ap.play(DeviceFileSource(track.localPath!))
//   seek       -> _ap.seek(pos)
//   _ap.onPositionChanged.listen((p) { position = p; notifyListeners(); });
//   _ap.onPlayerComplete.listen((_) => _onEnded());
//   _ap.onDurationChanged.listen(...)  -> replace Track.duration
// For lock-screen controls/queue, consider audio_service later.
// If you adopt Provider/Riverpod, expose this object there instead of the global.
// ─────────────────────────────────────────────────────────────
enum RepeatMode { off, all, one }

class PlayerController extends ChangeNotifier {
  final List<Track> queue = kTracks;
  int index = 0;
  bool isPlaying = false;
  bool shuffle = false;
  RepeatMode repeat = RepeatMode.off;
  Duration position = Duration.zero;

  // [BIND: SPOTIFY] Seed from GET /v1/me/tracks/contains (or a local liked-songs
  // DB). toggleLike -> PUT/DELETE /v1/me/tracks (requires user-library-modify scope).
  final Set<String> liked = {'t2'};

  Timer? _ticker;
  final _rng = Random();

  Track get current => queue[index];
  Duration get duration => current.duration;
  bool get isLiked => liked.contains(current.id);

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      position += const Duration(milliseconds: 250);
      if (position >= duration) _onEnded();
      notifyListeners();
    });
  }

  void _stopTicker() => _ticker?.cancel();

  void _onEnded() {
    if (repeat == RepeatMode.one) {
      position = Duration.zero;
    } else if (shuffle || repeat == RepeatMode.all || index < queue.length - 1) {
      next();
    } else {
      isPlaying = false;
      position = Duration.zero;
      _stopTicker();
    }
  }

  void playAt(int i) {
    index = i % queue.length;
    position = Duration.zero;
    isPlaying = true;
    _startTicker();
    notifyListeners();
  }

  void togglePlay() {
    isPlaying = !isPlaying;
    isPlaying ? _startTicker() : _stopTicker();
    notifyListeners();
  }

  void next() {
    if (shuffle && queue.length > 1) {
      int n;
      do {
        n = _rng.nextInt(queue.length);
      } while (n == index);
      index = n;
    } else {
      index = (index + 1) % queue.length;
    }
    position = Duration.zero;
    notifyListeners();
  }

  void previous() {
    if (position > const Duration(seconds: 3)) {
      position = Duration.zero;
    } else {
      index = (index - 1 + queue.length) % queue.length;
      position = Duration.zero;
    }
    notifyListeners();
  }

  void seek(Duration d) {
    position = d;
    notifyListeners();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = RepeatMode.values[(repeat.index + 1) % 3];
    notifyListeners();
  }

  void toggleLike() {
    liked.contains(current.id) ? liked.remove(current.id) : liked.add(current.id);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final player = PlayerController();

// ─────────────────────────────────────────────────────────────
// HELPERS / SHARED WIDGETS
// ─────────────────────────────────────────────────────────────
String fmt(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

Color shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// Placeholder artwork tile.
/// [BIND: SPOTIFY/LOCAL] Replace the gradient with the album image: the URL from
/// the API's `images[0].url` while online, or the artwork embedded in / saved
/// next to the downloaded .m4a (Image.file) when offline.
class ArtTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double? size;
  final double radius;
  const ArtTile({
    super.key,
    required this.color,
    this.icon = Icons.music_note,
    this.size,
    this.radius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [shade(color, 0.12), shade(color, -0.12)],
        ),
      ),
      child: LayoutBuilder(
        builder: (_, c) => Center(
          child: Icon(icon,
              color: Colors.white.withOpacity(0.85),
              size: (c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 48) * 0.42),
        ),
      ),
    );
  }
}

void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (_, __, ___) => const NowPlayingScreen(),
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      ),
      child: child,
    ),
  ));
}

// ─────────────────────────────────────────────────────────────
// APP + SHELL
// ─────────────────────────────────────────────────────────────
void main() => runApp(const MusicApp());

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Local Player',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const RootShell(),
      );
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body ends exactly at the top of the nav bar, so a bottom-pinned
      // MiniPlayer sits directly above it.
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: const [
              HomeScreen(),
              _PlaceholderScreen('Search'),
              _PlaceholderScreen('Your Library'), // [BIND: SPOTIFY] playlists + sync status
            ],
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.bg,
        selectedItemColor: Colors.white,
        unselectedItemColor: AppColors.muted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Your Library'),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen(this.title);
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.muted)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// SCREEN 1: HOME
// ─────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Extra bottom padding so content clears the mini player.
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + recent grid share a soft top gradient that melts into bg.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1F5C3F), AppColors.bg],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 12),
                  _recentGrid(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _shelf(context, 'Discover'),
        ],
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(_greeting,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.history)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
          ],
        ),
      );

  Widget _recentGrid() {
    // [BIND: SPOTIFY] Feed with GET /v1/me/player/recently-played (dedupe by
    // context URI) merged with local play history so it works offline.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 56,
        ),
        itemBuilder: (_, i) {
          final p = kRecent[i];
          return GestureDetector(
            onTap: () => player.playAt(i), // [BIND: AUDIO] play first local track of this playlist
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.overlay,
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  ArtTile(color: p.color, icon: p.icon, size: 56, radius: 0),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _shelf(BuildContext context, String title) {
    // [BIND: SPOTIFY] Feed with GET /v1/me/playlists (+ /v1/browse/featured-playlists
    // if available to your app). Show a "downloaded / not synced" badge per card
    // using the media manifest from your home server.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: kDiscover.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final p = kDiscover[i];
              return SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArtTile(color: p.color, icon: p.icon, size: 150, radius: 10),
                    const SizedBox(height: 8),
                    Text(p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(p.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted, height: 1.3)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SCREEN 2a: MINI PLAYER
// ─────────────────────────────────────────────────────────────
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final t = player.current;
        final progress = player.duration.inMilliseconds == 0
            ? 0.0
            : player.position.inMilliseconds / player.duration.inMilliseconds;

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: GestureDetector(
            onTap: () => openNowPlaying(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 60,
              decoration: BoxDecoration(
                color: Color.lerp(t.color, Colors.black, 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4, top: 6, bottom: 6),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'np-art',
                          child: ArtTile(color: t.color, size: 46, radius: 4),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700)),
                              Text(t.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: player.toggleLike,
                          icon: Icon(
                            player.isLiked ? Icons.check_circle : Icons.add_circle_outline,
                            color: player.isLiked ? AppColors.accent : Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: player.togglePlay,
                          icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 30),
                        ),
                      ],
                    ),
                  ),
                  // Thin progress line
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 2,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SCREEN 2b: NOW PLAYING (full screen)
// ─────────────────────────────────────────────────────────────
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final t = player.current;
        return Scaffold(
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(t.color, Colors.black, 0.25)!, AppColors.bg],
                stops: const [0.0, 0.85],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _topBar(context),
                    const Spacer(),
                    _artwork(t),
                    const Spacer(),
                    _titleRow(t),
                    const SizedBox(height: 12),
                    _timeline(context),
                    const SizedBox(height: 8),
                    _controls(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context) => Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          ),
          const Expanded(
            child: Column(
              children: [
                Text('PLAYING FROM PLAYLIST',
                    style: TextStyle(
                        fontSize: 10, letterSpacing: 1.2, color: AppColors.muted)),
                SizedBox(height: 2),
                // [BIND: SPOTIFY] Active playlist/context name.
                Text('Travel Mix',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      );

  Widget _artwork(Track t) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: Hero(
            tag: 'np-art',
            child: ArtTile(color: t.color, radius: 12),
          ),
        ),
      );

  Widget _titleRow(Track t) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            onPressed: player.toggleLike,
            iconSize: 28,
            icon: Icon(
              player.isLiked ? Icons.check_circle : Icons.add_circle_outline,
              color: player.isLiked ? AppColors.accent : Colors.white,
            ),
          ),
        ],
      );

  Widget _timeline(BuildContext context) {
    final durMs = player.duration.inMilliseconds.toDouble();
    final posMs = player.position.inMilliseconds.clamp(0, player.duration.inMilliseconds).toDouble();
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: posMs,
            max: durMs,
            // [BIND: AUDIO] onChanged/onChangeEnd -> audioPlayer.seek(Duration(...))
            onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fmt(player.position),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              Text(fmt(player.duration),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controls() {
    final repeatIcon = player.repeat == RepeatMode.one ? Icons.repeat_one : Icons.repeat;
    final repeatOn = player.repeat != RepeatMode.off;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: player.toggleShuffle,
          icon: Icon(Icons.shuffle,
              color: player.shuffle ? AppColors.accent : Colors.white),
        ),
        IconButton(
          onPressed: player.previous,
          iconSize: 38,
          icon: const Icon(Icons.skip_previous),
        ),
        GestureDetector(
          onTap: player.togglePlay,
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black, size: 40),
          ),
        ),
        IconButton(
          onPressed: player.next,
          iconSize: 38,
          icon: const Icon(Icons.skip_next),
        ),
        IconButton(
          onPressed: player.cycleRepeat,
          icon: Icon(repeatIcon, color: repeatOn ? AppColors.accent : Colors.white),
        ),
      ],
    );
  }
}
