import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:json_buddy/helper/global.dart';
import 'package:json_buddy/controller/line_number_controller.dart';
import 'package:json_buddy/widgets/syntax_error.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

class LineNumberTextField extends StatefulWidget {
  final TextEditingController textEditingController;
  final FormatException? currentError;
  final bool displayFilterView;
  final TextEditingController filteredTextEditingController;
  final VoidCallback userTextChangeCallback;
  const LineNumberTextField({
    required this.textEditingController,
    required this.filteredTextEditingController,
    required this.userTextChangeCallback,
    this.currentError,
    this.displayFilterView = false,
    Key? key,
  }) : super(key: key);

  @override
  State<LineNumberTextField> createState() => _LineNumberTextFieldState();
}

class _LineNumberTextFieldState extends State<LineNumberTextField> {
  static const _defaultFontFamily = 'monospace';
  static const _rootKey = 'root';
  static const _defaultFontColor = Color(0xff000000);
  static const _defaultBackgroundColor = Color(0xffffffff);

  LineNumberController? _lineNumberController;

  ScrollController? _scrollControllerLineNumbers;

  ScrollController? _scrollControllerJson;

  ScrollController? _scrollControllerJsonFiltered;

  LinkedScrollControllerGroup? _controllers;

  int? carretPositionInLine;
  int? carretLine;

  @override
  void initState() {
    super.initState();
    _lineNumberController = LineNumberController()..text = "";

    widget.textEditingController.addListener(() {
      _lineNumberController!.text = widget.textEditingController.text;
      final currentOffset = widget.textEditingController.selection.start;
      if (currentOffset < 0) {
        setState(() {
          carretLine = null;
          carretPositionInLine = null;
        });
      } else {
        final source = widget.textEditingController.text;
        int lineNum = 1;
        int lineStart = 0;
        bool previousCharWasCR = false;
        for (int i = 0; i < currentOffset; i++) {
          int char = source.codeUnitAt(i);
          if (char == 0x0a) {
            if (lineStart != i || !previousCharWasCR) {
              lineNum++;
            }
            lineStart = i + 1;
            previousCharWasCR = false;
          } else if (char == 0x0d) {
            lineNum++;
            lineStart = i + 1;
            previousCharWasCR = true;
          }
        }
        carretLine = lineNum;
        setState(() {
          if (lineNum > 1) {
            carretPositionInLine = currentOffset - lineStart + 1;
          } else {
            carretPositionInLine = currentOffset + 1;
          }
        });
      }
    });

    _controllers = LinkedScrollControllerGroup();

    _scrollControllerLineNumbers = _controllers?.addAndGet();
    _scrollControllerJson = _controllers?.addAndGet();
    _scrollControllerJsonFiltered = _controllers?.addAndGet();
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
      Widget codeField, double minWidth, String themeToUse) {
    const leftPad = 0.0;
    final longestLine = widget.textEditingController.text
        .split('\n')
        .fold<String>('', (p, e) => p.length < e.length ? e : p);
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0.0,
              minWidth: max(minWidth - leftPad, 0.0),
            ),
            child: Padding(
              child: Text(longestLine),
              padding: const EdgeInsets.only(right: 16.0),
            ), // Add extra padding
          ),
          Expanded(
              child: Container(
            color: themeMap[themeToUse]![_rootKey]?.backgroundColor ??
                _defaultBackgroundColor,
            child: codeField,
          )),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: leftPad),
      scrollDirection: Axis.horizontal,
      child: intrinsic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeToUse = prefs.getString(settingCodeTheme) ?? 'vs';
    final textStyle = TextStyle(
      fontFamily: _defaultFontFamily,
      color: themeMap[themeToUse]![_rootKey]?.color ?? _defaultFontColor,
    );
    final lineNumberCol = TextField(
      controller: _lineNumberController,
      enabled: false,
      maxLines: null,
      style: textStyle,
      scrollController: _scrollControllerLineNumbers,
      decoration: const InputDecoration(
        disabledBorder: InputBorder.none,
      ),
    );

    final jsonField = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Control horizontal scrolling
        return _wrapInScrollView(
          Stack(
            children: [
              TextField(
                controller: widget.textEditingController,
                scrollController: _scrollControllerJson,
                maxLines: null,
                style: textStyle,
                onChanged: (_) => widget.userTextChangeCallback(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
              ),
              if (carretLine != null && carretPositionInLine != null)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'L $carretLine C $carretPositionInLine',
                    style: themeMap[themeToUse]![_rootKey]!.copyWith(
                      fontSize: 10,
                    ),
                  ),
                )
            ],
          ),
          constraints.maxWidth,
          themeToUse,
        );
      },
    );

    final filteredField = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Control horizontal scrolling
        return _wrapInScrollView(
          TextField(
            readOnly: true,
            controller: widget.filteredTextEditingController,
            scrollController: _scrollControllerJsonFiltered,
            maxLines: null,
            style: textStyle,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
          ),
          constraints.maxWidth,
          themeToUse,
        );
      },
    );

    final contentChild = widget.displayFilterView
        ? Row(
            children: [
              Expanded(
                child: jsonField,
              ),
              Container(
                width: 5,
              ),
              Expanded(
                child: filteredField,
              ),
            ],
          )
        : jsonField;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          padding: const EdgeInsets.only(left: 3),
          child: lineNumberCol,
          height: double.infinity,
          decoration: BoxDecoration(
            color: themeMap[themeToUse]![_rootKey]?.backgroundColor ??
                _defaultBackgroundColor,
            border: const Border(
              right: BorderSide(),
            ),
          ),
        ),
        const SizedBox(
          width: 1,
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(child: contentChild),
              if (widget.currentError != null) SyntaxError(widget.currentError!)
            ],
          ),
        ),
      ],
    );
  }
}
