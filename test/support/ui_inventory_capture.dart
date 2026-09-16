import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opt-in inventory evidence from the images actually rendered by tests.
/// Normal test runs retain Flutter's original binding and comparator.
void installUiInventoryCapture(Directory output) {
  final binding = _InventoryBinding();
  final delegate = goldenFileComparator;
  goldenFileComparator = _InventoryComparator(delegate, output, binding);
}

class _InventoryBinding extends AutomatedTestWidgetsFlutterBinding {
  String description = '';
  int sequence = 0;
  final List<Map<String, Object?>> interactions = [];
  final Map<int, (Offset, List<String>, Duration)> _downs = {};

  @override
  Future<void> runTest(
    Future<void> Function() testBody,
    VoidCallback invariantTester, {
    String description = '',
  }) {
    this.description = description;
    sequence = 0;
    interactions.clear();
    _downs.clear();
    return super.runTest(testBody, invariantTester, description: description);
  }

  @override
  void handlePointerEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _downs[event.pointer] = (
        event.position,
        _textAt(event.position),
        event.timeStamp,
      );
    } else if (event is PointerUpEvent) {
      final down = _downs.remove(event.pointer);
      if (down != null) {
        interactions.add({
          'action': (down.$1 - event.position).distance > 12
              ? 'drag'
              : event.timeStamp - down.$3 >= const Duration(milliseconds: 500)
              ? 'long-press'
              : 'tap',
          'labels_at_start': down.$2,
          'from': [down.$1.dx, down.$1.dy],
          'to': [event.position.dx, event.position.dy],
        });
      }
    } else if (event is PointerCancelEvent) {
      _downs.remove(event.pointer);
    }
    super.handlePointerEvent(event);
  }

  List<String> _textAt(Offset position) {
    final result = <String>[];
    for (final element in find.byType(Text).evaluate()) {
      final render = element.findRenderObject();
      if (render is RenderBox && render.attached && render.hasSize) {
        final bounds = render.localToGlobal(Offset.zero) & render.size;
        if (bounds.inflate(12).contains(position)) {
          final widget = element.widget as Text;
          final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
          if (text.isNotEmpty) result.add(text);
        }
      }
    }
    return result;
  }
}

class _InventoryComparator extends GoldenFileComparator {
  _InventoryComparator(this.delegate, this.output, this.binding);
  final GoldenFileComparator delegate;
  final Directory output;
  final _InventoryBinding binding;

