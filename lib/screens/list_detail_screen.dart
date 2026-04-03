import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sharecart/utils/list_icon_helper.dart';
import 'package:flutter/services.dart';
import 'package:sharecart/components/app_bottom_nav.dart';
import 'package:sharecart/components/language_switcher.dart';
import 'package:get/get.dart';
import 'package:sharecart/screens/lists_screen.dart';
import 'package:sharecart/screens/login_screen.dart';
import 'package:sharecart/screens/register_screen.dart';
import 'package:sharecart/screens/welcome_screen.dart';
import 'package:sharecart/services/auth_service.dart';
import 'package:sharecart/services/recent_items_storage.dart';
import 'package:sharecart/theme/app_decorations.dart';
import 'package:sharecart/theme/app_palette.dart';
import 'package:sharecart/theme/app_theme.dart';
import 'package:sharecart/widgets/item_chat_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({
    super.key,
    required this.listId,
    this.summary,
    this.onGuestBack,
  });

  final int listId;
  final ListSummary? summary;
  /// When in guest mode and user goes back, this is called with context (e.g. clear guest + navigate to Welcome).
  final Future<void> Function(BuildContext context)? onGuestBack;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

const _guestPromptShownKey = 'guest_login_prompt_shown';

class _ListDetailScreenState extends State<ListDetailScreen> {
  ListDetail? _detail;
  bool _loading = true;
  Object? _error;
  bool _guestPromptShown = false;
  int? _currentUserId;
  Timer? _pollTimer;
  final TextEditingController _itemSearchController = TextEditingController();
  String _itemSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadDetail();
    _scheduleGuestPromptIfNeeded();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _itemSearchController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollRefresh());
  }

  Future<void> _pollRefresh() async {
    if (!mounted) return;
    try {
      final detail = await AuthService.instance.fetchListDetail(widget.listId);
      if (!mounted) return;
      final wasArchived = _detail?.archivedAt != null && _detail!.archivedAt!.isNotEmpty;
      final nowArchived = detail.archivedAt != null && detail.archivedAt!.isNotEmpty;
      if (_detail != null && !wasArchived && nowArchived) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('listCompletedMovedToArchived'.tr),
            backgroundColor: AppColors.success,
          ),
        );
      }
      if (mounted) setState(() => _detail = detail);
    } catch (_) {}
  }

  Future<void> _scheduleGuestPromptIfNeeded() async {
    if (!AuthService.instance.isGuestMode || AuthService.instance.guestListId != widget.listId) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_guestPromptShownKey) == true) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (AuthService.instance.isGuestMode && AuthService.instance.guestListId == widget.listId) {
        _showGuestLoginPromptOnce();
      }
    });
  }

  Future<void> _showGuestLoginPromptOnce() async {
    if (_guestPromptShown) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_guestPromptShownKey) == true) return;
    if (!mounted) return;
    _guestPromptShown = true;
    await prefs.setBool(_guestPromptShownKey, true);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text('guestLoginPromptTitle'.tr),
        content: Text('guestLoginPromptMessage'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await AuthService.instance.fetchListDetail(widget.listId);
      if (mounted) {
        final hadPrevious = _detail != null;
        final wasArchived = _detail?.archivedAt != null && _detail!.archivedAt!.isNotEmpty;
        final nowArchived = detail.archivedAt != null && detail.archivedAt!.isNotEmpty;
        setState(() {
          _detail = detail;
          _loading = false;
        });
        if (hadPrevious && !wasArchived && nowArchived) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('listCompletedMovedToArchived'.tr),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _startPolling();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  /// Refresh list detail without showing loading (stops blink on item toggle/add/delete).
  Future<void> _handleReorderOptimistic(ListDetail newDetail) async {
    final previous = _detail!;
    setState(() => _detail = newDetail);
    try {
      final ids = newDetail.items.map((i) => i.id).toList();
      await AuthService.instance.reorderListItems(widget.listId, ids);
      await _refreshSilent();
    } catch (e) {
      if (!mounted) return;
      setState(() => _detail = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _refreshSilent() async {
    try {
      final detail = await AuthService.instance.fetchListDetail(widget.listId);
      if (mounted) {
        final hadPrevious = _detail != null;
        final wasArchived = _detail?.archivedAt != null && _detail!.archivedAt!.isNotEmpty;
        final nowArchived = detail.archivedAt != null && detail.archivedAt!.isNotEmpty;
        setState(() => _detail = detail);
        if (hadPrevious && !wasArchived && nowArchived) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('listCompletedMovedToArchived'.tr),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _showEditDialog() async {
    if (_detail == null) return;
    List<String> editIcons = ['🛒', '🏠', '🎉', '🛍️', '📋', '🥗', '🍎', '🧾'];
    try {
      editIcons = await AuthService.instance.fetchListIcons();
      if (editIcons.isEmpty) editIcons = ['🛒', '🏠', '🎉', '🛍️', '📋', '🥗', '🍎', '🧾'];
    } catch (_) {}

    final nameController = TextEditingController(text: _detail!.name);
    DateTime? pickedDate;
    String? selectedIcon = _detail!.icon;
    if (_detail!.dueDate != null) {
      try {
        final parts = _detail!.dueDate!.split('-');
        if (parts.length == 3) {
          pickedDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (_) {}
    }

    final updated = await showDialog<ListDetail?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('edit'.tr),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'listName'.tr,
                        hintText: 'listNameHint'.tr,
                        border: const OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      autofocus: true,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'List icon',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = null),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selectedIcon == null ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedIcon == null ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                                width: selectedIcon == null ? 2 : 1,
                              ),
                            ),
                            child: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
                          ),
                        ),
                        ...editIcons.map((iconCode) {
                          final isSelected = selectedIcon == iconCode;
                          final display = ListIconHelper.toEmoji(iconCode) ?? iconCode;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedIcon = iconCode),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(display, style: const TextStyle(fontSize: 22)),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: pickedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (date != null) setDialogState(() => pickedDate = date);
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        pickedDate == null
                            ? 'dueDateOptional'.tr
                            : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('nameRequired'.tr)),
                      );
                      return;
                    }
                    final dueDate = pickedDate == null
                        ? null
                        : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}';
                    try {
                      final iconToSend = selectedIcon != null ? (ListIconHelper.toEmoji(selectedIcon) ?? selectedIcon) : null;
                      final detail = await AuthService.instance.updateList(
                        widget.listId,
                        name: name,
                        dueDate: dueDate,
                        icon: iconToSend,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop(detail);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString().replaceFirst('Exception: ', '')),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.cta,
                    foregroundColor: AppColors.onCta,
                  ),
                  child: Text('edit'.tr),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated != null && mounted) {
      setState(() => _detail = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('listUpdated'.tr), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _archiveOrRestore() async {
    final isArchived = _detail?.archivedAt != null && _detail!.archivedAt!.isNotEmpty;
    try {
      if (isArchived) {
        await AuthService.instance.restoreList(widget.listId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('listRestored'.tr), backgroundColor: AppColors.success),
        );
      } else {
        await AuthService.instance.archiveList(widget.listId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('listArchived'.tr), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pop();
        return;
      }
      await _loadDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteList() async {
    if (!_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only list owner can delete this list.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
title: Text('delete'.tr),
            content: Text('confirmDeleteList'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AuthService.instance.deleteList(widget.listId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('listDeleted'.tr), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _leaveList() async {
    if (_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Owner cannot leave the list.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave list'),
        content: const Text('Are you sure you want to leave this list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await AuthService.instance.leaveList(widget.listId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You left the list.'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pingList() async {
    try {
      await AuthService.instance.pingList(widget.listId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Nudge sent!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showShareDialog() async {
    if (_detail == null) return;
    final sharedWith = List<Map<String, dynamic>>.from(_detail!.sharedWith);
    final emailController = TextEditingController();
    var loading = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('shareList'.tr),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('shareWithEmail'.tr),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'email'.tr,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    enabled: !loading,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: loading
                        ? null
                        : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty) return;
                            setDialogState(() => loading = true);
                            try {
                              await AuthService.instance.shareList(widget.listId, email);
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              await _loadDetail();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('listShared'.tr), backgroundColor: AppColors.success),
                              );
                            } catch (e) {
                              setDialogState(() => loading = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
                                );
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.cta,
                      foregroundColor: AppColors.onCta,
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onCta,
                            ),
                          )
                        : Text('shareList'.tr),
                  ),
                  if (sharedWith.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('collaboratorsCount'.trParams({'count': sharedWith.length.toString()})),
                    const SizedBox(height: 8),
                    ...sharedWith.map((u) {
                      final id = u['id'] as int?;
                      final name = u['name'] as String? ?? '';
                      final email = u['email'] as String? ?? '';
                      return ListTile(
                        dense: true,
                        title: Text(name),
                        subtitle: email.isNotEmpty ? Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)) : null,
                        trailing: id != null
                            ? TextButton(
                                onPressed: loading
                                    ? null
                                    : () async {
                                        setDialogState(() => loading = true);
                                        try {
                                          await AuthService.instance.unshareList(widget.listId, id);
                                          if (!ctx.mounted) return;
                                          Navigator.of(ctx).pop();
                                          await _loadDetail();
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('accessRemoved'.tr), backgroundColor: AppColors.success),
                                          );
                                        } catch (e) {
                                          setDialogState(() => loading = false);
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
                                            );
                                          }
                                        }
                                      },
                                child: Text('removeAccess'.tr, style: const TextStyle(color: AppColors.error)),
                              )
                            : null,
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
            ],
          );
        },
      ),
    );
    emailController.dispose();
  }

  bool get _isGuest => AuthService.instance.isGuestMode && AuthService.instance.guestListId == widget.listId;

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<void> _loadCurrentUserId() async {
    if (_isGuest) return;
    try {
      final me = await AuthService.instance.me();
      if (!mounted) return;
      setState(() => _currentUserId = _asInt(me['id']));
    } catch (_) {}
  }

  bool get _isOwner {
    final ownerId = _asInt(_detail?.owner['id']);
    final currentId = _currentUserId;
    if (ownerId == null || currentId == null) return false;
    return ownerId == currentId;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isGuest = _isGuest;

    return PopScope(
      canPop: !isGuest,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isGuest && context.mounted) widget.onGuestBack?.call(context);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: isGuest
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    if (context.mounted) widget.onGuestBack?.call(context);
                  },
                )
              : null,
          title: Text(
          _detail?.name ?? widget.summary?.name ?? 'lists'.tr,
        ),
        centerTitle: true,
        actions: [
          if (isGuest) ...[
            if (_detail != null)
              PopupMenuButton<String>(
                tooltip: 'listMenuTitle'.tr,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'nudge':
                      await _pingList();
                      break;
                    case 'login':
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                      break;
                    case 'register':
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'nudge',
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active_outlined, size: 20, color: accent),
                        const SizedBox(width: 10),
                        Expanded(child: Text('listMenuNudge'.tr)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'login',
                    child: Row(
                      children: [
                        Icon(Icons.login_rounded, size: 20, color: accent),
                        const SizedBox(width: 10),
                        Text('login'.tr),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'register',
                    child: Row(
                      children: [
                        Icon(Icons.person_add_outlined, size: 20, color: accent),
                        const SizedBox(width: 10),
                        Text('register'.tr),
                      ],
                    ),
                  ),
                ],
              ),
          ] else ...[
            const LanguageSwitcher(),
            if (_detail != null)
              PopupMenuButton<String>(
                tooltip: 'listMenuTitle'.tr,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  switch (value) {
                    case 'nudge':
                      await _pingList();
                      break;
                    case 'share':
                      await _showShareDialog();
                      break;
                    case 'edit':
                      await _showEditDialog();
                      break;
                    case 'archive':
                    case 'restore':
                      await _archiveOrRestore();
                      break;
                    case 'leave':
                      await _leaveList();
                      break;
                    case 'delete':
                      await _deleteList();
                      break;
                  }
                },
                itemBuilder: (context) {
                  final isArchived = _detail!.archivedAt != null && _detail!.archivedAt!.isNotEmpty;
                  final canDelete = _isOwner;
                  final canLeave = !canDelete;
                  return [
                    PopupMenuItem(
                      value: 'nudge',
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, size: 20, color: accent),
                          const SizedBox(width: 10),
                          Expanded(child: Text('listMenuNudge'.tr)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, size: 20, color: accent),
                          const SizedBox(width: 10),
                          Expanded(child: Text('listMenuShare'.tr)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 20),
                          const SizedBox(width: 12),
                          Text('edit'.tr),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: isArchived ? 'restore' : 'archive',
                      child: Row(
                        children: [
                          Icon(isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 20),
                          const SizedBox(width: 12),
                          Text(isArchived ? 'restore'.tr : 'archive'.tr),
                        ],
                      ),
                    ),
                    if (canLeave)
                      const PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 20),
                            SizedBox(width: 12),
                            Text('Leave list'),
                          ],
                        ),
                      ),
                    if (canDelete)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                            const SizedBox(width: 12),
                            Text('delete'.tr, style: const TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                  ];
                },
              ),
          ],
        ],
      ),
      bottomNavigationBar: isGuest
          ? null
          : AppBottomNavBar(
              currentIndex: 0,
              onTap: (index) {
                if (index == 0) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => ListsScreen(initialTabIndex: index),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.pageBackground(),
        child: SafeArea(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AuthService.isUnauthorizedError(_error)
                                ? 'sessionExpiredMessage'.tr
                                : _error.toString(),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          if (AuthService.isUnauthorizedError(_error)) ...[
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                                  (route) => false,
                                );
                              },
                              child: Text('logInAgain'.tr),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : _detail == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (AuthService.instance.listDetailFromCache)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_off_outlined, size: 20, color: Colors.amber.shade800),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
'offlineShowingCached'.tr,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
                            child: TextField(
                              controller: _itemSearchController,
                              onChanged: (v) => setState(() => _itemSearchQuery = v.trim()),
                              decoration: InputDecoration(
                                hintText: 'searchItems'.tr,
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _itemSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _itemSearchController.clear();
                                          setState(() => _itemSearchQuery = '');
                                        },
                                      )
                                    : null,
                                isDense: true,
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _ListDetailBody(
                              listId: widget.listId,
                              detail: _detail!,
                              itemSearchQuery: _itemSearchQuery,
                              accent: accent,
                              onRefresh: _refreshSilent,
                              onReorderOptimistic: _handleReorderOptimistic,
                            ),
                          ),
                        ],
                      ),
        ),
      ),
    ),
    );
  }
}

