import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/diary_theme.dart';

const kShareMemoMaxLength = 500;

/// Friend picker plus the memo that goes out with a 살까말까 share.
Future<({Set<String> friendIds, String memo})?> showShareToFriendsSheet({
  required BuildContext context,
  required AppStore store,
  String title = '보낼 친구 선택',
  String confirmLabel = '보내기',
  String initialMemo = '',
}) async {
  final following = store.friends.where((f) => f.isFollowing).toList();
  if (following.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('팔로잉한 친구가 없어요. 먼저 친구를 추가해 주세요.')),
    );
    return null;
  }

  final result =
      await showModalBottomSheet<({Set<String> friendIds, String memo})>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: DiaryColors.paper,
        builder: (sheetCtx) => ShareToFriendsSheet(
          following: following,
          title: title,
          confirmLabel: confirmLabel,
          initialMemo: initialMemo,
        ),
      );
  return result;
}

class ShareToFriendsSheet extends StatefulWidget {
  const ShareToFriendsSheet({
    super.key,
    required this.following,
    this.title = '보낼 친구 선택',
    this.confirmLabel = '보내기',
    this.initialMemo = '',
  });

  final List<Friend> following;
  final String title;
  final String confirmLabel;
  final String initialMemo;

  @override
  State<ShareToFriendsSheet> createState() => _ShareToFriendsSheetState();
}

class _ShareToFriendsSheetState extends State<ShareToFriendsSheet> {
  final _selected = <String>{};
  late final TextEditingController _memoCtrl;

  @override
  void initState() {
    super.initState();
    _memoCtrl = TextEditingController(text: widget.initialMemo);
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // Keyboard MediaQuery dependents must drop before this route unmounts,
    // otherwise Flutter asserts `_dependents.isEmpty` in debug.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context, (
      friendIds: Set<String>.from(_selected),
      memo: _memoCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: DiaryTheme.body(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '고민되는 이유를 짧게 적어 같이 보내요',
                  style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _memoCtrl,
                  maxLines: 3,
                  maxLength: kShareMemoMaxLength,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '예: 이걸 사 말아',
                    filled: true,
                    fillColor: DiaryColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.following.length,
                    itemBuilder: (context, i) {
                      final f = widget.following[i];
                      final checked = _selected.contains(f.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(f.id);
                            } else {
                              _selected.remove(f.id);
                            }
                          });
                        },
                        secondary: CircleAvatar(
                          backgroundColor: DiaryColors.folderPeach,
                          backgroundImage: f.avatar.startsWith('http')
                              ? NetworkImage(f.avatar)
                              : null,
                          child: Text(
                            f.name.isNotEmpty ? f.name[0] : '?',
                            style: DiaryTheme.body(14, weight: FontWeight.w700),
                          ),
                        ),
                        title: Text(f.name),
                        subtitle: Text(f.username),
                      );
                    },
                  ),
                ),
                FilledButton(
                  onPressed: _selected.isEmpty ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: DiaryColors.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('${widget.confirmLabel} (${_selected.length})'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
