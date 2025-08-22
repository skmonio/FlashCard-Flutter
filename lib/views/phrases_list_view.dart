import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/phrase_provider.dart';
import '../models/phrase.dart';
import 'phrase_exercise_detail_view.dart';
import 'add_phrase_view.dart';

class PhrasesListView extends StatefulWidget {
  const PhrasesListView({super.key});

  @override
  State<PhrasesListView> createState() => _PhrasesListViewState();
}

class _PhrasesListViewState extends State<PhrasesListView> {
  String _searchQuery = '';
  String _sortOption = 'A-Z';
  bool _isSelectionMode = false;
  Set<String> _selectedPhraseIds = {};
  bool _selectAll = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrases'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: _isSelectionMode ? _buildSelectionActions() : _buildHeaderActions(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddPhrase(),
        tooltip: 'Add Phrase',
        child: const Icon(Icons.add),
      ),
      body: Consumer<PhraseProvider>(
        builder: (context, phraseProvider, child) {
          final phrases = phraseProvider.phrases;
          
          if (phrases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.translate,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No phrases yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your first phrase to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddPhrase(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Phrase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }
          
          final filteredPhrases = _getFilteredAndSortedPhrases(phrases);
          
          return Column(
            children: [
              // Search and filter section
              _buildSearchAndFilterSection(),
              
              // Phrases list
              Expanded(
                child: filteredPhrases.isEmpty
                    ? _buildEmptyState()
                    : _buildPhrasesList(filteredPhrases),
              ),
            ],
          );
        },
      ),
    );
  }



  Widget _buildPhraseCard(Phrase phrase) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _openPhraseExercise(phrase),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phrase and translation
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            phrase.phrase,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phrase.translation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Learning percentage
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getProgressColor(phrase.learningPercentage).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getProgressColor(phrase.learningPercentage).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${phrase.learningPercentage.toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getProgressColor(phrase.learningPercentage),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Progress bar
                LinearProgressIndicator(
                  value: phrase.learningPercentage / 100,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(phrase.learningPercentage),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Status and actions
                Row(
                  children: [
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(phrase).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(phrase),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(phrase),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Menu button
                    PopupMenuButton<String>(
                      onSelected: (action) => _handlePhraseAction(action, phrase),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'practice',
                          child: Row(
                            children: [
                              Icon(Icons.play_arrow),
                              SizedBox(width: 8),
                              Text('Practice'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(num percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    if (percentage >= 40) return Colors.yellow;
    return Colors.red;
  }

  Color _getStatusColor(Phrase phrase) {
    if (phrase.isNew) return Colors.blue;
    if (phrase.isDueForReview) return Colors.red;
    if (phrase.learningPercentage >= 100) return Colors.green;
    return Colors.orange;
  }

  String _getStatusText(Phrase phrase) {
    if (phrase.isNew) return 'New';
    if (phrase.isDueForReview) return 'Due';
    if (phrase.learningPercentage >= 100) return 'Learned';
    return 'Learning';
  }

  void _openPhraseExercise(Phrase phrase) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhraseExerciseDetailView(
          phrase: phrase,
          onComplete: (wasSuccessful) {
            // Optionally show a success message or update UI
            if (wasSuccessful) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Great job! Keep practicing!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _handlePhraseAction(String action, Phrase phrase) {
    switch (action) {
      case 'practice':
        _openPhraseExercise(phrase);
        break;
      case 'edit':
        _editPhrase(phrase);
        break;
      case 'delete':
        _showDeleteConfirmation(phrase);
        break;
    }
  }

  void _editPhrase(Phrase phrase) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddPhraseView(editingPhrase: phrase),
      ),
    );
  }

  void _showDeleteConfirmation(Phrase phrase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Phrase'),
        content: Text('Are you sure you want to delete "${phrase.phrase}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePhrase(phrase);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deletePhrase(Phrase phrase) {
    final phraseProvider = context.read<PhraseProvider>();
    phraseProvider.deletePhrase(phrase.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${phrase.phrase}"'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _navigateToAddPhrase() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddPhraseView(),
      ),
    );
  }

  // New methods for updated UI
  List<Widget> _buildHeaderActions() {
    return [
      IconButton(
        onPressed: _toggleSelectionMode,
        icon: const Icon(Icons.select_all),
        tooltip: 'Select',
      ),
    ];
  }

  List<Widget> _buildSelectionActions() {
    return [
      // Select All Toggle
      IconButton(
        onPressed: () {
          setState(() {
            if (_selectAll) {
              _selectedPhraseIds.clear();
              _selectAll = false;
            } else {
              final provider = context.read<PhraseProvider>();
              final phrases = _getFilteredAndSortedPhrases(provider.phrases);
              final phraseIds = phrases.map((p) => p.id).toSet();
              _selectedPhraseIds = phraseIds;
              _selectAll = true;
            }
          });
        },
        icon: Icon(_selectAll ? Icons.check_box : Icons.check_box_outline_blank),
        tooltip: _selectAll ? 'Deselect All' : 'Select All',
      ),
      
      // Delete Selected
      if (_selectedPhraseIds.isNotEmpty)
        IconButton(
          onPressed: () => _showDeleteSelectedDialog(),
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete Selected',
        ),
      
      // Selection Count
      if (_selectedPhraseIds.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_selectedPhraseIds.length}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
    ];
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search bar
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search phrases...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Sort Button
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortOption = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'A-Z',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward),
                    SizedBox(width: 8),
                    Text('A-Z'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Z-A',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward),
                    SizedBox(width: 8),
                    Text('Z-A'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sortOption == 'A-Z' ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sortOption,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Phrase> _getFilteredAndSortedPhrases(List<Phrase> phrases) {
    var filteredPhrases = List<Phrase>.from(phrases);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filteredPhrases = filteredPhrases.where((phrase) =>
        phrase.phrase.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        phrase.translation.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Sort phrases
    if (_sortOption == 'A-Z') {
      filteredPhrases.sort((a, b) => a.phrase.toLowerCase().compareTo(b.phrase.toLowerCase()));
    } else if (_sortOption == 'Z-A') {
      filteredPhrases.sort((a, b) => b.phrase.toLowerCase().compareTo(a.phrase.toLowerCase()));
    }
    
    return filteredPhrases;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.translate,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No phrases found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first phrase to get started',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddPhrase(),
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Phrase'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhrasesList(List<Phrase> phrases) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: phrases.length,
      itemBuilder: (context, index) {
        final phrase = phrases[index];
        final isSelected = _selectedPhraseIds.contains(phrase.id);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: _isSelectionMode ? () => _togglePhraseSelection(phrase.id) : () => _openPhraseExercise(phrase),
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _selectedPhraseIds.add(phrase.id);
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSelectionMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) => _togglePhraseSelection(phrase.id),
                        activeColor: Colors.green,
                      ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(
                          '${phrase.learningPercentage.toInt()}%',
                          style: TextStyle(
                            color: Colors.teal[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        phrase.phrase,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phrase.translation,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Added: ${_formatDate(phrase.dateCreated)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                trailing: _isSelectionMode ? null : PopupMenuButton<String>(
                  onSelected: (value) => _handlePhraseAction(value, phrase),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'practice',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow, size: 16),
                          SizedBox(width: 8),
                          Text('Practice'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPhraseIds.clear();
        _selectAll = false;
      }
    });
  }

  void _togglePhraseSelection(String phraseId) {
    setState(() {
      if (_selectedPhraseIds.contains(phraseId)) {
        _selectedPhraseIds.remove(phraseId);
        _selectAll = false;
      } else {
        _selectedPhraseIds.add(phraseId);
      }
    });
  }

  void _showDeleteSelectedDialog() {
    if (_selectedPhraseIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Phrases'),
        content: Text(
          'Are you sure you want to delete ${_selectedPhraseIds.length} phrase(s)?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSelectedPhrases();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedPhrases() {
    final phraseProvider = context.read<PhraseProvider>();
    final selectedCount = _selectedPhraseIds.length;
    
    for (final phraseId in _selectedPhraseIds) {
      final phrase = phraseProvider.phrases.firstWhere((p) => p.id == phraseId);
      phraseProvider.deletePhrase(phrase.id);
    }
    
    setState(() {
      _selectedPhraseIds.clear();
      _selectAll = false;
      _isSelectionMode = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedCount phrase(s) deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
