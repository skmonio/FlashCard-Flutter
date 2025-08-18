import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../providers/user_profile_provider.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  String _selectedAvatar = 'person';
  String? _profileImageData;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _avatarOptions = [
    {'name': 'person.crop.circle.fill', 'icon': Icons.person, 'label': 'Person'},
    {'name': 'person.crop.circle', 'icon': Icons.person_outline, 'label': 'Person Outline'},
    {'name': 'person.fill', 'icon': Icons.person, 'label': 'Person Fill'},
    {'name': 'person', 'icon': Icons.person_outline, 'label': 'Person'},
    {'name': 'person.2.fill', 'icon': Icons.group, 'label': 'Group'},
    {'name': 'person.2', 'icon': Icons.group_outlined, 'label': 'Group Outline'},
    {'name': 'graduationcap.fill', 'icon': Icons.school, 'label': 'Graduation Cap'},
    {'name': 'graduationcap', 'icon': Icons.school_outlined, 'label': 'Graduation Cap Outline'},
    {'name': 'book.fill', 'icon': Icons.book, 'label': 'Book'},
    {'name': 'book', 'icon': Icons.book_outlined, 'label': 'Book Outline'},
    {'name': 'brain.head.profile', 'icon': Icons.psychology, 'label': 'Brain'},
    {'name': 'brain', 'icon': Icons.psychology_outlined, 'label': 'Brain Outline'},
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<UserProfileProvider>();
    _usernameController = TextEditingController(text: provider.username);
    _selectedAvatar = provider.selectedAvatar;
    _profileImageData = provider.profileImageData;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image Section
              _buildProfileImageSection(),
              
              const SizedBox(height: 30),
              
              // Username Section
              _buildUsernameSection(),
              
              const SizedBox(height: 30),
              
              // Avatar Selection Section
              _buildAvatarSelectionSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile Photo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Center(
          child: Stack(
            children: [
              // Profile Image
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(0.1),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: _profileImageData != null
                    ? ClipOval(
                        child: Image.memory(
                          base64Decode(_profileImageData!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        _getAvatarIcon(_selectedAvatar),
                        size: 60,
                        color: Colors.grey,
                      ),
              ),
              
              // Camera Button
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 20),
                    color: Colors.white,
                    onPressed: _showImagePickerOptions,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Image Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _showImagePickerOptions,
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            if (_profileImageData != null)
              ElevatedButton.icon(
                onPressed: _removeProfileImage,
                icon: const Icon(Icons.delete),
                label: const Text('Remove'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsernameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Username',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Enter your username',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a username';
            }
            if (value.trim().length < 2) {
              return 'Username must be at least 2 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAvatarSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Avatar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _avatarOptions.length,
          itemBuilder: (context, index) {
            final avatar = _avatarOptions[index];
            final isSelected = _selectedAvatar == avatar['name'];
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAvatar = avatar['name'];
                  _profileImageData = null; // Clear profile image when avatar is selected
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      avatar['icon'],
                      size: 32,
                      color: isSelected ? Colors.blue : Colors.grey[600],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      avatar['label'],
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.blue : Colors.grey[600],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageData = base64Encode(bytes);
          _selectedAvatar = ''; // Clear avatar when image is selected
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeProfileImage() {
    setState(() {
      _profileImageData = null;
    });
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<UserProfileProvider>();
      
      try {
        await provider.updateUsername(_usernameController.text.trim());
        await provider.updateAvatar(_selectedAvatar);
        if (_profileImageData != null) {
          await provider.updateProfileImage(_profileImageData);
        } else {
          await provider.updateProfileImage(null);
        }
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getAvatarIcon(String avatar) {
    switch (avatar) {
      case 'person.crop.circle.fill':
        return Icons.person;
      case 'person.crop.circle':
        return Icons.person_outline;
      case 'person.fill':
        return Icons.person;
      case 'person':
        return Icons.person_outline;
      case 'person.2.fill':
        return Icons.group;
      case 'person.2':
        return Icons.group_outlined;
      case 'graduationcap.fill':
        return Icons.school;
      case 'graduationcap':
        return Icons.school_outlined;
      case 'book.fill':
        return Icons.book;
      case 'book':
        return Icons.book_outlined;
      case 'brain.head.profile':
        return Icons.psychology;
      case 'brain':
        return Icons.psychology_outlined;
      default:
        return Icons.person;
    }
  }
} 