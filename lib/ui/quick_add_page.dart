import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course.dart';
import '../data/storage.dart';
import '../data/study_item.dart';
import '../services/speech_recognition_service.dart';
import '../services/study_text_parser.dart';
import '../state/schedule_providers.dart';
import 'study_item_editor_page.dart';

Future<void> showStudyAddMenu(
  BuildContext context, {
  StudyItemKind? kind,
}) async {
  if (kind != null) {
    await Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => StudyItemEditorPage(kind: kind)));
    return;
  }
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: const Text('添加内容'),
      message: const Text('可以填写表单，也可以用文字或语音快速创建'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(sheetContext);
            Navigator.of(
              context,
            ).push(CupertinoPageRoute(builder: (_) => const QuickAddPage()));
          },
          child: const Text('文字或语音输入'),
        ),
        for (final entry in const [
          (StudyItemKind.assignment, '添加作业'),
          (StudyItemKind.exam, '添加考试'),
          (StudyItemKind.personal, '添加个人待办'),
        ])
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => StudyItemEditorPage(kind: entry.$1),
                ),
              );
            },
            child: Text(entry.$2),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: const Text('取消'),
      ),
    ),
  );
}

class QuickAddPage extends ConsumerStatefulWidget {
  const QuickAddPage({super.key});
  @override
  ConsumerState<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends ConsumerState<QuickAddPage> {
  final _text = TextEditingController();
  bool _listening = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _recognize() async {
    setState(() {
      _listening = true;
      _error = null;
    });
    try {
      final result = await SpeechRecognitionService.recognize();
      if (mounted && result.isNotEmpty) setState(() => _text.text = result);
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'unsupported') {
        await showCupertinoDialog<void>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('语音输入'),
            content: const Text('安卓端语音输入功能尚未准备好，请先使用文字输入。'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else {
        setState(() => _error = e.message ?? '无法使用语音识别');
      }
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  void _parse() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请先输入一句话');
      return;
    }
    final courses = ref.read(coursesProvider).asData?.value ?? const <Course>[];
    final defaultHour =
        AppStorage.settings.get('study_default_due_hour', defaultValue: 22)
            as int;
    final result = StudyTextParser.parse(
      text,
      courses: courses,
      defaultHour: defaultHour,
    );
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) =>
            StudyItemEditorPage(kind: result.item.kind, draft: result.item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: const CupertinoNavigationBar(middle: Text('快速添加')),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '说出或输入一件事',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '例如“周五晚上十点交高频电子技术作业”或“下周三两点在一教考试”',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          CupertinoTextField(
            controller: _text,
            minLines: 4,
            maxLines: 7,
            autofocus: true,
            placeholder: '输入作业、考试或待办…',
            padding: const EdgeInsets.all(16),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: _listening
                ? () => SpeechRecognitionService.stop()
                : _recognize,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _listening ? CupertinoIcons.stop_circle : CupertinoIcons.mic,
                ),
                const SizedBox(width: 8),
                Text(_listening ? '正在聆听，点此停止' : '使用系统语音识别'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CupertinoButton(onPressed: _parse, child: const Text('解析并确认')),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: CupertinoColors.systemRed),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '识别和解析完成后会打开确认表单，不会直接保存。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    ),
  );
}
