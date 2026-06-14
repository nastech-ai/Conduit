import 'package:conduit/core/theme/app_palette.dart';
import 'package:conduit/core/presentation/system_navigation_insets.dart';
import 'package:conduit/core/theme/terminal_appearance.dart';
import 'package:conduit/features/terminal/presentation/terminal_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:conduit_vt/conduit_vt.dart';

class TerminalKeyboardBar extends StatelessWidget {
  const TerminalKeyboardBar({
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.brightness,
    required this.actions,
    required this.fullscreen,
    required this.onToggleFullscreen,
    super.key,
  });

  final TerminalSessionController controller;
  final FocusNode focusNode;
  final AppPalette palette;
  final Brightness brightness;
  final List<TerminalKeyboardAction> actions;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    return ListenableBuilder(
      listenable: controller.keyboard,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.canvasFor(brightness),
            border: Border(
              top: BorderSide(color: palette.hairlineFor(brightness)),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: shouldApplyBottomSafeArea(context),
            left: false,
            right: false,
            child: SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(
                  safePadding.left + 8,
                  7,
                  safePadding.right + 8,
                  7,
                ),
                children: [for (final action in actions) _buildAction(action)],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAction(TerminalKeyboardAction action) {
    return switch (action) {
      TerminalKeyboardAction.control => _ToggleKey(
        label: action.label,
        palette: palette,
        brightness: brightness,
        selected: controller.keyboard.ctrl,
        onPressed: () {
          controller.keyboard.ctrl = !controller.keyboard.ctrl;
          _focusTerminal();
        },
      ),
      TerminalKeyboardAction.alt => _ToggleKey(
        label: action.label,
        palette: palette,
        brightness: brightness,
        selected: controller.keyboard.alt,
        onPressed: () {
          controller.keyboard.alt = !controller.keyboard.alt;
          _focusTerminal();
        },
      ),
      TerminalKeyboardAction.fullscreen => _Key(
        icon: fullscreen
            ? Icons.fullscreen_exit_rounded
            : Icons.fullscreen_rounded,
        palette: palette,
        brightness: brightness,
        onPressed: () {
          onToggleFullscreen();
          _focusTerminal();
        },
      ),
      TerminalKeyboardAction.arrowUp => _Key(
        icon: Icons.keyboard_arrow_up_rounded,
        palette: palette,
        brightness: brightness,
        onPressed: () => _sendKey(TerminalKey.arrowUp),
      ),
      TerminalKeyboardAction.arrowDown => _Key(
        icon: Icons.keyboard_arrow_down_rounded,
        palette: palette,
        brightness: brightness,
        onPressed: () => _sendKey(TerminalKey.arrowDown),
      ),
      TerminalKeyboardAction.arrowLeft => _Key(
        icon: Icons.keyboard_arrow_left_rounded,
        palette: palette,
        brightness: brightness,
        onPressed: () => _sendKey(TerminalKey.arrowLeft),
      ),
      TerminalKeyboardAction.arrowRight => _Key(
        icon: Icons.keyboard_arrow_right_rounded,
        palette: palette,
        brightness: brightness,
        onPressed: () => _sendKey(TerminalKey.arrowRight),
      ),
      TerminalKeyboardAction.paste => _Key(
        icon: Icons.content_paste_rounded,
        palette: palette,
        brightness: brightness,
        onPressed: _paste,
      ),
      TerminalKeyboardAction.functionKeys => _FunctionKeysMenu(
        palette: palette,
        brightness: brightness,
        onSelected: (key) => _sendKey(key),
      ),
      _ => _Key(
        label: action.label,
        palette: palette,
        brightness: brightness,
        onPressed: () => _triggerAction(action),
      ),
    };
  }

  void _triggerAction(TerminalKeyboardAction action) {
    switch (action) {
      case TerminalKeyboardAction.escape:
        _sendKey(TerminalKey.escape);
      case TerminalKeyboardAction.tab:
        _sendKey(TerminalKey.tab);
      case TerminalKeyboardAction.home:
        _sendKey(TerminalKey.home);
      case TerminalKeyboardAction.end:
        _sendKey(TerminalKey.end);
      case TerminalKeyboardAction.pageUp:
        _sendKey(TerminalKey.pageUp);
      case TerminalKeyboardAction.pageDown:
        _sendKey(TerminalKey.pageDown);
      case TerminalKeyboardAction.controlC:
        _sendControl(TerminalKey.keyC);
      case TerminalKeyboardAction.controlD:
        _sendControl(TerminalKey.keyD);
      case TerminalKeyboardAction.controlZ:
        _sendControl(TerminalKey.keyZ);
      case TerminalKeyboardAction.controlL:
        _sendControl(TerminalKey.keyL);
      case TerminalKeyboardAction.colon:
        _sendText(':');
      case TerminalKeyboardAction.slash:
        _sendText('/');
      case TerminalKeyboardAction.pipe:
        _sendText('|');
      case TerminalKeyboardAction.dash:
        _sendText('-');
      case TerminalKeyboardAction.control:
      case TerminalKeyboardAction.alt:
      case TerminalKeyboardAction.fullscreen:
      case TerminalKeyboardAction.arrowUp:
      case TerminalKeyboardAction.arrowDown:
      case TerminalKeyboardAction.arrowLeft:
      case TerminalKeyboardAction.arrowRight:
      case TerminalKeyboardAction.paste:
      case TerminalKeyboardAction.functionKeys:
        break;
    }
  }

  void _sendKey(TerminalKey key) {
    controller.sendKey(key);
    _focusTerminal();
  }

  void _sendControl(TerminalKey key) {
    controller.sendControl(key);
    _focusTerminal();
  }

  void _sendText(String text) {
    controller.sendText(text);
    _focusTerminal();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      controller.paste(text);
    }
    _focusTerminal();
  }

  void _focusTerminal() {
    if (focusNode.canRequestFocus) {
      focusNode.requestFocus();
    }
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.onPressed,
    required this.palette,
    required this.brightness,
    this.label,
    this.icon,
  });

