import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sharecart/components/app_bottom_nav.dart';
import 'package:sharecart/components/language_switcher.dart';
import 'package:sharecart/screens/list_detail_screen.dart';
import 'package:sharecart/screens/static_content_screen.dart';
import 'package:sharecart/screens/settings_screen.dart';
import 'package:sharecart/screens/welcome_screen.dart';
import 'package:sharecart/services/auth_service.dart';
import 'package:sharecart/theme/app_decorations.dart';
import 'package:sharecart/theme/app_theme.dart';
import 'package:sharecart/utils/list_icon_helper.dart';


class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key, this.initialTabIndex = 0, this.initialSnackbar});

  final int initialTabIndex;
  final String? initialSnackbar;

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex.clamp(0, 2);
    if (AuthService.instance.isLoggedIn) {
      AuthService.instance.registerFcmTokenWithBackend();
    }
    if (widget.initialSnackbar != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.initialSnackbar!)),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'lists'.tr : _currentIndex == 1 ? 'archived'.tr : 'myProfile'.tr,
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: const [
          LanguageSwitcher(),
        ],
      ),
      body: Container(
        decoration: AppDecorations.pageBackground(),
        child: SafeArea(
          child: IndexedStack(
          index: _currentIndex,
          children: [
            KeyedSubtree(key: const ValueKey(0), child: _ListsTab(accent: Theme.of(context).colorScheme.primary)),
            KeyedSubtree(key: const ValueKey(1), child: _ArchivedTab(accent: Theme.of(context).colorScheme.primary, isVisible: _currentIndex == 1)),
            KeyedSubtree(key: const ValueKey(2), child: _ProfileTab(accent: Theme.of(context).colorScheme.primary)),
          ],
        ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

}

class _ListsTab extends StatefulWidget {
  const _ListsTab({required this.accent});

  final Color accent;

  @override
  State<_ListsTab> createState() => _ListsTabState();
}

class _ListsTabState extends State<_ListsTab> {
  late Future<ListsIndexResult> _listsFuture;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  String _searchQuery = '';
  bool _joinLoading = false;

  @override
  void initState() {
    super.initState();
    _listsFuture = AuthService.instance.fetchLists();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinListByCode() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('invalidCode'.tr)),
      );
      return;
    }
    setState(() => _joinLoading = true);
    try {
      final result = await AuthService.instance.joinByCode(code);
      if (!mounted) return;
      _joinCodeController.clear();
      _refreshLists();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'joinedList'.tr} "${result.list.name}"'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListDetailScreen(
            listId: result.list.id,
            summary: ListSummary(
              id: result.list.id,
              name: result.list.name,
              dueDate: result.list.dueDate,
              archivedAt: result.list.archivedAt,
              itemsCount: result.list.items.length,
              joinCode: result.list.joinCode,
              icon: result.list.icon,
            ),
          ),
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
      if (mounted) setState(() => _joinLoading = false);
    }
  }

  void _refreshLists() {
    setState(() {
      _listsFuture = AuthService.instance.fetchLists();
    });
  }

  Future<void> _showCreateListDialog() async {
    final accent = widget.accent;
    List<String> icons = ['🛒', '🏠', '🎉', '🛍️', '📋', '🥗', '🍎', '🧾'];
    try {
      icons = await AuthService.instance.fetchListIcons();
      if (icons.isEmpty) icons = ['🛒', '🏠', '🎉', '🛍️', '📋', '🥗', '🍎', '🧾'];
    } catch (_) {}

    final nameController = TextEditingController();
    DateTime? pickedDate;
    String? selectedIcon;

    if (!mounted) return;
    final created = await showDialog<ListDetail?>(
      context: context,
      builder: (context) {
        var isLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('createListTitle'.tr),
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
                      enabled: !isLoading,
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
                              color: selectedIcon == null ? accent.withValues(alpha: 0.15) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedIcon == null ? accent : Colors.grey.shade300,
                                width: selectedIcon == null ? 2 : 1,
                              ),
                            ),
                            child: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
                          ),
                        ),
                        ...icons.map((iconCode) {
                          final isSelected = selectedIcon == iconCode;
                          final display = ListIconHelper.toEmoji(iconCode) ?? iconCode;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedIcon = iconCode),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? accent.withValues(alpha: 0.15) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? accent : Colors.grey.shade300,
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
                    Text(
'dueDateOptional'.tr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                              );
                              if (date != null) {
                                setDialogState(() => pickedDate = date);
                              }
                            },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        pickedDate == null
                            ? 'Pick date'
                            : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('nameRequired'.tr)),
                            );
                            return;
                          }
                          setDialogState(() => isLoading = true);
                          final dueDate = pickedDate == null
                              ? null
                              : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}';
                          try {
                            final iconToSend = selectedIcon != null ? (ListIconHelper.toEmoji(selectedIcon) ?? selectedIcon) : null;
                            final detail = await AuthService.instance.createList(
                              name,
                              dueDate: dueDate,
                              icon: iconToSend,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop(detail);
                          } catch (e) {
                            setDialogState(() => isLoading = false);
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
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onCta),
                        )
                      : Text('createNewList'.tr),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (created != null) {
      _refreshLists();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('createListSuccess'.tr),
          backgroundColor: AppColors.success,
        ),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListDetailScreen(
            listId: created.id,
            summary: ListSummary(
              id: created.id,
              name: created.name,
              dueDate: created.dueDate,
              archivedAt: created.archivedAt,
              itemsCount: created.items.length,
              joinCode: created.joinCode,
              icon: created.icon,
            ),
          ),
        ),
      );
      if (mounted) _refreshLists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
