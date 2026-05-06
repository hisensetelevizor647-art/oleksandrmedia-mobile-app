import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const String kGoogleOauthClientId =
    '1034187669203-7ssee2rn0ldvhv1c6q7pmrkckj9evvd6.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final VideoRepository repository = VideoRepository();
  await repository.init();

  final AppController controller = AppController(repository: repository);
  await controller.init();

  runApp(OleksandrMediaApp(controller: controller));
}

class OleksandrMediaApp extends StatelessWidget {
  const OleksandrMediaApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OleksandrMedia Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0057FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0C111B),
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) {
          if (!controller.ready) {
            return const SplashScreen();
          }
          if (controller.currentUser == null) {
            return LoginScreen(controller: controller);
          }
          return HomeScreen(controller: controller);
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0D1B3A),
              Color(0xFF14213D),
              Color(0xFF1F2937),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: const Color(0xCC111827),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'OleksandrMedia',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mobile app with encrypted local storage',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: controller.authBusy
                          ? null
                          : () async {
                              await controller.signInWithGoogle();
                            },
                      icon: controller.authBusy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      controller.authError ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final GoogleSignInAccount user = controller.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OleksandrMedia Mobile'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async => controller.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final bool? created = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (BuildContext _) => AddVideoScreen(controller: controller),
            ),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video saved locally (encrypted box).'),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Hello, ${user.displayName ?? user.email}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'All metadata is stored locally in an encrypted Hive box.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: controller.videos.isEmpty
                      ? const Center(
                          child: Text(
                            'Local library is empty. Add your first video.',
                          ),
                        )
                      : ListView.separated(
                          itemCount: controller.videos.length,
                          separatorBuilder: (BuildContext _, int __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final VideoEntry video = controller.videos[index];
                            return VideoCard(
                              video: video,
                              onDelete: () async =>
                                  controller.deleteVideo(video.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AddVideoScreen extends StatefulWidget {
  const AddVideoScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AddVideoScreen> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends State<AddVideoScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _useUrl = false;
  String? _filePath;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickVideoFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _filePath = result.files.first.path;
      });
    }
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    final String url = _urlController.text.trim();
    final String? source = _useUrl ? url : _filePath;

    if (title.isEmpty || source == null || source.isEmpty) {
      setState(() {
        _error = 'Set title and video source (URL or file).';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.controller.addVideo(
        title: title,
        description: description,
        source: source,
        sourceType: _useUrl ? VideoSourceType.url : VideoSourceType.file,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _error = 'Save error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add video')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text('File'),
                  icon: Icon(Icons.folder),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('URL'),
                  icon: Icon(Icons.link),
                ),
              ],
              selected: <bool>{_useUrl},
              onSelectionChanged: (Set<bool> values) {
                setState(() {
                  _useUrl = values.first;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_useUrl)
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Video URL',
                  border: OutlineInputBorder(),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _pickVideoFile,
                    icon: const Icon(Icons.video_file),
                    label: const Text('Pick video file'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _filePath ?? 'No file selected',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save locally'),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, required this.onDelete});

  final VideoEntry video;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          video.sourceType == VideoSourceType.file
              ? Icons.video_file
              : Icons.public,
        ),
        title: Text(video.title),
        subtitle: Text(
          '${video.description.isEmpty ? 'No description' : video.description}\n'
          '${video.source}\n'
          '${DateFormat('yyyy-MM-dd HH:mm').format(video.createdAt)}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

enum VideoSourceType { file, url }

class VideoEntry {
  VideoEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.source,
    required this.sourceType,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String source;
  final VideoSourceType sourceType;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'source': source,
      'sourceType': sourceType.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VideoEntry.fromJson(Map<String, dynamic> json) {
    return VideoEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      source: json['source'] as String,
      sourceType: (json['sourceType'] as String) == VideoSourceType.file.name
          ? VideoSourceType.file
          : VideoSourceType.url,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class VideoRepository {
  static const String _boxName = 'oleksandrmedia_encrypted_box';
  static const String _videosKey = 'videos';
  static const String _hiveEncryptionKeyName = 'oleksandrmedia_hive_key_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  late Box<String> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    final List<int> key = await _getOrCreateEncryptionKey();
    _box = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: HiveAesCipher(key),
    );
  }

  Future<List<VideoEntry>> loadVideos() async {
    final String? raw = _box.get(_videosKey);
    if (raw == null || raw.isEmpty) {
      return <VideoEntry>[];
    }

    final List<dynamic> data = jsonDecode(raw) as List<dynamic>;
    return data
        .map(
          (dynamic item) => VideoEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList()
      ..sort(
        (VideoEntry a, VideoEntry b) => b.createdAt.compareTo(a.createdAt),
      );
  }

  Future<void> saveVideos(List<VideoEntry> videos) async {
    final String raw = jsonEncode(
      videos.map((VideoEntry v) => v.toJson()).toList(),
    );
    await _box.put(_videosKey, raw);
  }

  Future<List<int>> _getOrCreateEncryptionKey() async {
    final String? savedKey = await _secureStorage.read(
      key: _hiveEncryptionKeyName,
    );
    if (savedKey != null && savedKey.isNotEmpty) {
      return base64Decode(savedKey);
    }

    final Random random = Random.secure();
    final List<int> key = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.write(
      key: _hiveEncryptionKeyName,
      value: base64Encode(key),
    );
    return key;
  }
}

class AppController extends ChangeNotifier {
  AppController({required this.repository});

  final VideoRepository repository;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  final Uuid _uuid = const Uuid();

  bool ready = false;
  bool authBusy = false;
  String? authError;

  GoogleSignInAccount? currentUser;
  List<VideoEntry> videos = <VideoEntry>[];

  Future<void> init() async {
    _googleSignIn.authenticationEvents
        .listen(_handleAuthEvent)
        .onError(_handleAuthError);

    await _googleSignIn.initialize(serverClientId: kGoogleOauthClientId);
    await _googleSignIn.attemptLightweightAuthentication();
    videos = await repository.loadVideos();
    ready = true;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    authBusy = true;
    authError = null;
    notifyListeners();

    try {
      if (_googleSignIn.supportsAuthenticate()) {
        await _googleSignIn.authenticate();
      } else {
        throw UnsupportedError('This platform does not support authenticate().');
      }
    } on GoogleSignInException catch (e) {
      authError = 'Google Sign-In: ${e.code.name} ${e.description ?? ''}'.trim();
    } catch (e) {
      authError = '$e';
    } finally {
      authBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<void> addVideo({
    required String title,
    required String description,
    required String source,
    required VideoSourceType sourceType,
  }) async {
    final VideoEntry entry = VideoEntry(
      id: _uuid.v4(),
      title: title,
      description: description,
      source: source,
      sourceType: sourceType,
      createdAt: DateTime.now(),
    );

    videos = <VideoEntry>[entry, ...videos];
    await repository.saveVideos(videos);
    notifyListeners();
  }

  Future<void> deleteVideo(String id) async {
    videos = videos.where((VideoEntry e) => e.id != id).toList();
    await repository.saveVideos(videos);
    notifyListeners();
  }

  void _handleAuthEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        currentUser = event.user;
      case GoogleSignInAuthenticationEventSignOut():
        currentUser = null;
    }
    notifyListeners();
  }

  void _handleAuthError(Object error) {
    if (error is GoogleSignInException) {
      authError =
          'Google Sign-In: ${error.code.name} ${error.description ?? ''}'.trim();
    } else {
      authError = error.toString();
    }
    notifyListeners();
  }
}