class _ListDetailBody extends StatelessWidget {
  const _ListDetailBody({
    required this.listId,
    required this.detail,
    this.itemSearchQuery = '',
    required this.accent,
    required this.onRefresh,
    required this.onReorderOptimistic,
  });

  final int listId;
  final ListDetail detail;
  final String itemSearchQuery;
  final Color accent;
  final Future<void> Function() onRefresh;
  final Future<void> Function(ListDetail newDetail) onReorderOptimistic;

  Map<String, List<ListItem>> _groupBySection(List<ListItem> items) {
    final Map<String, List<ListItem>> grouped = {};
    for (final item in items) {
      final key = (item.section ?? 'other').toLowerCase();
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  String _sectionLabel(String key) {
    switch (key) {
      case 'fruits':
        return 'sectionFruits'.tr;
      case 'vegetables':
        return 'sectionVegetables'.tr;
      case 'cooking':
        return 'sectionCooking'.tr;
      case 'beauty':
        return 'sectionBeauty'.tr;
      case 'dairy_bakery':
        return 'sectionDairyBakery'.tr;
      case 'beverages':
        return 'sectionBeverages'.tr;
      case 'snacks':
        return 'sectionSnacks'.tr;
      case 'electronics':
        return 'sectionElectronics'.tr;
      default:
        return 'sectionOther'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = itemSearchQuery.isEmpty
        ? detail.items
        : detail.items.where((i) => i.name.toLowerCase().contains(itemSearchQuery.toLowerCase())).toList();
    final grouped = _groupBySection(items);

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
      children: [
        _HeaderCard(detail: detail, accent: accent),
        const SizedBox(height: 10),
        _AddBlock(
          listId: listId,
          detail: detail,
          accent: accent,
          onAdded: onRefresh,
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'swipeForShortcuts'.tr,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_basket_outlined,
                    color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    itemSearchQuery.isEmpty ? 'noItemsYetAdd'.tr : 'noItemsMatchSearch'.tr,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ),
              ],
            ),
          )
        else
          ...grouped.entries.map(
            (entry) {
              final sectionKey = entry.key;
              final sectionItems = entry.value;
              return _SectionCard(
                listId: listId,
                sectionKey: sectionKey,
                label: _sectionLabel(sectionKey),
                items: sectionItems,
                canReorder: itemSearchQuery.isEmpty,
                accent: accent,
                onRefresh: onRefresh,
                onSectionReorder: (newOrder) async {
                  final fullOrdered = <ListItem>[];
                  for (final k in grouped.keys) {
                    final list = (k == sectionKey) ? newOrder : grouped[k]!;
                    fullOrdered.addAll(list);
                  }
                  final newDetail = detail.copyWith(items: fullOrdered);
                  await onReorderOptimistic(newDetail);
                },
              );
            },
          ),
        const SizedBox(height: 12),
        _PaymentsCard(
          listId: listId,
          accent: accent,
        ),
      ],
    );
  }
}