'goodToSeeYou'.tr,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
'yourSharedCarts'.tr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showCreateListDialog,
                icon: const Icon(Icons.add_circle_outline),
                color: accent,
                tooltip: 'createNewList'.tr,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'searchLists'.tr,
              prefixIcon: const Icon(Icons.search, size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        if (AuthService.instance.isLoggedIn) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _joinCodeController,
                    decoration: InputDecoration(
                      hintText: 'joinListCodeHint'.tr,
                      prefixIcon: const Icon(Icons.link, size: 20),
                      isDense: true,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    enabled: !_joinLoading,
                    onSubmitted: (_) => _joinListByCode(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _joinLoading ? null : _joinListByCode,
                  icon: _joinLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onCta),
                        )
                      : const Icon(Icons.login, size: 18),
                  label: Text('joinWithCode'.tr),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.cta,
                    foregroundColor: AppColors.onCta,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Expanded(
          child: FutureBuilder<ListsIndexResult>(
            future: _listsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                final isUnauthorized = AuthService.isUnauthorizedError(snapshot.error);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isUnauthorized ? 'sessionExpiredMessage'.tr : snapshot.error.toString(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.red.shade700,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        if (isUnauthorized) ...[
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
                );
              }

              final result = snapshot.data!;
              final active = result.active;
              final filtered = _searchQuery.isEmpty
                  ? active
                  : active.where((l) => l.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              final hasActive = filtered.isNotEmpty;
              final fromCache = AuthService.instance.listsFromCache;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (fromCache)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        setState(() {
                          _listsFuture = AuthService.instance.fetchLists();
                        });
                        await _listsFuture;
                      },
                      child: hasActive
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          Text(
'activeLists'.tr,
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurface,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          ...filtered.map(
                            (list) => _ListCard(
                              summary: list,
                              accent: accent,
                              onRefresh: _refreshLists,
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height - 200,
                          child: _EmptyListsState(accent: accent),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyListsState extends StatelessWidget {
  const _EmptyListsState({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.14),
                  accent.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
'noListsYet'.tr,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
'createFirstSharedCart'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Text(
'yourListsWillAppearHere'.tr,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.summary,
    required this.accent,
    this.onRefresh,
  });

  final ListSummary summary;
  final Color accent;
  final VoidCallback? onRefresh;

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<bool> _canCurrentUserDelete() async {
    try {
      final me = await AuthService.instance.me();
      final myId = _asInt(me['id']);
      if (myId == null) return false;

      final detail = await AuthService.instance.fetchListDetail(summary.id);
      final ownerId = _asInt(detail.owner['id']);
      if (ownerId == null) return false;

      return ownerId == myId;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleMenuAction(BuildContext context, String value) async {
    switch (value) {
      case 'open':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListDetailScreen(
              listId: summary.id,
              summary: summary,
            ),
          ),
        );
        if (context.mounted) onRefresh?.call();
        break;
      case 'archive':
        try {
          await AuthService.instance.archiveList(summary.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('listArchived'.tr), backgroundColor: AppColors.success),
          );
          onRefresh?.call();
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
          );
        }
        break;
      case 'restore':
        try {
          await AuthService.instance.restoreList(summary.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('listRestored'.tr), backgroundColor: AppColors.success),
          );
          onRefresh?.call();
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
          );
        }
        break;
      case 'delete':
        final canDelete = await _canCurrentUserDelete();
        if (!canDelete) {
          if (!context.mounted) return;
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
        if (ok != true || !context.mounted) return;
        try {
          await AuthService.instance.deleteList(summary.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('listDeleted'.tr), backgroundColor: AppColors.success),
          );
          onRefresh?.call();
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
          );
        }
        break;
      case 'leave':
        try {
          await AuthService.instance.leaveList(summary.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You left the list.'), backgroundColor: AppColors.success),
          );
          onRefresh?.call();
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDueDate = summary.dueDate != null;
    final isArchived = summary.archivedAt != null;
    final enterDuration = Duration(milliseconds: 220 + (summary.id % 5) * 35);

    return TweenAnimationBuilder<double>(
      duration: enterDuration,
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppDecorations.listCard(accent, archived: isArchived),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => _handleMenuAction(context, 'open'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isArchived
                        ? Colors.grey.shade200
                        : (summary.icon != null ? AppColors.cta : accent.withValues(alpha: 0.12)),
                    shape: BoxShape.circle,
                    border: summary.icon != null
                        ? Border.all(color: accent.withValues(alpha: 0.25))
                        : null,
                  ),
                  child: summary.icon != null && summary.icon!.isNotEmpty
                      ? (ListIconHelper.toEmoji(summary.icon) != null
                          ? Center(
                              child: Text(
                                ListIconHelper.toEmoji(summary.icon)!,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: isArchived ? Colors.grey.shade700 : accent,
                                ),
                              ),
                            )
                          : Icon(
                              isArchived ? Icons.archive_outlined : Icons.list_alt_outlined,
                              size: 20,
                              color: isArchived ? Colors.grey.shade700 : accent,
                            ))
                      : Icon(
                          isArchived ? Icons.archive_outlined : Icons.list_alt_outlined,
                          size: 20,
                          color: isArchived ? Colors.grey.shade700 : accent,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
'itemsCount'.trParams({'count': summary.itemsCount.toString()}),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                          ),
                          if (hasDueDate) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.event_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              summary.dueDate!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 22, color: Colors.grey.shade600),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                  onSelected: (value) => _handleMenuAction(context, value),
                  itemBuilder: (context) => [
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
                    PopupMenuItem(
                      value: isArchived ? 'restore' : 'archive',
                      child: Row(
                        children: [
                          Icon(
                            isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(isArchived ? 'restore'.tr : 'archive'.tr),
                        ],
                      ),
                    ),
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
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _ArchivedTab extends StatefulWidget {
  const _ArchivedTab({required this.accent, this.isVisible = false});

  final Color accent;
  final bool isVisible;

  @override
  State<_ArchivedTab> createState() => _ArchivedTabState();
}

class _ArchivedTabState extends State<_ArchivedTab> {
  late Future<ListsIndexResult> _listsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _listsFuture = AuthService.instance.fetchLists();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ArchivedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isVisible && widget.isVisible) {
      setState(() {
        _listsFuture = AuthService.instance.fetchLists();
      });
    }
  }

  void _refresh() {
    setState(() {
      _listsFuture = AuthService.instance.fetchLists();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
'archived'.tr,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'searchLists'.tr,
              prefixIcon: const Icon(Icons.search, size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              isDense: true,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<ListsIndexResult>(
            future: _listsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final isUnauthorized = AuthService.isUnauthorizedError(snapshot.error);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isUnauthorized ? 'sessionExpiredMessage'.tr : snapshot.error.toString(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.red.shade700,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        if (isUnauthorized) ...[
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
                );
              }
              final archived = snapshot.data!.archived;
              final filtered = _searchQuery.isEmpty
                  ? archived
                  : archived.where((l) => l.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              final fromCache = AuthService.instance.listsFromCache;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (fromCache)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        setState(() {
                          _listsFuture = AuthService.instance.fetchLists();
                        });
                        await _listsFuture;
                      },
                      child: filtered.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height - 200,
                          child: Center(
                            child: Text(
                              _searchQuery.isEmpty ? 'noArchivedLists'.tr : 'noListsMatchSearch'.tr,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final list = filtered[index];
                          return _ListCard(
                            summary: list,
                            accent: Colors.grey.shade500,
                            onRefresh: _refresh,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AuthService.instance.me(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          final isUnauthorized = AuthService.isUnauthorizedError(snapshot.error);
          return _ProfileError(
            accent: accent,
            message: isUnauthorized ? 'sessionExpiredMessage'.tr : snapshot.error.toString(),
            isSessionExpired: isUnauthorized,
          );
        }

        final user = snapshot.data ?? const <String, dynamic>{};
        final name = user['name'] as String? ?? 'guest'.tr;
        final email = user['email'] as String? ?? '';
        final createdAt = user['created_at'] as String?;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.person,
                      color: accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
'account'.tr,
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                    ),
                    const SizedBox(height: 12),
                    if (createdAt != null) ...[
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
'memberSince'.trParams({'date': createdAt}),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Icon(Icons.security_outlined,
                            size: 18, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
'listsProtected'.tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.settings_outlined, color: accent, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
'settings'.tr,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'legal'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _legalTile(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      title: 'privacyPolicy'.tr,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StaticContentScreen(
                            title: 'privacyPolicy'.tr,
                            body: StaticContent.privacyPolicy,
                          ),
                        ),
                      ),
                    ),
                    _legalTile(
                      context,
                      icon: Icons.description_outlined,
                      title: 'termsAndConditions'.tr,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StaticContentScreen(
                            title: 'termsAndConditions'.tr,
                            body: StaticContent.termsAndConditions,
                          ),
                        ),
                      ),
                    ),
                    _legalTile(
                      context,
                      icon: Icons.help_outline,
                      title: 'faq'.tr,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StaticContentScreen(
                            title: 'faq'.tr,
                            body: StaticContent.faq,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: () async {
                  try {
                    await AuthService.instance.logout();
                  } catch (_) {
                    // Ignore logout error here; token is cleared anyway.
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const WelcomeScreen(),
                    ),
                    (route) => false,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('logout'.tr),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _legalTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 22, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                    ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({
    required this.accent,
    required this.message,
    this.isSessionExpired = false,
  });

  final Color accent;
  final String message;
  final bool isSessionExpired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSessionExpired ? 'sessionExpiredMessage'.tr : 'couldNotLoadProfile'.tr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                ),
              ),
            ],
          ),
          if (!isSessionExpired) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const WelcomeScreen(),
                ),
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cta,
              foregroundColor: AppColors.onCta,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(isSessionExpired ? 'logInAgain'.tr : 'backToWelcome'.tr),
          ),
        ],
      ),
    );
  }
}
