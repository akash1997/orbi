import 'dart:math';
import 'package:flutter/material.dart';

class Drawer3D extends StatefulWidget {
  final Widget child;
  final bool isMonitoring;
  final String monitoredFolderPath;
  final VoidCallback? onChangeFolderTap;
  final VoidCallback? onViewRecordingsTap;

  const Drawer3D({
    super.key,
    required this.child,
    required this.isMonitoring,
    required this.monitoredFolderPath,
    this.onChangeFolderTap,
    this.onViewRecordingsTap,
  });

  @override
  State<Drawer3D> createState() => Drawer3DState();
}

class Drawer3DState extends State<Drawer3D>
    with SingleTickerProviderStateMixin {
  static const double _maxSlideRatio = 0.75;
  static const double _extraHeightRatio = 0.1;
  double _startingPos = 0;
  var _drawerVisible = false;
  late AnimationController _animationController;
  Size _screen = const Size(0, 0);
  late CurvedAnimation _animator;

  double get _maxSlide => _screen.width * _maxSlideRatio;
  double get _extraHeight => _screen.height * _extraHeightRatio;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animator = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutQuad,
      reverseCurve: Curves.easeInQuad,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screen = MediaQuery.of(context).size;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: GestureDetector(
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            _buildBackground(),
            _buildOverlay(),
            _buildDrawer(),
            _buildHeader(),
          ],
        ),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    _startingPos = details.globalPosition.dx;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final globalDelta = details.globalPosition.dx - _startingPos;
    if (globalDelta > 0) {
      final pos = globalDelta / _screen.width;
      if (_drawerVisible && pos <= 1.0) return;
      _animationController.value = pos;
    } else {
      final pos = 1 - (globalDelta.abs() / _screen.width);
      if (!_drawerVisible && pos >= 0.0) return;
      _animationController.value = pos;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (details.velocity.pixelsPerSecond.dx.abs() > 500) {
      if (details.velocity.pixelsPerSecond.dx > 0) {
        _animationController.forward(from: _animationController.value);
        _drawerVisible = true;
      } else {
        _animationController.reverse(from: _animationController.value);
        _drawerVisible = false;
      }
      return;
    }
    if (_animationController.value > 0.5) {
      _animationController.forward(from: _animationController.value);
      _drawerVisible = true;
    } else {
      _animationController.reverse(from: _animationController.value);
      _drawerVisible = false;
    }
  }

  void toggleDrawer() {
    if (_animationController.value < 0.5) {
      _animationController.forward();
      _drawerVisible = true;
    } else {
      _animationController.reverse();
      _drawerVisible = false;
    }
  }

  Widget _buildBackground() => Positioned.fill(
        top: -_extraHeight,
        bottom: -_extraHeight,
        child: AnimatedBuilder(
          animation: _animator,
          builder: (context, widget) => Transform.translate(
            offset: Offset(_maxSlide * _animator.value, 0),
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY((pi / 2 + 0.1) * -_animator.value),
              alignment: Alignment.centerLeft,
              child: widget,
            ),
          ),
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      );

  Widget _buildDrawer() => Positioned.fill(
        top: -_extraHeight,
        bottom: -_extraHeight,
        left: 0,
        right: _screen.width - _maxSlide,
        child: AnimatedBuilder(
          animation: _animator,
          builder: (context, widget) {
            final isOpen = _animator.value >= 0.2;
            return Transform.translate(
              offset: Offset(_maxSlide * (_animator.value - 1), 0),
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(pi * (1 - _animator.value) / 2),
                alignment: Alignment.centerRight,
                child: IgnorePointer(
                  ignoring: !isOpen,
                  child: widget,
                ),
              ),
            );
          },
          child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Shadow edge
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black12,
                        ],
                      ),
                    ),
                  ),
                ),
                // Settings content
                Positioned.fill(
                  top: _extraHeight,
                  bottom: _extraHeight,
                  child: SafeArea(
                    child: SizedBox(
                      width: _maxSlide,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Header
                            Row(
                              children: [
                                const Icon(
                                  Icons.settings,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Settings',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Monitoring Status Card
                            _buildStatusCard(context),
                            const SizedBox(height: 24),

                            const Divider(),
                            const SizedBox(height: 16),

                            // View Recordings Option
                            _buildSettingTile(
                              context,
                              icon: Icons.audio_file,
                              title: 'View Recordings',
                              subtitle: 'Browse all audio files',
                              enabled: true,
                              onTap: widget.onViewRecordingsTap,
                            ),

                            // Change Folder Option
                            _buildSettingTile(
                              context,
                              icon: Icons.folder,
                              title: 'Change Folder',
                              subtitle: 'Modify monitored folder',
                              enabled: true,
                              onTap: widget.onChangeFolderTap,
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 24),

                            // Phase 2 Settings
                            Text(
                              'COMING IN PHASE 2',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 16),

                            _buildSettingTile(
                              context,
                              icon: Icons.notifications,
                              title: 'Notifications',
                              subtitle: 'Alert preferences',
                              enabled: false,
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.language,
                              title: 'Language',
                              subtitle: 'App language',
                              enabled: false,
                            ),
                            _buildSettingTile(
                              context,
                              icon: Icons.info_outline,
                              title: 'About',
                              subtitle: 'Version & info',
                              enabled: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        leading: Icon(icon, size: 24),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMonitoring
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isMonitoring ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.isMonitoring ? 'Monitoring Active' : 'Monitoring Inactive',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.folder,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.monitoredFolderPath,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => SafeArea(
        child: AnimatedBuilder(
          animation: _animator,
          builder: (_, __) {
            return Transform.translate(
              offset: Offset((_screen.width - 60) * _animator.value, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: IconButton(
                      onPressed: toggleDrawer,
                      icon: const Icon(Icons.menu),
                    ),
                  ),
                  Opacity(
                    opacity: 1 - _animator.value,
                    child: Text(
                      "ORBI",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(width: 50, height: 50),
                ],
              ),
            );
          },
        ),
      );

  Widget _buildOverlay() => Positioned.fill(
        child: AnimatedBuilder(
          animation: _animator,
          builder: (_, widget) {
            final ignoreOverlay = _animator.value > 0.0;
            return IgnorePointer(
              ignoring: ignoreOverlay,
              child: Opacity(
                opacity: 1 - _animator.value,
                child: Transform.translate(
                  offset: Offset((_maxSlide + 50) * _animator.value, 0),
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY((pi / 2 + 0.1) * -_animator.value),
                    alignment: Alignment.centerLeft,
                    child: widget,
                  ),
                ),
              ),
            );
          },
          child: widget.child,
        ),
      );
}