  final AppPalette palette;
  final Brightness brightness;
  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isIconKey = icon != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: palette.panelFor(brightness),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            height: 36,
            constraints: BoxConstraints(minWidth: isIconKey ? 44 : 46),
            padding: EdgeInsets.symmetric(horizontal: isIconKey ? 0 : 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.hairlineFor(brightness)),
            ),
            child: icon == null
                ? Text(
                    label ?? '',
                    style: TextStyle(
                      color: palette.foregroundFor(brightness),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  )
                : Icon(
                    icon,
                    color: palette.foregroundFor(brightness),
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ToggleKey extends StatelessWidget {
  const _ToggleKey({
    required this.label,
    required this.palette,
    required this.brightness,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final AppPalette palette;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = palette.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.22),
                palette.panelFor(brightness),
              )
            : palette.panelFor(brightness),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 50,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.7)
                    : palette.hairlineFor(brightness),
                width: selected ? 1.3 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? accent : palette.foregroundFor(brightness),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FunctionKeysMenu extends StatelessWidget {
  const _FunctionKeysMenu({
    required this.palette,
    required this.brightness,
    required this.onSelected,
  });

  final AppPalette palette;
  final Brightness brightness;
  final ValueChanged<TerminalKey> onSelected;

  static const _keys = [
    (label: 'F1', key: TerminalKey.f1),
    (label: 'F2', key: TerminalKey.f2),
    (label: 'F3', key: TerminalKey.f3),
    (label: 'F4', key: TerminalKey.f4),
    (label: 'F5', key: TerminalKey.f5),
    (label: 'F6', key: TerminalKey.f6),
    (label: 'F7', key: TerminalKey.f7),
    (label: 'F8', key: TerminalKey.f8),
    (label: 'F9', key: TerminalKey.f9),
    (label: 'F10', key: TerminalKey.f10),
    (label: 'F11', key: TerminalKey.f11),
    (label: 'F12', key: TerminalKey.f12),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: PopupMenuButton<TerminalKey>(
        tooltip: 'Function keys',
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final item in _keys)
            PopupMenuItem(value: item.key, child: Text(item.label)),
        ],
        child: Container(
          width: 44,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.panelFor(brightness),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.hairlineFor(brightness)),
          ),
          child: Text(
            'Fn',
            style: TextStyle(
              color: palette.foregroundFor(brightness),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
