import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class DictationPage extends StatefulWidget {
  const DictationPage({super.key});

  @override
  _DictationPageState createState() => _DictationPageState();
}

class _DictationPageState extends State<DictationPage> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<String> _chunks = [];
  int _currentChunkIndex = 0;
  bool _isSpeaking = false;
  bool _isListening = false;
  double _pitch = 1.0;
  int _wordCount = 5;
  double _speechRate = 0.4;

  @override
  void dispose() {
    _controller.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> initDicto() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(_pitch);

    _tts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() async {
      setState(() => _isSpeaking = false);
      _listenForNextCommand();
    });
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _startDictation() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await initDicto();

    _chunks = _splitText(text, _wordCount);
    _currentChunkIndex = 0;
    _speakNextChunk();
  }

  List<String> _splitText(String text, int chunkSize) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];

    for (int i = 0; i < words.length; i += chunkSize) {
      final chunk = words.sublist(
          i, (i + chunkSize > words.length) ? words.length : i + chunkSize);
      chunks.add(chunk.join(' '));
    }

    return chunks;
  }

  Future<void> _speakNextChunk() async {
    if (_currentChunkIndex >= _chunks.length) return;

    final chunk = _chunks[_currentChunkIndex];
    // setState(() => _isSpeaking = true);

    // await _tts.setLanguage('en-US');
    // await _tts.setSpeechRate(0.4);
    await _tts.speak(chunk);

    // _tts.setCompletionHandler(() async {
    //   setState(() => _isSpeaking = false);
    //   _listenForNextCommand();
    // });
  }

  Future<void> _listenForNextCommand() async {
    if (!await _requestMicPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Microphone permission is required to listen for commands.',
          ),
        ),
      );
      return;
    }
    if (!_isListening && await _speech.initialize()) {
      setState(() => _isListening = true);

      _speech.listen(
        onResult: (result) {
          final command = result.recognizedWords.toLowerCase();
          if (command.contains("next") ||
              command.contains("yes") ||
              command.contains("hmm")) {
            _currentChunkIndex++;
            _speakNextChunk();
          } else if (command.contains("what") || command.contains("repeat")) {
            _speakNextChunk();
          }
          _speech.stop();
          setState(() => _isListening = false);
        },
        listenFor: Duration(seconds: 10),
        // pauseFor: Duration(seconds: 2),
        partialResults: false,
        localeId: 'en_US',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dictation Assistant')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Pitch: $_pitch',
              style: TextStyle(fontSize: 18),
            ),
            Slider(
              value: _pitch,
              onChanged: (pitch) {
                setState(() => _pitch = pitch);
                _tts.setPitch(pitch);
              },
              min: 0.5,
              max: 2.0,
              divisions: 15,
            ),
            SizedBox(height: 20),
            Text(
              'Word Count: $_wordCount',
              style: TextStyle(fontSize: 18),
            ),
            Slider(
              value: _wordCount.toDouble(),
              onChanged: (wordCount) {
                setState(() => _wordCount = wordCount.toInt());
              },
              min: 1,
              max: 15,
            ),
            SizedBox(height: 20),
            Text(
              'Speech Rate: ${(_speechRate * 100).toInt()}%',
              style: TextStyle(fontSize: 18),
            ),
            Slider(
              value: _speechRate,
              onChanged: (rate) {
                setState(() => _speechRate = rate);
                _tts.setSpeechRate(rate);
              },
              min: 0.1,
              max: 1.0,
              divisions: 10,
            ),
            SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your text or notes here...',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSpeaking ? null : _startDictation,
              child: Text('Start Dictation'),
            ),
            if (_isListening)
              Text(
                '🎤 Listening for "next", "yes", or "hmm"...',
              ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _isSpeaking ? null : _speakNextChunk,
                  child: Text('Repeat Last'),
                ),
                ElevatedButton(
                  onPressed: _isSpeaking
                      ? () {
                          _tts.stop();
                          setState(() => _isSpeaking = false);
                        }
                      : null,
                  child: Text('Stop'),
                ),
                ElevatedButton(
                  onPressed: _isSpeaking
                      ? null
                      : () {
                          _currentChunkIndex++;
                          _speakNextChunk();
                        },
                  child: Text('Speak next'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
