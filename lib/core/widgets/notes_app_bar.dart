import 'package:flutter/material.dart';
import '../../features/settings/ui/settings_screen.dart';

class NotesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NotesAppBar({super.key, this.extraActions = const []});

  final List<Widget> extraActions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Notes Assistant'),
      centerTitle: true,
      actions: [
        ...extraActions,
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: 'Transcriptions',
          onPressed: Navigator.canPop(context)
              ? () => Navigator.popUntil(context, (r) => r.isFirst)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}
