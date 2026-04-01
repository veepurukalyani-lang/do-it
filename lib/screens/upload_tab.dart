import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:image_picker/image_picker.dart';
import '../app_state.dart';
import '../models/post.dart';
import '../services/firebase_service.dart';
import '../services/media_service.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player/video_player.dart';
import '../widgets/auth_prompt_dialog.dart';

class UploadTab extends StatefulWidget {
  const UploadTab({super.key});

  @override
  State<UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends State<UploadTab> {
  final _titleController = TextEditingController();
  final _promptController = TextEditingController();
  final _toolController = TextEditingController();
  
  bool _hasMedia = false;
  XFile? _pickedFile;
  Uint8List? _mediaBytes;
  XFile? _thumbnailFile;
  Uint8List? _thumbnailBytes;
  bool _isVideo = false;
  final ImagePicker _picker = ImagePicker();

  // Progress tracking
  bool _isUploading = false;
  String _uploadStage = '';
  double _uploadProgress = 0.0;

  Future<void> _pickMedia() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Select Media Type',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.purpleAccent),
              title: const Text('Image'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.purpleAccent),
              title: const Text('Reel (Video)'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    // Clear old data when picking new category
    _titleController.clear();
    _promptController.clear();
    _toolController.clear();

    final XFile? file = source == 'image'
        ? await _picker.pickImage(source: ImageSource.gallery)
        : await _picker.pickVideo(source: ImageSource.gallery);

    if (file != null) {
      if (source == 'video') {
        // Use the correct controller depending on platform:
        // - Web: networkUrl with a blob URL
        // - Native: file() for a real filesystem path
        final VideoPlayerController tempController = kIsWeb
            ? VideoPlayerController.networkUrl(Uri.parse(file.path))
            : VideoPlayerController.networkUrl(Uri.parse(file.path)); // Fallback for now to avoid dart:io
        try {
          await tempController.initialize();
          final duration = tempController.value.duration;
          await tempController.dispose();

          if (duration.inSeconds > 60) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reels must be under 1 minute. Please select a shorter video.'), backgroundColor: Colors.redAccent),
              );
            }
            return;
          }
        } catch (e) {
          // If duration check fails for any reason, still allow the upload.
          debugPrint('Video duration check error: $e');
          await tempController.dispose();
        }

        // Auto generate thumbnail (skip on web and desktop for now as video_compress is mobile-only)
        final bool isMobile = !kIsWeb; 
        if (isMobile) {
          setState(() {
            _isUploading = true;
            _uploadStage = 'Generating preview...';
          });
          
          try {
            final XFile? thumbnailFile = await MediaService.instance.generateVideoThumbnail(file);
            if (thumbnailFile != null) {
              final thumbBytes = await thumbnailFile.readAsBytes();
              setState(() {
                _thumbnailFile = XFile(thumbnailFile.path);
                _thumbnailBytes = thumbBytes;
              });
            }
          } catch (e) {
            debugPrint('Thumbnail generation failed: $e');
          } finally {
            setState(() => _isUploading = false);
          }
        }
      }

      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFile = file;
        _mediaBytes = bytes;
        _hasMedia = true;
        _isVideo = source == 'video';
      });
    }
  }

  Future<void> _pickThumbnail() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _thumbnailFile = image;
        _thumbnailBytes = bytes;
      });
    }
  }

  void _submit() async {
    if (!_hasMedia || _pickedFile == null || _isUploading) return;

    // Must be logged in with a real Firebase account to upload
    if (!appState.isLoggedIn) {
      AuthPromptDialog.show(
        context,
        title: 'Sign in to publish',
        subtitle: 'Create an account to share your AI art with the world.',
      );
      return;
    }
    
    setState(() {
      _isUploading = true;
      _uploadStage = 'Initializing...';
      _uploadProgress = 0.0;
    });
    
    try {
      Uint8List? mediaToUpload;
      Uint8List? thumbToUpload;

      final bool isMobile = !kIsWeb;

      // Compress if it's a video and on mobile
      if (_isVideo && isMobile) {
        setState(() {
          _uploadStage = 'Compressing video...';
          _uploadProgress = 0.0;
        });

        final XFile? compressedVideo = await MediaService.instance.compressVideo(
          _pickedFile!,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress / 100; // video_compress returns 0-100
              });
            }
          },
        );

        if (compressedVideo != null) {
          mediaToUpload = await compressedVideo.readAsBytes();
          debugPrint('Video compressed: ${compressedVideo.path}');
        }
      } else if (!_isVideo && isMobile) {
        // Optional: Compress image too
        setState(() => _uploadStage = 'Optimizing image...');
        final XFile? compressedImage = await MediaService.instance.compressImage(_pickedFile!);
        if (compressedImage != null) {
          mediaToUpload = await compressedImage.readAsBytes();
        }
      }

      // If no compression happened or compression failed, use the original bytes
      mediaToUpload ??= _mediaBytes;
      
      if (_thumbnailBytes != null) {
        thumbToUpload = _thumbnailBytes;
      }

      if (mediaToUpload == null) {
        throw Exception('File data is missing or could not be read.');
      }

      await firebaseService.uploadPost(
        caption: _titleController.text.isNotEmpty ? _titleController.text : (_isVideo ? 'New Video' : 'New AI Art'),
        prompt: _isVideo ? '' : _promptController.text.trim(),
        toolsUsed: _isVideo ? '' : _toolController.text.trim(),
        file: mediaToUpload,
        isVideo: _isVideo,
        thumbnailFile: thumbToUpload,
        username: appState.currentUser,
        profileImage: appState.currentUserProfileImage,
        onProgress: (stage, progress) {
          if (mounted) {
            setState(() {
              _uploadStage = stage;
              _uploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isVideo ? 'Video published successfully!' : 'Creation shared successfully!'),
            backgroundColor: Colors.purpleAccent,
          ),
        );
        
        // Reset form
        setState(() {
          _titleController.clear();
          _promptController.clear();
          _toolController.clear();
          _hasMedia = false;
          _pickedFile = null;
          _mediaBytes = null;
          _thumbnailFile = null;
          _thumbnailBytes = null;
          _isVideo = false;
          _isUploading = false;
          _uploadStage = '';
          _uploadProgress = 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Upload Area
            GestureDetector(
              onTap: _isUploading ? null : _pickMedia,
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1.5, style: BorderStyle.solid),
                ),
                child: _hasMedia
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _isVideo
                                ? Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.play_circle_fill, size: 80, color: Colors.white70),
                                          SizedBox(height: 12),
                                          Text('Video Ready to Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  )
                                : Image.memory(
                                    _mediaBytes!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          if (!_isUploading)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.white, size: 28),
                                onPressed: () {
                                  setState(() {
                                    _hasMedia = false;
                                    _pickedFile = null;
                                    _mediaBytes = null;
                                    _thumbnailFile = null;
                                    _thumbnailBytes = null;
                                    _isVideo = false;
                                    _titleController.clear();
                                    _promptController.clear();
                                    _toolController.clear();
                                  });
                                },
                              ),
                            ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_photo_alternate, size: 48, color: Colors.purpleAccent),
                          ),
                          const SizedBox(height: 16),
                          const Text('Select AI Art or Reel', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Share your creativity with the world', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
              ),
            ),
            
            if (_hasMedia && _isVideo) ...[
              const SizedBox(height: 24),
              const Text('Reel Thumbnail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _isUploading ? null : _pickThumbnail,
                child: Container(
                  height: 120,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    image: _thumbnailBytes != null 
                        ? DecorationImage(image: MemoryImage(_thumbnailBytes!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _thumbnailBytes == null 
                      ? const Icon(Icons.add_a_photo, color: Colors.grey)
                      : Container(
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.all(4),
                          color: Colors.black26,
                          child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                ),
              ),
            ],
            if (_hasMedia) ...[
              const SizedBox(height: 24),
              const Text('Caption', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                enabled: !_isUploading,
                decoration: InputDecoration(
                  hintText: _isVideo ? 'What\'s this reel about?' : 'Give your masterpiece a title...',
                  filled: true,
                  fillColor: Colors.grey[50],
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.purpleAccent)),
                  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[100]!)),
                ),
              ),
              const SizedBox(height: 20),

              if (!_isVideo) ...[
                const Text('The Prompt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                TextField(
                  controller: _promptController,
                  enabled: !_isUploading,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share the secret sauce (optional)...',
                    filled: true,
                    fillColor: Colors.grey[50],
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.purpleAccent)),
                    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[100]!)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    const Text('Prompts enable the "Try It" feature for others.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 20),

                const Text('AI Tool Used', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '' || _isUploading) {
                      return const Iterable<String>.empty();
                    }
                    const _tools = ['Midjourney', 'DALL-E 3', 'Stable Diffusion', 'Leonardo AI', 'Runway', 'Pika Labs', 'Sora', 'HeyGen', 'Luma Dream Machine'];
                    return _tools.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _toolController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    if (_toolController.text.isNotEmpty && controller.text.isEmpty) {
                       controller.text = _toolController.text;
                    }
                    controller.addListener(() {
                      _toolController.text = controller.text;
                    });
                    
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !_isUploading,
                      decoration: InputDecoration(
                        hintText: 'e.g. Midjourney, DALL-E, Higgsfield...',
                        filled: true,
                        fillColor: Colors.grey[50],
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.purpleAccent)),
                        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[100]!)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ] else ...[
                const SizedBox(height: 20),
              ],

              // Publish Button with Progress
              Column(
                children: [
                  if (_isUploading) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_uploadStage, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('${(_uploadProgress * 100).toInt()}%', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: _isUploading 
                            ? [Colors.grey[300]!, Colors.grey[400]!] 
                            : [Colors.purpleAccent, Colors.pinkAccent],
                      ),
                      boxShadow: _isUploading ? null : [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(
                        _isUploading ? 'Uploading...' : (_isVideo ? 'Publish Reel' : 'Share Creation'),
                        style: TextStyle(
                          color: _isUploading ? Colors.grey[600] : Colors.white, 
                          fontSize: 17, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ]
          ],
        ),
      ),
    );
  }
}
