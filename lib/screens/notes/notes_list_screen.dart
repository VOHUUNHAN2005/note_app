import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:note_app/database/db_helper.dart';
import 'package:note_app/screens/notes/note_editor_screen.dart';
import 'package:note_app/screens/topics/topics_list_screen.dart';

class NotesListScreen extends StatefulWidget {
  final List<Topic> topics;

  const NotesListScreen({
    super.key,
    required this.topics,
  });

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Note> _allNotes = [];      
  List<Note> _filteredNotes = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String? _selectedTopicId; 
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topics != widget.topics) {
      _loadNotes();
    }
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final loadedNotes = await DatabaseHelper.instance.getNotes(widget.topics);

    setState(() {
      _allNotes = loadedNotes;
      _isLoading = false;
    });
    _applyFilterAndSearch();
  }

  void _applyFilterAndSearch() {
    List<Note> temp = List.from(_allNotes);

    if (_selectedTopicId != null) {
      temp = temp.where((note) => note.topic?.id == _selectedTopicId).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      temp = temp.where((note) {
        final titleMatch = note.title.toLowerCase().contains(query);
        final contentMatch = note.content.toLowerCase().contains(query);
        return titleMatch || contentMatch;
      }).toList();
    }

    setState(() {
      _filteredNotes = temp;
    });
  }

  String _formatContent(String content) {
    if (content.length <= 20) {
      return content;
    }
    return '${content.substring(0, 20)}...';
  }

  void _deleteNote(String id) async {
    await DatabaseHelper.instance.deleteNote(id);
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách Ghi chú'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tiêu đề, nội dung...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                _applyFilterAndSearch();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _applyFilterAndSearch();
                    },
                  ),
                ),

                if (widget.topics.isNotEmpty)
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: const Text('Tất cả'),
                            selected: _selectedTopicId == null,
                            onSelected: (bool selected) {
                              setState(() {
                                _selectedTopicId = null;
                              });
                              _applyFilterAndSearch();
                            },
                          ),
                        ),
                        ...widget.topics.map((topic) {
                          final isSelected = _selectedTopicId == topic!.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              avatar: CircleAvatar(
                                backgroundColor: topic.color,
                                radius: 6,
                              ),
                              label: Text(
                                topic.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : topic.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: topic.color,
                              onSelected: (bool selected) {
                                setState(() {
                                  _selectedTopicId = selected ? topic.id : null;
                                });
                                _applyFilterAndSearch();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                Expanded(
                  child: _filteredNotes.isEmpty
                      ? const Center(
                          child: Text(
                            'Không tìm thấy ghi chú phù hợp.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = _filteredNotes[index];
                            final formattedDate =
                                DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt);

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            note.title,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          onPressed: () => _deleteNote(note.id),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    if (note.topic != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: note.topic!.color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: note.topic!.color, width: 1.5),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: note.topic!.color,
                                              radius: 6,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              note.topic!.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: note.topic!.color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _formatContent(note.content),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Tạo lúc: $formattedDate',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        IconButton(
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => NoteEditorScreen(
                                                  note: note,
                                                  topics: widget.topics,
                                                ),
                                              ),
                                            );
                                            _loadNotes();
                                          },
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(topics: widget.topics),
            ),
          );
          _loadNotes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}