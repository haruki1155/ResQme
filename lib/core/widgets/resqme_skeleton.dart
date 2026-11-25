import 'package:flutter/material.dart';

/// Subtle, brand-aligned skeleton surface block using ResQMe neutral surface tokens
/// (`#FFFFFF`, `#F1F3F7`, `#E2E8F0`) with zero external dependencies.
/// Automatically disables motion when `MediaQuery.disableAnimationsOf(context)` is true.
class ResQMeSkeletonBox extends StatefulWidget {
  const ResQMeSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  @override
  State<ResQMeSkeletonBox> createState() => _ResQMeSkeletonBoxState();
}

class _ResQMeSkeletonBoxState extends State<ResQMeSkeletonBox>
    with SingleTickerProviderStateMixin {
  static const _baseTone = Color(0xFFE2E8F0);
  static const _softTone = Color(0xFFF1F3F7);

  AnimationController? _controller;
  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation(MediaQuery.disableAnimationsOf(context));
  }

  void _syncAnimation(bool disableAnimations) {
    if (disableAnimations) {
      _controller?.stop();
      _animating = false;
      return;
    }
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    if (!_animating) {
      _animating = true;
      _controller!.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations || _controller == null) {
      return Semantics(
        excludeSemantics: true,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _baseTone,
            borderRadius: widget.borderRadius,
          ),
        ),
      );
    }

    return Semantics(
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, _) {
          final color = Color.lerp(_softTone, _baseTone, _controller!.value)!;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: widget.borderRadius,
            ),
          );
        },
      ),
    );
  }
}

/// Initial-load skeleton matching `PortalDashboardScreen` roster + student metric cards.
class PortalDashboardSkeleton extends StatelessWidget {
  const PortalDashboardSkeleton({super.key});

  Widget _statCardPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResQMeSkeletonBox(width: 110, height: 12),
          SizedBox(height: 10),
          ResQMeSkeletonBox(width: 64, height: 24),
          SizedBox(height: 8),
          ResQMeSkeletonBox(height: 11),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading dashboard statistics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ResQMeSkeletonBox(width: 180, height: 14),
          const SizedBox(height: 8),
          _statCardPlaceholder(),
          const SizedBox(height: 16),
          const ResQMeSkeletonBox(width: 160, height: 14),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _statCardPlaceholder()),
              const SizedBox(width: 10),
              Expanded(child: _statCardPlaceholder()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _statCardPlaceholder()),
              const SizedBox(width: 10),
              Expanded(child: _statCardPlaceholder()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Initial-load card list skeleton matching Active Students, Student Roster,
/// Authorized Personnel, and Lost QR Management lists.
class PortalCardListSkeleton extends StatelessWidget {
  const PortalCardListSkeleton({
    super.key,
    this.itemCount = 4,
    this.scrollable = true,
  });

  final int itemCount;
  final bool scrollable;

  Widget _cardItem() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResQMeSkeletonBox(width: 170, height: 15),
                SizedBox(height: 8),
                ResQMeSkeletonBox(width: 210, height: 12),
              ],
            ),
          ),
          SizedBox(width: 12),
          ResQMeSkeletonBox(
            width: 76,
            height: 24,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!scrollable) {
      return Semantics(
        label: 'Loading records',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < itemCount; i++) ...[
              _cardItem(),
              if (i + 1 < itemCount) const SizedBox(height: 10),
            ],
          ],
        ),
      );
    }

    return Semantics(
      label: 'Loading records',
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, _) => _cardItem(),
      ),
    );
  }
}

/// Initial-load skeleton matching `StudentDetailsScreen` profile & supervision cards.
class PortalDetailsSkeleton extends StatelessWidget {
  const PortalDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading student details',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ResQMeSkeletonBox(width: 180, height: 20),
                        ),
                        SizedBox(width: 12),
                        ResQMeSkeletonBox(
                          width: 84,
                          height: 24,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    ResQMeSkeletonBox(height: 14),
                    SizedBox(height: 12),
                    ResQMeSkeletonBox(height: 14),
                    SizedBox(height: 12),
                    ResQMeSkeletonBox(height: 14),
                    SizedBox(height: 12),
                    ResQMeSkeletonBox(width: 220, height: 14),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResQMeSkeletonBox(width: 150, height: 15),
                    SizedBox(height: 12),
                    ResQMeSkeletonBox(height: 44),
                    SizedBox(height: 10),
                    ResQMeSkeletonBox(height: 44),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initial-load skeleton matching `ActivityLogsScreen` Manila date group + audit cards.
class ActivityLogsSkeleton extends StatelessWidget {
  const ActivityLogsSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading activity logs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 10),
            child: ResQMeSkeletonBox(width: 165, height: 13),
          ),
          for (var i = 0; i < itemCount; i++) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ResQMeSkeletonBox(width: 190, height: 15),
                      ),
                      SizedBox(width: 10),
                      ResQMeSkeletonBox(
                        width: 68,
                        height: 22,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  ResQMeSkeletonBox(width: 230, height: 12),
                  SizedBox(height: 8),
                  ResQMeSkeletonBox(width: 140, height: 11),
                ],
              ),
            ),
            if (i + 1 < itemCount) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Initial-load skeleton matching Student QR & device-readiness cards.
class StudentQrCardSkeleton extends StatelessWidget {
  const StudentQrCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading QR status',
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResQMeSkeletonBox(
                width: 200,
                height: 200,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              SizedBox(height: 14),
              ResQMeSkeletonBox(width: 160, height: 13),
            ],
          ),
        ),
      ),
    );
  }
}
