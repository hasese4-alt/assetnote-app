import 'package:flutter/material.dart';

/// 処理中に全画面をぐるぐるスピナーで覆い、ほかの操作を禁止するオーバーレイ。
///
/// 使い方:
///   LoadingOverlay(
///     isLoading: _isProcessing,
///     child: MyWidget(),
///   )
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
