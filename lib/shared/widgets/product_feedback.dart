import 'package:flutter/material.dart';
import '../../domain/shared/product_failure.dart';
import '../design_system/momcozy_design_system.dart';

class ProductErrorView extends StatelessWidget {
  const ProductErrorView({
    super.key,
    required this.failure,
    this.onRetry,
    this.preserveDraft = false,
  });
  final ProductFailure failure;
  final VoidCallback? onRetry;
  final bool preserveDraft;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure.kind) {
      ProductFailureKind.offline => '网络未连接，请连接后重试',
      ProductFailureKind.unauthenticated => '登录已过期，请重新登录后继续',
      ProductFailureKind.forbidden => '当前账号没有访问权限',
      ProductFailureKind.conflict => '记录已在其他页面更新，请重新载入后核对',
      ProductFailureKind.invalid => '请检查填写内容后重试',
      ProductFailureKind.unavailable => '暂时无法载入，请稍后重试',
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MomCozyColors.amberSoft,
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(color: MomCozyColors.foreground),
            ),
            if (preserveDraft) const Text('这次填写的内容仍然保留。'),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  failure.kind == ProductFailureKind.conflict ? '重新载入' : '重试',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProductEmptyView extends StatelessWidget {
  const ProductEmptyView({
    super.key,
    required this.title,
    this.description,
    this.action,
    this.icon,
    this.foreground,
  });
  final String title;
  final String? description;
  final Widget? action;
  final IconData? icon;
  final Color? foreground;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: MomCozyIconSizes.feature,
            color: foreground ?? MomCozyColors.iconSecondary,
          ),
          const SizedBox(height: MomCozySpacing.content),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w600,
            fontSize: MomCozyTypography.titleSize,
          ),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(color: foreground),
            ),
          ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: action!),
      ],
    ),
  );
}

class ProductLoadingView extends StatelessWidget {
  const ProductLoadingView({super.key, this.label, this.foreground});
  final String? label;
  final Color? foreground;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(MomCozySpacing.section),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: foreground),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: MomCozySpacing.content),
              child: Text(
                label!,
                textAlign: TextAlign.center,
                style: MomCozyTypography.secondaryText.copyWith(
                  color: foreground,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A non-interactive skeleton with no fake content or perpetual animation.
class ProductSkeleton extends StatelessWidget {
  const ProductSkeleton({super.key, this.lines = 3, this.label = '正在载入'});
  final int lines;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lines; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: MomCozySpacing.content),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: index == lines - 1 ? .65 : 1,
                child: Container(
                  height: MomCozySpacing.page,
                  decoration: BoxDecoration(
                    color: MomCozyColors.secondary,
                    borderRadius: BorderRadius.circular(MomCozyRadii.badge),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