  @override
  Uri getTestUri(Uri key, int? version) => delegate.getTestUri(key, version);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final passed = await delegate.compare(imageBytes, golden);
    if (passed) await _record(imageBytes, golden);
    return passed;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    // Inventory is not allowed to approve a new baseline implicitly.
    throw StateError('Run inventory without --update-goldens.');
  }

  Future<void> _record(Uint8List bytes, Uri golden) async {
    final resolved = delegate is LocalFileComparator
        ? (delegate as LocalFileComparator).basedir.resolveUri(golden)
        : golden;
    final prefix = '${Directory.current.absolute.path}/';
    final relative = resolved.toFilePath().replaceFirst(prefix, '');
    if (!relative.startsWith('test/') || relative.contains('..')) {
      throw StateError('Unexpected inventory source: $relative');
    }
    final file = File('${output.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    final widgets = find
        .byWidgetPredicate((_) => true)
        .evaluate()
        .map((e) => e.widget.runtimeType.toString())
        .toSet();
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) {
          final widget = e.widget as Text;
          return widget.data ?? widget.textSpan?.toPlainText() ?? '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
    final foregroundScrollables = _foregroundScrollables().toSet();
    final scrolls = <Map<String, Object?>>[];
    for (final element in find.byType(Scrollable).evaluate()) {
      final state = (element as StatefulElement).state as ScrollableState;
      final position = state.position;
      if (!position.hasContentDimensions || !position.hasPixels) continue;
      scrolls.add({
        'foreground': foregroundScrollables.contains(element),
        'axis': position.axis.name,
        'direction': position.axisDirection.name,
        'pixels': position.pixels,
        'min': position.minScrollExtent,
        'max': position.maxScrollExtent,
        'viewport': position.viewportDimension,
      });
    }
    final png = ByteData.sublistView(bytes);
    final metadata = <String, Object?>{
      'source': relative,
      'evidence': 'current-widget-test-render; golden comparison passed',
      'test_description': binding.description,
      'sequence': binding.sequence++,
      'sha256': sha256.convert(bytes).toString(),
      'width': png.getUint32(16),
      'height': png.getUint32(20),
      'captured_at': DateTime.now().toUtc().toIso8601String(),
      'widget_types': widgets.toList()..sort(),
      'texts': texts,
      'scrolls': scrolls,
      'controls': _controls(),
      'needs_long_capture': scrolls.any(
        (s) =>
            s['foreground'] == true &&
            s['axis'] == 'vertical' &&
            (s['max'] as double) > 1,
      ),
      'interactions_since_previous_capture': List.of(binding.interactions),
      'call_stack': StackTrace.current.toString(),
    };
    if (Platform.environment['MOMCOZY_UI_INVENTORY_LONG'] == '1') {
      final result = await _captureLong(file);
      metadata['long_capture'] = result;
      if (result['status'] != 'complete-measured-scroll-stitch') {
        final stale = File(
          file.path.replaceFirst(RegExp(r'\.png$'), '.long.png'),
        );
        if (stale.existsSync()) stale.deleteSync();
      }
    }
    binding.interactions.clear();
    await File('${file.path}.json').writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(metadata)}\n',
    );
    final observation = sha256
        .convert(
          utf8.encode(
            '$relative|${binding.description}|${metadata['sequence']}',
          ),
        )
        .toString();
    final trace = File('${output.path}/observations/$observation.json');
    await trace.parent.create(recursive: true);
    await trace.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(metadata)}\n',
    );
  }

  List<Map<String, Object?>> _controls() {
    final result = <Map<String, Object?>>[];
    for (final element in find.byWidgetPredicate((_) => true).evaluate()) {
      final widget = element.widget;
      final bool enabled;
      if (widget is ButtonStyleButton) {
        enabled = widget.onPressed != null || widget.onLongPress != null;
      } else if (widget is IconButton) {
        enabled = widget.onPressed != null;
      } else if (widget is ListTile) {
        if (widget.onTap == null && widget.onLongPress == null) continue;
        enabled = widget.enabled;
      } else if (widget is InkWell) {
        if (widget.onTap == null && widget.onLongPress == null) continue;
        enabled = true;
      } else if (widget is Switch) {
        enabled = widget.onChanged != null;
      } else if (widget is Checkbox) {
        enabled = widget.onChanged != null;
      } else {
        continue;
      }
      if (!(ModalRoute.of(element)?.isCurrent ?? true)) continue;
      final render = element.findRenderObject();
      if (render is! RenderBox || !render.attached || !render.hasSize) continue;
      final bounds = render.localToGlobal(Offset.zero) & render.size;
      final labels = <String>{};
      void visit(Element child) {
        final value = child.widget;
        if (value is Text) {
          labels.add(value.data ?? value.textSpan?.toPlainText() ?? '');
        }
        if (value is Tooltip) {
          labels.add(value.message ?? value.richMessage?.toPlainText() ?? '');
        }
        child.visitChildren(visit);
      }

      visit(element);
      if (widget is IconButton && widget.tooltip != null) {
        labels.add(widget.tooltip!);
      }
      labels.remove('');
      result.add({
        'widget': widget.runtimeType.toString(),
        'key': widget.key?.toString(),
        'labels': labels.toList(),
        'enabled': enabled,
        'bounds': [bounds.left, bounds.top, bounds.width, bounds.height],
        'selected': widget is Switch
            ? widget.value
            : widget is Checkbox
            ? widget.value
            : null,
        'note':
            'Observed mounted control; nested InkWell may duplicate its parent button; not a completeness assertion',
      });
    }
    return result;
  }

  List<Element> _foregroundScrollables() {
    // A shell's inner PageRoute stays current when a root-navigator popup is
    // open. Select the top PopupRoute across both navigators, even when that
    // popup has no overflow; never stitch its obscured background page.
    PopupRoute<dynamic>? popup;
    for (final element
        in find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable ||
                  widget is Dialog ||
                  widget is BottomSheet,
            )
            .evaluate()) {
      final route = ModalRoute.of(element);
      if (route is PopupRoute<dynamic> && route.isCurrent) popup = route;
    }
    return find.byType(Scrollable).evaluate().where((element) {
      final route = ModalRoute.of(element);
      return popup != null
          ? identical(route, popup)
          : (route?.isCurrent ?? true);
    }).toList();
  }

  Future<Map<String, Object?>> _captureLong(File viewportFile) async {
    final candidates = _foregroundScrollables().where((element) {
      final state = (element as StatefulElement).state as ScrollableState;
      final p = state.position;
      // A keyboard can leave a very short but genuinely scrollable chat area.
      // Its content still needs a full capture; height is not an overflow test.
      return (ModalRoute.of(element)?.isCurrent ?? true) &&
          p.hasContentDimensions &&
          p.axis == Axis.vertical &&
          p.maxScrollExtent > 1 &&
          p.viewportDimension > 0;
    }).toList();
    if (candidates.isEmpty) return {'status': 'no-active-vertical-overflow'};
    bool hasAncestor(Element child, bool Function(Element) predicate) {
      var found = false;
      child.visitAncestorElements((ancestor) {
        if (predicate(ancestor)) found = true;
        return !found;
      });
      return found;
    }

    final editableScrolls = candidates
        .where(
          (candidate) => hasAncestor(
            candidate,
            (ancestor) => ancestor.widget is EditableText,
          ),
        )
        .toList();
    final pageScrolls = candidates
        .where((candidate) => !editableScrolls.contains(candidate))
        .toList();
    // A textarea is a bounded control inside the document, not a second page.
    // Stitch the enclosing form while retaining the textarea's actual scroll
    // state. Separate interaction captures must show its start/end states;
    // this image does not claim to expand all text inside the control.
    final nestedEditableOnly =
        pageScrolls.length == 1 &&
        editableScrolls.isNotEmpty &&
        editableScrolls.every(
          (candidate) => hasAncestor(
            candidate,
            (ancestor) => identical(ancestor, pageScrolls.single),
          ),
        );
    if (candidates.length != 1 && !nestedEditableOnly) {
      return {
        'status': 'needs-multiple-scroll-review',
        'count': candidates.length,
      };
    }
    final element = nestedEditableOnly ? pageScrolls.single : candidates.single;
    final nestedEditables = <Map<String, Object?>>[
      if (nestedEditableOnly)
        for (final candidate in editableScrolls)
          {
            'pixels': ((candidate as StatefulElement).state as ScrollableState)
                .position
                .pixels,
            'max':
                (candidate.state as ScrollableState).position.maxScrollExtent,
            'viewport':
                (candidate.state as ScrollableState).position.viewportDimension,
          },
    ];
    final position = (element as StatefulElement).state as ScrollableState;
    final p = position.position;
    if (p.axisDirection != AxisDirection.down) {
      return {'status': 'needs-reverse-scroll-review'};
    }
    final original = p.pixels;
    final tooltipBoxes = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_TooltipBox',
    );
    final tooltipMessages = find
        .descendant(of: tooltipBoxes, matching: find.byType(Text))
        .evaluate()
        .map((e) {
          final text = e.widget as Text;
          return text.data ?? text.textSpan?.toPlainText();
        })
        .toSet();
    final fixedTooltip =
        tooltipMessages.isNotEmpty &&
        find.byType(Tooltip).evaluate().any((e) {
          final tooltip = e.widget as Tooltip;
          return tooltipMessages.contains(
                tooltip.message ?? tooltip.richMessage?.toPlainText(),
              ) &&
              !hasAncestor(e, (ancestor) => identical(ancestor, element));
        });
    final preserveTooltip = tooltipBoxes.evaluate().isNotEmpty && !fixedTooltip;
    final render = element.findRenderObject();
    if (render is! RenderBox || !render.hasSize) {
      return {'status': 'missing-scroll-box'};
    }
    RenderObject? object = render;
    RenderObject? boundary;
    while (object != null) {
      if (object.isRepaintBoundary) boundary = object;
      object = object.parent;
    }
    if (boundary == null) return {'status': 'missing-root-boundary'};
    final origin = render.localToGlobal(Offset.zero, ancestor: boundary);
    var bounds = (origin & render.size).intersect(boundary.paintBounds);
    final originalBounds = bounds;
    if (bounds.height <= 0 || bounds.top < 0) {
      return {'status': 'unsupported-scroll-bounds'};
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final frames = <ui.Image>[];
    var written = 0.0;
    var top = 0.0;
    final offsets = <double>[];
    final frameBounds = <List<double>>[];
    // A scroll viewport can be clipped by the enclosing dialog's rounded
    // corners. Do not copy its bottom edge into the middle of a long image.
    // Overlapping interior strips retain the first top and the final bottom
    // exactly once, without painting over the real rendered corner pixels.
    var edgeGuard = bounds.height < 256 ? bounds.height / 4 : 64.0;
    final fixedOverlays = <List<double>>[];
    // A bottom-positioned button is painted over the scroll viewport, but is
    // not part of its document. Keep it only in the last frame; earlier strips
    // must stop above its measured bounds (including a small shadow margin).
    void measureFixedOverlays() {
      // Controls can appear only after the capture scrolls away from the end.
      // On a short viewport a large-text bottom button may occupy more than
      // the bottom quarter, so use its actual Positioned constraint.
      for (final candidate
          in find
              .byWidgetPredicate(
                (w) =>
                    w is Positioned ||
                    w is SnackBar ||
                    (fixedTooltip && w.runtimeType.toString() == '_TooltipBox'),
              )
              .evaluate()) {
        if (candidate.widget case final Positioned positioned) {
          if (positioned.bottom == null || positioned.top != null) continue;
          if (ModalRoute.of(candidate) != ModalRoute.of(element)) continue;
        } else {
          // Scaffold lays SnackBar out with a custom layout, not Positioned.
          // It remains fixed while the page scrolls and belongs in the last
          // strip only. A root dialog paints above it, so don't reserve space
          // for a background Scaffold's snackbar inside the dialog document.
          if (ModalRoute.of(element) is PopupRoute<dynamic>) continue;
        }
        var insideScrollable = false;
        candidate.visitAncestorElements((ancestor) {
          if (ancestor == element) insideScrollable = true;
          return true;
        });
        if (insideScrollable) continue;
        final overlay = candidate.findRenderObject();
        if (overlay is! RenderBox || !overlay.hasSize) continue;
        final rect =
            overlay.localToGlobal(Offset.zero, ancestor: boundary) &
            overlay.size;
        if (!rect.overlaps(bounds) || rect.top < bounds.top) continue;
        final guard = bounds.bottom - rect.top + 8;
        if (guard > edgeGuard) edgeGuard = guard;
        final measured = [rect.left, rect.top, rect.width, rect.height];
        if (!fixedOverlays.any((item) => listEquals(item, measured))) {
          fixedOverlays.add(measured);
        }
      }
    }

    Future<bool> moveTo(double target) async {
      // Streaming chat can have a queued post-frame "scroll to latest".
      // Observe the actual offset after layout and retry the requested scroll;
      // never label a bottom-only frame as a full document capture.
      for (var attempt = 0; attempt < 4; attempt++) {
        final requested = target.clamp(p.minScrollExtent, p.maxScrollExtent);
        p.jumpTo(requested);
        await binding.pump();
        if ((p.pixels - requested).abs() < .5) return true;
      }
      return false;
    }

    try {
      if (preserveTooltip) {
        // Programmatic jumpTo does not reliably dismiss a long-press tooltip.
        // Capture clean document strips, then restore the matched viewport once
        // below; otherwise the same tooltip is repeated at later scroll offsets.
        Tooltip.dismissAllToolTips();
        await binding.pump();
        await binding.pump(const Duration(milliseconds: 250));
        if (find
            .byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_TooltipBox',
            )
            .evaluate()
            .isNotEmpty) {
          return {'status': 'needs-tooltip-dismiss-review'};
        }
      }
      if (!await moveTo(p.minScrollExtent)) {
        return {'status': 'needs-auto-scroll-review'};
      }
      while (true) {
        // A scroll-triggered footer can shrink the viewport (for example the
        // large-text service timeline's "latest" button). Its pixels are not
        // document content. Measure each frame after layout instead of copying
        // the initial viewport rectangle through subsequent layouts.
        bounds =
            (render.localToGlobal(Offset.zero, ancestor: boundary) &
                    render.size)
                .intersect(boundary.paintBounds);
        if (bounds.top != originalBounds.top ||
            bounds.left != originalBounds.left ||
            bounds.width != originalBounds.width ||
            bounds.height <= 0) {
          return {'status': 'needs-changing-scroll-origin-review'};
        }
        measureFixedOverlays();
        if (edgeGuard >= bounds.height) {
          return {'status': 'needs-fixed-overlay-review'};
        }
        // Include the root RenderView, which is a repaint boundary but is not
        // a RenderRepaintBoundary widget. Capturing only the popup's layer
        // loses the real dimmed page and produces transparent outer regions.
        final layer = boundary.debugLayer;
        if (layer is! OffsetLayer) {
          return {'status': 'missing-root-offset-layer'};
        }
        final image = await layer.toImage(boundary.paintBounds, pixelRatio: 1);
        frames.add(image);
        final offset = p.pixels - p.minScrollExtent;
        offsets.add(offset);
        frameBounds.add([bounds.left, bounds.top, bounds.width, bounds.height]);
        if (frames.length == 1) {
          top = bounds.top;
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, image.width.toDouble(), top),
            Rect.fromLTWH(0, 0, image.width.toDouble(), top),
            Paint(),
          );
        }
        // Keep the full-width page strip; side padding remains exactly as rendered.
        final start = written > offset ? written - offset : 0.0;
        final atEnd = p.pixels >= p.maxScrollExtent - .5;
        final count = bounds.height - start - (atEnd ? 0 : edgeGuard);
        if (count > 0) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, bounds.top + start, image.width.toDouble(), count),
            Rect.fromLTWH(0, top + written, image.width.toDouble(), count),
            Paint(),
          );
          written += count;
        }
        if (atEnd) break;
        if (frames.length >= 400 || written > 40000) {
          return {
            'status': 'pagination-or-infinite-scroll',
            'offsets': offsets,
          };
        }
        // Whole-pixel hops avoid alternating half-pixel glyph rasterization
        // when a short viewport exposes only a few pixels per strip.
        final hop = ((bounds.height - edgeGuard) / 2).floorToDouble();
        if (!await moveTo(p.pixels + (hop < 1 ? 1 : hop))) {
          return {'status': 'needs-auto-scroll-review', 'offsets': offsets};
        }
      }
      final last = frames.last;
      if (preserveTooltip) {
        // Scrolling dismisses Tooltip. Restore the *actual matched viewport*
        // at its measured document offset, preserving the tooltip and its
        // anchor rather than silently outputting a different UI state.
        final codec = await ui.instantiateImageCodec(
          await viewportFile.readAsBytes(),
        );
        final matched = await codec.getNextFrame();
        codec.dispose();
        try {
          if (matched.image.width != last.width) {
            return {'status': 'needs-overlay-scale-review'};
          }
          canvas.drawImageRect(
            matched.image,
            Rect.fromLTWH(0, bounds.top, last.width.toDouble(), bounds.height),
            Rect.fromLTWH(
              0,
              top + original - p.minScrollExtent,
              last.width.toDouble(),
              bounds.height,
            ),
            Paint(),
          );
        } finally {
          matched.image.dispose();
        }
      }
      final bottom = last.height - bounds.bottom;
      canvas.drawImageRect(
        last,
        Rect.fromLTWH(0, bounds.bottom, last.width.toDouble(), bottom),
        Rect.fromLTWH(0, top + written, last.width.toDouble(), bottom),
        Paint(),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        last.width,
        (top + written + bottom).ceil(),
      );
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final name = viewportFile.path.replaceFirst(
        RegExp(r'\.png$'),
        '.long.png',
      );
      await File(name).writeAsBytes(bytes!.buffer.asUint8List());
      return {
        'status': 'complete-measured-scroll-stitch',
        'file': name,
        'offsets': offsets,
        'scroll_bounds': [bounds.left, bounds.top, bounds.width, bounds.height],
        'frame_scroll_bounds': frameBounds,
        'content_height': written,
        'interior_strip_edge_guard': edgeGuard,
        'fixed_bottom_overlay_bounds': fixedOverlays,
        'original_scroll_offset': original,
        'tooltip_preserved_from_matched_viewport': preserveTooltip,
        'fixed_tooltip_kept_in_final_frame': fixedTooltip,
        if (nestedEditableOnly) ...{
          'scope': 'page document; nested editable controls remain bounded',
          'nested_editable_scrolls': nestedEditables,
          'nested_editable_contents_expanded': false,
        },
      };
    } finally {
      for (final frame in frames) {
        frame.dispose();
      }
      if (position.mounted && p.hasContentDimensions) {
        p.jumpTo(original.clamp(p.minScrollExtent, p.maxScrollExtent));
        await binding.pump();
      }
    }
  }
}
