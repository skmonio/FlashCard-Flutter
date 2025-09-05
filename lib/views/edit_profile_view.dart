import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../providers/user_profile_provider.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _picker = ImagePicker();
  
  String _selectedAvatar = '';
  String? _profileImageData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    final provider = context.read<UserProfileProvider>();
    final profile = provider.profile;
    
    if (profile != null) {
      setState(() {
        _usernameController.text = profile.username;
        _selectedAvatar = profile.selectedAvatar;
        _profileImageData = profile.profileImageData;
      });
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          // Fixed Header - matching Taal Trek header height
          SafeArea(
            child: Container(
              height: kToolbarHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: _buildCustomHeader(context),
            ),
          ),
          
          // Form content
          Expanded(
            child: SingleChildScrollView(
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
          ),
        ],
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
            labelText: 'Username',
            hintText: 'Enter your username',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a username';
            }
            if (value.trim().length < 3) {
              return 'Username must be at least 3 characters long';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAvatarSelectionSection() {
    final avatars = [
      'person.crop.circle.fill',
      'person.crop.circle',
      'person.fill',
      'person',
      'person.2.fill',
      'person.2',
      'graduationcap.fill',
      'graduationcap',
      'book.fill',
      'book',
      'brain.head.profile',
      'brain',
    ];

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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: avatars.map((avatar) {
            final isSelected = _selectedAvatar == avatar;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAvatar = avatar;
                  _profileImageData = null; // Clear profile image when avatar is selected
                });
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.1),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: Icon(
                  _getAvatarIcon(avatar),
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 30,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            'Edit Profile',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        
        // Left side - Back button with proper padding
        Positioned(
          left: 16, // Add proper padding from left edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
        ),
        
        // Right side - Save button
        Positioned(
          right: 16, // Add proper padding from right edge
          top: 0,
          bottom: 0,
          child: TextButton(
            onPressed: _saveProfile,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
