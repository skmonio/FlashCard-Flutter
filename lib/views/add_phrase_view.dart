import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/phrase_provider.dart';
import '../services/sound_manager.dart';
import '../services/haptic_service.dart';
import '../models/phrase.dart';

class AddPhraseView extends StatefulWidget {
  final Phrase? editingPhrase;
  
  const AddPhraseView({super.key, this.editingPhrase});

  @override
  State<AddPhraseView> createState() => _AddPhraseViewState();
}

class _AddPhraseViewState extends State<AddPhraseView> {
  final _phraseController = TextEditingController();
  final _translationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isTranslating = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if editing
    if (widget.editingPhrase != null) {
      _phraseController.text = widget.editingPhrase!.phrase;
      _translationController.text = widget.editingPhrase!.translation;
    }
  }

  @override
  void dispose() {
    _phraseController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  Future<void> _translatePhrase() async {
    if (_phraseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phrase to translate')),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final translation = await context.read<PhraseProvider>().translatePhrase(
        _phraseController.text.trim(),
      );

      if (translation != null) {
        _translationController.text = translation;
        HapticService().lightImpact();
        SoundManager().playCorrectSound();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Translation failed. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  Future<void> _savePhrase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.editingPhrase != null) {
        // Update existing phrase
        await context.read<PhraseProvider>().updatePhrase(
          widget.editingPhrase!.id,
          _phraseController.text.trim(),
          _translationController.text.trim(),
        );
      } else {
        // Add new phrase
        await context.read<PhraseProvider>().addPhrase(
          _phraseController.text.trim(),
          _translationController.text.trim(),
        );
      }

      HapticService().successFeedback();
      SoundManager().playCompleteSound();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editingPhrase != null ? 'Phrase updated successfully!' : 'Phrase added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${widget.editingPhrase != null ? 'updating' : 'saving'} phrase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingPhrase != null ? 'Edit Phrase' : 'Add Phrase'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Phrase Input
              TextFormField(
                controller: _phraseController,
                decoration: const InputDecoration(
                  labelText: 'Dutch Phrase',
                  hintText: 'e.g., Ik vind het niet leuk',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.translate),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a phrase';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Translate Button
              ElevatedButton.icon(
                onPressed: _isTranslating ? null : _translatePhrase,
                icon: _isTranslating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate),
                label: Text(_isTranslating ? 'Translating...' : 'Translate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Translation Input
              TextFormField(
                controller: _translationController,
                decoration: const InputDecoration(
                  labelText: 'English Translation',
                  hintText: 'e.g., I don\'t like it',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a translation';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePhrase,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Phrase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),

              // Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'About Phrases',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Phrases are separate from flashcards and decks\n'
                        '• Each phrase will have translation and sentence builder exercises\n'
                        '• Progress is tracked individually for each phrase\n'
                        '• Use the Translate button for quick translations',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
