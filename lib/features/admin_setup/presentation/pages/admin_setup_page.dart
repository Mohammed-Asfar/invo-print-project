import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/repositories/admin_setup_repository.dart';
import '../cubit/admin_setup_cubit.dart';

class AdminSetupPage extends StatelessWidget {
  const AdminSetupPage({super.key});

  static const routePath = '/admin/setup';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminSetupCubit>(),
      child: const _AdminSetupView(),
    );
  }
}

class _AdminSetupView extends StatefulWidget {
  const _AdminSetupView();

  @override
  State<_AdminSetupView> createState() => _AdminSetupViewState();
}

class _AdminSetupViewState extends State<_AdminSetupView> {
  final _formKey = GlobalKey<FormState>();
  final _userUid = TextEditingController();
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _customerId = TextEditingController();
  final _licenseId = TextEditingController();
  final _allowedDevices = TextEditingController(text: '2');
  final _projectId = TextEditingController();
  final _apiKey = TextEditingController();
  final _authDomain = TextEditingController();
  final _storageBucket = TextEditingController();
  final _messagingSenderId = TextEditingController();
  final _appId = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _userUid,
      _email,
      _displayName,
      _customerId,
      _licenseId,
      _allowedDevices,
      _projectId,
      _apiKey,
      _authDomain,
      _storageBucket,
      _messagingSenderId,
      _appId,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final adminName = authState is AuthAdminAuthenticated
        ? authState.session.displayName
        : 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Setup - $adminName'),
        actions: [
          TextButton.icon(
            onPressed: () {
              context.read<AuthBloc>().add(const AuthSignOutRequested());
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: BlocListener<AdminSetupCubit, AdminSetupState>(
        listener: (context, state) {
          if (state is AdminSetupSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Customer setup saved.')),
            );
          }
          if (state is AdminSetupFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Customer Control Setup',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Use this after the customer Auth user exists in both Firebase projects. Customer ID is your internal business ID, for example cust_abc_traders.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pasteFirebaseJson,
                            icon: const Icon(Icons.content_paste),
                            label: const Text('Paste Firebase JSON'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _importFirebaseJson,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Import Firebase JSON'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _Section(
                      title: 'Customer Account',
                      children: [
                        _Field(controller: _userUid, label: 'Auth User UID'),
                        _Field(controller: _email, label: 'Email'),
                        _Field(
                          controller: _displayName,
                          label: 'Business Name',
                        ),
                        _Field(controller: _customerId, label: 'Customer ID'),
                        _Field(controller: _licenseId, label: 'License ID'),
                        _Field(
                          controller: _allowedDevices,
                          label: 'Allowed Devices',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _Section(
                      title: 'Customer Firebase Config',
                      children: [
                        _Field(controller: _projectId, label: 'Project ID'),
                        _Field(controller: _apiKey, label: 'API Key'),
                        _Field(controller: _authDomain, label: 'Auth Domain'),
                        _Field(
                          controller: _storageBucket,
                          label: 'Storage Bucket (optional for v1)',
                          required: false,
                        ),
                        _Field(
                          controller: _messagingSenderId,
                          label: 'Messaging Sender ID',
                        ),
                        _Field(controller: _appId, label: 'App ID'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    BlocBuilder<AdminSetupCubit, AdminSetupState>(
                      builder: (context, state) {
                        final isSaving = state is AdminSetupSaving;
                        return Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : _save,
                            icon: isSaving
                                ? SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onAccent,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(isSaving ? 'Saving...' : 'Save Setup'),
                          ),
                        );
                      },
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AdminSetupCubit>().save(
      CustomerSetupInput(
        userUid: _userUid.text.trim(),
        email: _email.text.trim(),
        displayName: _displayName.text.trim(),
        customerId: _customerId.text.trim(),
        licenseId: _licenseId.text.trim(),
        allowedDevices: int.tryParse(_allowedDevices.text.trim()) ?? 1,
        projectId: _projectId.text.trim(),
        apiKey: _apiKey.text.trim(),
        authDomain: _authDomain.text.trim(),
        storageBucket: _storageBucket.text.trim(),
        messagingSenderId: _messagingSenderId.text.trim(),
        appId: _appId.text.trim(),
      ),
    );
  }

  Future<void> _importFirebaseJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;

    try {
      _applyFirebaseJson(utf8.decode(bytes));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firebase config imported.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not import JSON: $error')),
        );
      }
    }
  }

  Future<void> _pasteFirebaseJson() async {
    final controller = TextEditingController();
    final jsonText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Paste Firebase JSON'),
          content: SizedBox(
            width: 640,
            child: TextField(
              controller: controller,
              minLines: 12,
              maxLines: 16,
              decoration: const InputDecoration(
                hintText:
                    '{"projectId":"...","apiKey":"...","authDomain":"..."}',
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(controller.text),
              icon: const Icon(Icons.check),
              label: const Text('Use JSON'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (jsonText == null || jsonText.trim().isEmpty) return;

    try {
      _applyFirebaseJson(jsonText);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firebase config pasted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not read JSON: $error')));
      }
    }
  }

  void _applyFirebaseJson(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON root must be an object.');
    }

    final config = _extractFirebaseConfig(decoded);
    _applyFirebaseConfig(config);
  }

  Map<String, String> _extractFirebaseConfig(Map<String, dynamic> json) {
    final source = json['firebaseConfig'] is Map<String, dynamic>
        ? json['firebaseConfig'] as Map<String, dynamic>
        : json;

    String? read(String key) => source[key]?.toString().trim();

    final config = <String, String>{};
    for (final key in [
      'projectId',
      'apiKey',
      'authDomain',
      'storageBucket',
      'messagingSenderId',
      'appId',
    ]) {
      final value = read(key);
      if (value != null && value.isNotEmpty) {
        config[key] = value;
      }
    }

    final missing = [
      'projectId',
      'apiKey',
      'authDomain',
      'messagingSenderId',
      'appId',
    ].where((key) => !config.containsKey(key)).toList();
    if (missing.isNotEmpty) {
      throw FormatException('Missing required keys: ${missing.join(', ')}');
    }

    return config;
  }

  void _applyFirebaseConfig(Map<String, String> config) {
    setState(() {
      _projectId.text = config['projectId'] ?? _projectId.text;
      _apiKey.text = config['apiKey'] ?? _apiKey.text;
      _authDomain.text = config['authDomain'] ?? _authDomain.text;
      _storageBucket.text = config['storageBucket'] ?? _storageBucket.text;
      _messagingSenderId.text =
          config['messagingSenderId'] ?? _messagingSenderId.text;
      _appId.text = config['appId'] ?? _appId.text;
    });
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.required = true,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Required';
          }
          return null;
        },
      ),
    );
  }
}