/// Single "Add to list" block: add item row + quick chips + apply template.
class _AddBlock extends StatelessWidget {
  const _AddBlock({
    required this.listId,
    required this.detail,
    required this.accent,
    required this.onAdded,
  });

  final int listId;
  final ListDetail detail;
  final Color accent;
  final Future<void> Function() onAdded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'addItemsSection'.tr,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.3,
                  color: AppColors.onSurface.withValues(alpha: 0.75),
                ),
          ),
          const SizedBox(height: 10),
          _AddItemCard(
            listId: listId,
            accent: accent,
            onAdded: onAdded,
            contextItemNames: detail.items.map((i) => i.name).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'quickAddSection'.tr,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: AppColors.onSurface.withValues(alpha: 0.55),
                          ),
                    ),
                    const SizedBox(height: 6),
                    _QuickAddChips(
                      listId: listId,
                      accent: accent,
                      onAdded: onAdded,
                    ),
                  ],
                ),
              ),
              if (!AuthService.instance.isGuestMode) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _ApplyTemplateButton(
                    listId: listId,
                    accent: accent,
                    onApplied: onAdded,
                    compact: true,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplyTemplateButton extends StatelessWidget {
  const _ApplyTemplateButton({
    required this.listId,
    required this.accent,
    required this.onApplied,
    this.compact = false,
  });

  final int listId;
  final Color accent;
  final Future<void> Function() onApplied;
  /// Icon-only (for tight toolbar next to quick-add chips).
  final bool compact;

  void _openDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('selectTemplate'.tr),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<TemplateSummary>>(
            future: AuthService.instance.fetchTemplates(),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  style: TextStyle(color: Colors.red.shade700),
                );
              }
              final templates = snapshot.data ?? [];
              if (templates.isEmpty) {
                return Text(
'noTemplates'.tr,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: templates.length,
                itemBuilder: (_, i) {
                  final t = templates[i];
                  return ListTile(
                    leading: Icon(Icons.list_alt_rounded, color: accent),
                    title: Text(t.name),
                    subtitle: Text('itemsCount'.trParams({'count': t.itemsCount.toString()})),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await AuthService.instance.applyTemplate(t.id, listId);
                        await onApplied();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('templateApplied'.tr),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: 'applyTemplate'.tr,
        child: IconButton(
          onPressed: () => _openDialog(context),
          icon: Icon(Icons.dashboard_customize_outlined, color: accent),
          style: IconButton.styleFrom(
            backgroundColor: accent.withValues(alpha: 0.12),
            padding: const EdgeInsets.all(10),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _openDialog(context),
      icon: Icon(Icons.dashboard_customize_outlined, size: 18, color: accent),
      label: Text('applyTemplate'.tr, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.7)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
    );
  }
}

/// Bottom sheet content for add/edit payment. Owns controllers and disposes them in [State.dispose].
class _PaymentSheetContent extends StatefulWidget {
  const _PaymentSheetContent({
    required this.listId,
    required this.accent,
    this.payment,
    required this.onSuccess,
  });

  final int listId;
  final Color accent;
  final ListPayment? payment;
  final VoidCallback onSuccess;

  @override
  State<_PaymentSheetContent> createState() => _PaymentSheetContentState();
}

class _PaymentSheetContentState extends State<_PaymentSheetContent> {
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    _amountController = TextEditingController(
      text: p != null ? p.amount.toStringAsFixed(2) : '',
    );
    _currencyController = TextEditingController(
      text: p?.currency ?? 'EUR',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('amount'.tr)),
      );
      return;
    }
    final amount = double.tryParse(amountStr.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    final currency = _currencyController.text.trim();
    try {
      if (widget.payment != null) {
        await AuthService.instance.updateListPayment(
          widget.listId,
          widget.payment!.id,
          amount,
          currency: currency.isEmpty ? null : currency,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment updated.'), backgroundColor: AppColors.success),
        );
      } else {
        await AuthService.instance.addListPayment(
          widget.listId,
          amount,
          currency: currency.isEmpty ? null : currency,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('paymentAdded'.tr),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.payment != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit ? 'edit'.tr : 'addWhatIPaid'.tr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'amount'.tr,
                    hintText: '0.00',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currencyController,
                  decoration: InputDecoration(
                    labelText: 'currencyOptional'.tr,
                    hintText: 'EUR',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.cta,
                    foregroundColor: AppColors.onCta,
                  ),
                  child: Text(isEdit ? 'edit'.tr : 'addWhatIPaid'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentsCard extends StatefulWidget {
  const _PaymentsCard({
    required this.listId,
    required this.accent,
  });

  final int listId;
  final Color accent;

  @override
  State<_PaymentsCard> createState() => _PaymentsCardState();
}

class _PaymentsCardState extends State<_PaymentsCard> {
  late Future<List<ListPayment>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _paymentsFuture = AuthService.instance.fetchListPayments(widget.listId);
  }

  void _refresh() {
    setState(() {
      _paymentsFuture = AuthService.instance.fetchListPayments(widget.listId);
    });
  }

  Future<void> _showSettlementSheet(BuildContext context) async {
    try {
      final result = await AuthService.instance.fetchSettlement(widget.listId);
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Settle up',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total spent', style: Theme.of(ctx).textTheme.titleSmall),
                        Text(
                          result.totalSpent.toStringAsFixed(2),
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: widget.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fair share each', style: Theme.of(ctx).textTheme.titleSmall),
                        Text(
                          result.fairShare.toStringAsFixed(2),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Who pays / gets back',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: result.participants.isEmpty
                        ? Center(
                            child: Text(
                              'No participants',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: result.participants.length,
                            itemBuilder: (ctx, i) {
                              final p = result.participants[i];
                              final isZero = p.balance.abs() < 0.01;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ),
                                    if (isZero)
                                      Text('Settled', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
                                    else if (p.balance > 0)
                                      Text(
                                        'Gets back ${p.balance.toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
                                      )
                                    else
                                      Text(
                                        'Owes ${(-p.balance).toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showAddPaymentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PaymentSheetContent(
        listId: widget.listId,
        accent: widget.accent,
        payment: null,
        onSuccess: () {
          _refresh();
        },
      ),
    ).then((_) => _refresh());
  }

  void _showEditPaymentSheet(BuildContext context, ListPayment p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PaymentSheetContent(
        listId: widget.listId,
        accent: widget.accent,
        payment: p,
        onSuccess: () {
          _refresh();
        },
      ),
    ).then((_) => _refresh());
  }

  Future<void> _confirmDeletePayment(BuildContext context, ListPayment p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete'.tr),
        content: const Text('Delete this payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AuthService.instance.deleteListPayment(widget.listId, p.id);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment deleted.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
'payments'.tr,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _showSettlementSheet(context),
                icon: Icon(Icons.account_balance_wallet_outlined, size: 18, color: accent),
                tooltip: 'Settle up',
                style: IconButton.styleFrom(padding: const EdgeInsets.all(4), minimumSize: const Size(32, 32)),
              ),
              IconButton(
                onPressed: () => _showAddPaymentSheet(context),
                icon: Icon(Icons.add_circle_outline, size: 18, color: accent),
                tooltip: 'addWhatIPaid'.tr,
                style: IconButton.styleFrom(padding: const EdgeInsets.all(4), minimumSize: const Size(32, 32)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FutureBuilder<List<ListPayment>>(
            future: _paymentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }
              if (snapshot.hasError) {
                final isUnauthorized = AuthService.isUnauthorizedError(snapshot.error);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isUnauthorized ? 'sessionExpiredMessage'.tr : snapshot.error.toString().replaceFirst('Exception: ', ''),
                        style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                      ),
                      if (isUnauthorized) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                              (route) => false,
                            );
                          },
                          child: Text('logInAgain'.tr),
                        ),
                      ],
                    ],
                  ),
                );
              }
              final payments = snapshot.data ?? [];
              if (payments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
'noPaymentsYet'.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                  ),
                );
              }
              final total = payments.fold<double>(0, (sum, p) => sum + p.amount);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...payments.map((p) {
                    final name = p.userName?.isNotEmpty == true ? p.userName! : 'guest'.tr;
                    final cur = p.currency?.isNotEmpty == true ? p.currency! : '';
                    final value = cur.isEmpty ? '${p.amount.toStringAsFixed(2)}' : '${p.amount.toStringAsFixed(2)} $cur';
                    String? dateStr;
                    if (p.paidAt != null && p.paidAt!.isNotEmpty) {
                      try {
                        final dt = DateTime.tryParse(p.paidAt!);
                        if (dt != null) {
                          dateStr = DateFormat.yMMMd().add_Hm().format(dt);
                        }
                      } catch (_) {}
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                if (dateStr != null)
                                  Text(
                                    dateStr,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Text(
                              value,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
                            padding: EdgeInsets.zero,
                            onSelected: (v) {
                              if (v == 'edit') _showEditPaymentSheet(context, p);
                              if (v == 'delete') _confirmDeletePayment(context, p);
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, size: 20), const SizedBox(width: 8), Text('edit'.tr)])),
                              PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 20, color: AppColors.error), const SizedBox(width: 8), Text('delete'.tr)])),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text('totalPaid'.tr, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                        const Spacer(),
                        Text(
                          total.toStringAsFixed(2),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAddChips extends StatefulWidget {
  const _QuickAddChips({
    required this.listId,
    required this.accent,
    required this.onAdded,
  });

  final int listId;
  final Color accent;
  final Future<void> Function() onAdded;

  @override
  State<_QuickAddChips> createState() => _QuickAddChipsState();
}

class _QuickAddChipsState extends State<_QuickAddChips> {
  static const List<String> _fixed = ['Milk', 'Bread', 'Eggs', 'Butter', 'Water', 'Cheese', 'Yogurt', 'Rice'];
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await RecentItemsStorage.instance.getRecentNames();
    if (mounted) setState(() => _recent = list);
  }

  Future<void> _onChipTap(String name) async {
    try {
      await AuthService.instance.storeListItem(widget.listId, name, quantity: 1);
      await RecentItemsStorage.instance.addName(name);
      await widget.onAdded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('itemAddedSuccess'.tr), backgroundColor: AppColors.success),
      );
      _loadRecent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fixedLower = _fixed.map((s) => s.toLowerCase()).toSet();
    final recentOnly = _recent.where((s) => !fixedLower.contains(s.toLowerCase())).toList();
    final allChips = [..._fixed, ...recentOnly.take(10)];

    if (allChips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: allChips.map((name) {
        return ActionChip(
          label: Text(name, style: const TextStyle(fontSize: 12)),
          onPressed: () => _onChipTap(name),
          backgroundColor: widget.accent.withValues(alpha: 0.08),
          side: BorderSide(color: widget.accent.withValues(alpha: 0.25)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}

class _AddItemCard extends StatefulWidget {
  const _AddItemCard({
    required this.listId,
    required this.accent,
    required this.onAdded,
    this.contextItemNames = const [],
  });

  final int listId;
  final Color accent;
  final Future<void> Function() onAdded;
  final List<String> contextItemNames;

  @override
  State<_AddItemCard> createState() => _AddItemCardState();
}

class _AddItemCardState extends State<_AddItemCard> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  bool _loading = false;
  List<String> _suggestions = [];
  Timer? _debounce;
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechInitialized = false;
  bool _didAutoSubmitForSession = false;

  /// Parses speech text: strips "add " prefix and leading quantity (e.g. "5 apple" -> 5, "apple").
  ({String name, int quantity}) _parseSpeechResult(String text) {
    String t = text.trim();
    if (t.isEmpty) return (name: '', quantity: 1);
    t = t.replaceFirst(RegExp(r'^\s*add\s+', caseSensitive: false), '').trim();
    if (t.isEmpty) return (name: '', quantity: 1);
    final numMatch = RegExp(r'^(\d+)\s+(.+)$').firstMatch(t);
    if (numMatch != null) {
      final qty = int.tryParse(numMatch.group(1) ?? '1');
      final name = (numMatch.group(2) ?? '').trim();
      if (qty != null && qty >= 1 && qty <= 9999 && name.isNotEmpty) {
        return (name: name, quantity: qty);
      }
    }
    return (name: t, quantity: 1);
  }

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
    _nameController.addListener(_onNameChanged);
    _loadSuggestions('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _speech.stop();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_loading) return;
    if (!_speechInitialized) {
      _speechInitialized = true;
      final ok = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _isListening = _speech.isListening);
          if (status == SpeechToText.doneStatus && mounted && !_didAutoSubmitForSession) {
            final text = _nameController.text.trim();
            if (text.isNotEmpty) {
              _didAutoSubmitForSession = true;
              final parsed = _parseSpeechResult(text);
              if (parsed.name.isNotEmpty) {
                _nameController.text = parsed.name;
                _quantityController.text = parsed.quantity.toString();
                _submit();
              }
            }
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error.errorMsg),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('speechNotAvailable'.tr),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
        if (!_didAutoSubmitForSession) {
          final text = _nameController.text.trim();
          if (text.isNotEmpty) {
            _didAutoSubmitForSession = true;
            final parsed = _parseSpeechResult(text);
            if (parsed.name.isNotEmpty) {
              _nameController.text = parsed.name;
              _quantityController.text = parsed.quantity.toString();
              _submit();
            }
          }
        }
      }
      return;
    }
    _didAutoSubmitForSession = false;
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) setState(() => _nameController.text = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
    if (mounted) setState(() => _isListening = _speech.isListening);
  }

  void _onNameChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadSuggestions(_nameController.text.trim());
    });
  }

  Future<void> _loadSuggestions(String q) async {
    try {
      if (q.isEmpty) {
        final results = await Future.wait<List<String>>([
          AuthService.instance.fetchPredictiveSuggestions(widget.listId),
          AuthService.instance.fetchSuggestions(
            '',
            limit: 10,
            contextItems: widget.contextItemNames.isEmpty ? null : widget.contextItemNames,
          ),
        ]);
        final predictive = results[0];
        final generic = results[1];
        final seen = <String>{};
        final merged = <String>[];
        for (final s in [...predictive, ...generic]) {
          final k = s.toLowerCase().trim();
          if (k.isEmpty) continue;
          if (seen.add(k)) merged.add(s);
        }
        if (mounted) setState(() => _suggestions = merged.take(15).toList());
      } else {
        final list = await AuthService.instance.fetchSuggestions(
          q,
          limit: 10,
          contextItems: widget.contextItemNames.isEmpty ? null : widget.contextItemNames,
        );
        if (mounted) setState(() => _suggestions = list);
      }
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    }
  }

  int get _quantity {
    final q = int.tryParse(_quantityController.text);
    return (q != null && q >= 1 && q <= 9999) ? q : 1;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.storeListItem(
        widget.listId,
        name,
        quantity: _quantity,
      );
      _nameController.clear();
      _quantityController.text = '1';
      await RecentItemsStorage.instance.addName(name);
      await widget.onAdded();
      if (!mounted) return;
      await _loadSuggestions('');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('itemAddedSuccess'.tr),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queryEmpty = _nameController.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'addItemTitle'.tr,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'itemNamePlaceholder'.tr,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isListening ? AppColors.error : widget.accent,
                        size: 22,
                      ),
                      onPressed: _toggleListening,
                      tooltip: 'addItemByVoice'.tr,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !_loading,
                  onSubmitted: (_) => _submit(),
                ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'quantityLabel'.tr,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  isDense: true,
                ),
                enabled: !_loading,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cta,
                foregroundColor: AppColors.onCta,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onCta),
                    )
                  : Text('addItemButton'.tr),
            ),
          ],
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (queryEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'smartSuggestions'.tr,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
              ),
            ),
          if (queryEmpty) const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _suggestions.map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  _nameController.text = s;
                  setState(() => _suggestions = []);
                },
                backgroundColor: widget.accent.withValues(alpha: 0.1),
                side: BorderSide(color: widget.accent.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail, required this.accent});

  final ListDetail detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ownerName = detail.owner['name'] as String? ?? '';
    final ownerEmail = detail.owner['email'] as String? ?? '';
    final collaborators =
        detail.sharedWith.length + detail.joinedByCode.length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.08),
            accent.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: detail.icon != null && detail.icon!.isNotEmpty && ListIconHelper.toEmoji(detail.icon) != null
                    ? Center(child: Text(ListIconHelper.toEmoji(detail.icon)!, style: const TextStyle(fontSize: 20)))
                    : Icon(Icons.list_alt_outlined, size: 20, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: detail.dueDate != null
                    ? Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              detail.dueDate!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'listMetaShared'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(
                    '${'code'.tr}: ${detail.joinCode}',
                    style: const TextStyle(letterSpacing: 0.8, fontSize: 11),
                  ),
                  backgroundColor: AppColors.cardBg,
                  side: BorderSide(color: accent.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: Icon(Icons.copy_outlined, size: 18, color: accent),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: detail.joinCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('codeCopied'.tr)),
                    );
                  },
                  tooltip: 'codeCopied'.tr,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                ),
                if (collaborators > 0) ...[
                  const SizedBox(width: 4),
                  Chip(
                    label: Text('collaboratorsCount'.trParams({'count': collaborators.toString()}), style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.cardBg,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
          ),
          if (ownerName.isNotEmpty || ownerEmail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${'owner'.tr}: $ownerName${ownerEmail.isNotEmpty ? ' · $ownerEmail' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.listId,
    required this.sectionKey,
    required this.label,
    required this.items,
    this.canReorder = true,
    required this.accent,
    required this.onRefresh,
    required this.onSectionReorder,
  });

  final int listId;
  final String sectionKey;
  final String label;
  final List<ListItem> items;
  final bool canReorder;
  final Color accent;
  final Future<void> Function() onRefresh;
  final Future<void> Function(List<ListItem> newOrder) onSectionReorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.label_rounded,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.onSurface,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '${items.length}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.grey.shade700, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (canReorder)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: (oldIndex, newIndex) {
                final newOrder = List<ListItem>.from(items);
                final item = newOrder.removeAt(oldIndex);
                newOrder.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
                onSectionReorder(newOrder);
              },
              itemBuilder: (context, index) {
                final item = items[index];
                return KeyedSubtree(
                  key: ValueKey(item.id),
                  child: ReorderableDelayedDragStartListener(
                    index: index,
                    child: _ItemTile(
                      listId: listId,
                      item: item,
                      accent: accent,
                      onRefresh: onRefresh,
                      showDragHandle: true,
                    ),
                  ),
                );
              },
            )
          else
            ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _ItemTile(
                  listId: listId,
                  item: item,
                  accent: accent,
                  onRefresh: onRefresh,
                  showDragHandle: false,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatefulWidget {
  const _ItemTile({
    required this.listId,
    required this.item,
    required this.accent,
    required this.onRefresh,
    this.showDragHandle = false,
  });

  final int listId;
  final ListItem item;
  final Color accent;
  final Future<void> Function() onRefresh;
  final bool showDragHandle;

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _updating = false;

  Future<void> _toggleCompleted() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await AuthService.instance.updateListItem(
        widget.listId,
        widget.item.id,
        completed: !widget.item.completed,
      );
      await widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _deleteItem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete'.tr),
        content: Text('removeItemConfirm'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('cancel'.tr)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('delete'.tr)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _updating = true);
    try {
      await AuthService.instance.deleteListItem(widget.listId, widget.item.id);
      await widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _claimItem() async {
    if (_updating || widget.item.isClaimed) return;
    setState(() => _updating = true);
    try {
      await AuthService.instance.claimListItem(widget.listId, widget.item.id);
      await widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("You'll buy this item."), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _toggleOutOfStock() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await AuthService.instance.toggleItemOutOfStock(widget.listId, widget.item.id);
      await widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _openItemChat() async {
    await showItemChatSheet(
      context,
      listId: widget.listId,
      itemId: widget.item.id,
      itemName: widget.item.name,
      accent: widget.accent,
    );
  }

  Future<void> _showItemMenu() async {
    if (_updating) return;
    final item = widget.item;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.quantity > 1 ? '${item.name} × ${item.quantity}' : item.name,
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.chat_bubble_outline, color: widget.accent),
                title: Text('itemChatTooltip'.tr),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openItemChat();
                },
              ),
              if (!item.isClaimed)
                ListTile(
                  leading: Icon(Icons.shopping_bag_outlined, color: widget.accent),
                  title: Text('illBuyThis'.tr),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _claimItem();
                  },
                ),
              ListTile(
                leading: Icon(
                  item.isOutOfStock ? Icons.inventory_2 : Icons.inventory_2_outlined,
                  color: Colors.orange.shade800,
                ),
                title: Text(item.isOutOfStock ? 'backInStock'.tr : 'outOfStock'.tr),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _toggleOutOfStock();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('delete'.tr, style: const TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteItem();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDone = item.completed;
    final isOos = item.isOutOfStock;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
          color: isDone
              ? Colors.grey.shade600
              : (isOos ? VintagePalette.orangeDark : AppColors.onSurface),
        );

    final tile = ListTile(
      dense: true,
      enabled: !_updating,
      visualDensity: VisualDensity.compact,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showDragHandle)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(Icons.drag_handle, size: 18, color: Colors.grey.shade500),
            ),
          IconButton(
            icon: Icon(
              isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: isDone ? widget.accent : Colors.grey.shade400,
              size: 22,
            ),
            onPressed: _updating ? null : _toggleCompleted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
      title: Text(
        item.quantity > 1 ? '${item.name} × ${item.quantity}' : item.name,
        style: textStyle?.copyWith(fontSize: 14),
      ),
      subtitle: (item.completedByName?.trim().isNotEmpty ?? false)
          ? Text(
              'completedBy'.trParams({'name': item.completedByName!.trim()}),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 12),
            )
          : isOos
              ? Text(
                  'outOfStock'.tr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                )
              : item.isClaimed
                  ? Text(
                      '${item.claimedByName ?? 'Someone'} will buy this',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.accent,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    )
                  : null,
      trailing: IconButton(
        tooltip: 'itemOptions'.tr,
        icon: Icon(Icons.more_vert_rounded, size: 22, color: Colors.grey.shade700),
        onPressed: _updating ? null : _showItemMenu,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );

    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.44,
        children: [
          SlidableAction(
            onPressed: (_) => _toggleCompleted(),
            backgroundColor: widget.accent,
            foregroundColor: AppColors.onPrimary,
            icon: isDone ? Icons.undo : Icons.check,
            label: isDone ? 'incompleteItem'.tr : 'completeItem'.tr,
          ),
          SlidableAction(
            onPressed: (_) => _toggleOutOfStock(),
            backgroundColor: AppColors.cta,
            foregroundColor: AppColors.onCta,
            icon: isOos ? Icons.inventory_2 : Icons.remove_shopping_cart_outlined,
            label: isOos ? 'backInStock'.tr : 'outOfStock'.tr,
          ),
          SlidableAction(
            onPressed: (_) => _deleteItem(),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'delete'.tr,
          ),
        ],
      ),
      child: tile,
    );
  }
}

