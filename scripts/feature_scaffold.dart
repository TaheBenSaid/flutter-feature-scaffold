import 'dart:io';

const _usage = '''
Usage: dart feature_scaffold.dart <feature_name> [--lite|--full|--upgrade] [--root lib] [--dry-run]

  --lite     day 1: repository, bloc and page
  --full     month 6: data, domain and presentation layers (default)
  --upgrade  turn an existing --lite feature into the --full layout
  --root     folder that holds features/ and core/ (default: lib)
  --dry-run  print what would happen, write nothing
''';

class Names {
  Names(this.snake)
    : pascal = snake.split('_').where((p) => p.isNotEmpty).map((p) => p[0].toUpperCase() + p.substring(1)).join(),
      title = snake.replaceAll('_', ' ').replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

  final String snake;
  final String pascal;
  final String title;
}

class Plan {
  Plan(this.root, this.dryRun);

  final String root;
  final bool dryRun;
  final created = <String>[];
  final skipped = <String>[];
  final changed = <String>[];
  final moved = <(String, String)>[];

  void write(String path, String content) {
    if (File(path).existsSync()) {
      skipped.add(path);
      return;
    }
    created.add(path);
    if (dryRun) return;
    File(path).parent.createSync(recursive: true);
    File(path).writeAsStringSync(content);
  }

  void move(String from, String to, String content) {
    moved.add((from, to));
    if (dryRun) return;
    File(to).parent.createSync(recursive: true);
    File(to).writeAsStringSync(content);
    File(from).deleteSync();
  }

  void update(String path, String content) {
    changed.add(path);
    if (!dryRun) File(path).writeAsStringSync(content);
  }
}

String _toSnake(String raw) => raw
    .trim()
    .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
    .replaceAll(RegExp(r'[\s-]+'), '_')
    .toLowerCase();

String _resultFile() => '''
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final Object error;
}
''';

String _event(Names n) =>
    '''
part of '${n.snake}_bloc.dart';

sealed class ${n.pascal}Event extends Equatable {
  const ${n.pascal}Event();

  @override
  List<Object?> get props => const [];
}

final class ${n.pascal}Requested extends ${n.pascal}Event {
  const ${n.pascal}Requested();
}
''';

String _state(Names n, String item) =>
    '''
part of '${n.snake}_bloc.dart';

sealed class ${n.pascal}State extends Equatable {
  const ${n.pascal}State();

  @override
  List<Object?> get props => const [];
}

final class ${n.pascal}Initial extends ${n.pascal}State {
  const ${n.pascal}Initial();
}

final class ${n.pascal}Loading extends ${n.pascal}State {
  const ${n.pascal}Loading();
}

final class ${n.pascal}Success extends ${n.pascal}State {
  const ${n.pascal}Success(this.items);

  final List<$item> items;

  @override
  List<Object?> get props => [items];
}

final class ${n.pascal}Empty extends ${n.pascal}State {
  const ${n.pascal}Empty();
}

final class ${n.pascal}Failure extends ${n.pascal}State {
  const ${n.pascal}Failure();
}
''';

String _view(Names n, String success) =>
    '''
class _${n.pascal}View extends StatelessWidget {
  const _${n.pascal}View();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('${n.title}')),
      body: BlocBuilder<${n.pascal}Bloc, ${n.pascal}State>(
        builder: (context, state) => switch (state) {
          ${n.pascal}Initial() || ${n.pascal}Loading() => const Center(
            child: CircularProgressIndicator(),
          ),
          ${n.pascal}Empty() => const Center(child: Text('Nothing here yet')),
          ${n.pascal}Failure() => Center(
            child: TextButton(
              onPressed: () =>
                  context.read<${n.pascal}Bloc>().add(const ${n.pascal}Requested()),
              child: const Text('Something went wrong. Try again'),
            ),
          ),
          ${n.pascal}Success(:final items) => $success,
        },
      ),
    );
  }
}
''';

Map<String, String> _lite(Names n) => {
  'data/${n.snake}_repository.dart':
      '''
class ${n.pascal}Repository {
  const ${n.pascal}Repository();

  Future<List<String>> fetch${n.pascal}() async => const [];
}
''',
  'presentation/bloc/${n.snake}_bloc.dart':
      '''
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/${n.snake}_repository.dart';

part '${n.snake}_event.dart';
part '${n.snake}_state.dart';

class ${n.pascal}Bloc extends Bloc<${n.pascal}Event, ${n.pascal}State> {
  ${n.pascal}Bloc(this._repository) : super(const ${n.pascal}Initial()) {
    on<${n.pascal}Requested>(_onRequested);
  }

  final ${n.pascal}Repository _repository;

  Future<void> _onRequested(
    ${n.pascal}Requested event,
    Emitter<${n.pascal}State> emit,
  ) async {
    emit(const ${n.pascal}Loading());
    try {
      final items = await _repository.fetch${n.pascal}();
      emit(items.isEmpty ? const ${n.pascal}Empty() : ${n.pascal}Success(items));
    } on Exception {
      emit(const ${n.pascal}Failure());
    }
  }
}
''',
  'presentation/bloc/${n.snake}_event.dart': _event(n),
  'presentation/bloc/${n.snake}_state.dart': _state(n, 'String'),
  'presentation/pages/${n.snake}_page.dart':
      '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/${n.snake}_repository.dart';
import '../bloc/${n.snake}_bloc.dart';

class ${n.pascal}Page extends StatelessWidget {
  const ${n.pascal}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ${n.pascal}Bloc(const ${n.pascal}Repository())..add(const ${n.pascal}Requested()),
      child: const _${n.pascal}View(),
    );
  }
}

${_view(n, '''ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => ListTile(title: Text(items[i])),
          )''')}''',
};

Map<String, String> _full(Names n) => {
  'domain/entities/${n.snake}_entity.dart':
      '''
import 'package:equatable/equatable.dart';

class ${n.pascal}Entity extends Equatable {
  const ${n.pascal}Entity({required this.id, required this.title});

  final String id;
  final String title;

  @override
  List<Object?> get props => [id, title];
}
''',
  'domain/repositories/${n.snake}_repository.dart':
      '''
import '../../../../core/result.dart';
import '../entities/${n.snake}_entity.dart';

abstract interface class ${n.pascal}Repository {
  Future<Result<List<${n.pascal}Entity>>> get${n.pascal}();
}
''',
  'domain/usecases/get_${n.snake}.dart':
      '''
import '../../../../core/result.dart';
import '../entities/${n.snake}_entity.dart';
import '../repositories/${n.snake}_repository.dart';

class Get${n.pascal} {
  const Get${n.pascal}(this._repository);

  final ${n.pascal}Repository _repository;

  Future<Result<List<${n.pascal}Entity>>> call() => _repository.get${n.pascal}();
}
''',
  'data/models/${n.snake}_model.dart':
      '''
import '../../domain/entities/${n.snake}_entity.dart';

class ${n.pascal}Model {
  const ${n.pascal}Model({required this.id, required this.title});

  factory ${n.pascal}Model.fromJson(Map<String, dynamic> json) => ${n.pascal}Model(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
      );

  final String id;
  final String title;

  ${n.pascal}Entity toEntity() => ${n.pascal}Entity(id: id, title: title);
}
''',
  'data/datasources/${n.snake}_remote_data_source.dart':
      '''
import '../models/${n.snake}_model.dart';

class ${n.pascal}RemoteDataSource {
  const ${n.pascal}RemoteDataSource();

  Future<List<${n.pascal}Model>> fetch${n.pascal}() async => const [];
}
''',
  'data/repositories/${n.snake}_repository_impl.dart':
      '''
import '../../../../core/result.dart';
import '../../domain/entities/${n.snake}_entity.dart';
import '../../domain/repositories/${n.snake}_repository.dart';
import '../datasources/${n.snake}_remote_data_source.dart';

class ${n.pascal}RepositoryImpl implements ${n.pascal}Repository {
  const ${n.pascal}RepositoryImpl(this._remote);

  final ${n.pascal}RemoteDataSource _remote;

  @override
  Future<Result<List<${n.pascal}Entity>>> get${n.pascal}() async {
    try {
      final models = await _remote.fetch${n.pascal}();
      return Success([for (final m in models) m.toEntity()]);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
}
''',
  'presentation/bloc/${n.snake}_bloc.dart':
      '''
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result.dart';
import '../../domain/entities/${n.snake}_entity.dart';
import '../../domain/usecases/get_${n.snake}.dart';

part '${n.snake}_event.dart';
part '${n.snake}_state.dart';

class ${n.pascal}Bloc extends Bloc<${n.pascal}Event, ${n.pascal}State> {
  ${n.pascal}Bloc(this._get${n.pascal}) : super(const ${n.pascal}Initial()) {
    on<${n.pascal}Requested>(_onRequested);
  }

  final Get${n.pascal} _get${n.pascal};

  Future<void> _onRequested(
    ${n.pascal}Requested event,
    Emitter<${n.pascal}State> emit,
  ) async {
    emit(const ${n.pascal}Loading());
    switch (await _get${n.pascal}()) {
      case Success(:final value) when value.isEmpty:
        emit(const ${n.pascal}Empty());
      case Success(:final value):
        emit(${n.pascal}Success(value));
      case Failure():
        emit(const ${n.pascal}Failure());
    }
  }
}
''',
  'presentation/bloc/${n.snake}_event.dart': _event(n),
  'presentation/bloc/${n.snake}_state.dart': _state(n, '${n.pascal}Entity'),
  'presentation/widgets/${n.snake}_list.dart':
      '''
import 'package:flutter/material.dart';

import '../../domain/entities/${n.snake}_entity.dart';

class ${n.pascal}List extends StatelessWidget {
  const ${n.pascal}List({super.key, required this.items});

  final List<${n.pascal}Entity> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) => ListTile(title: Text(items[i].title)),
    );
  }
}
''',
  'presentation/pages/${n.snake}_page.dart':
      '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/${n.snake}_remote_data_source.dart';
import '../../data/repositories/${n.snake}_repository_impl.dart';
import '../../domain/usecases/get_${n.snake}.dart';
import '../bloc/${n.snake}_bloc.dart';
import '../widgets/${n.snake}_list.dart';

class ${n.pascal}Page extends StatelessWidget {
  const ${n.pascal}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ${n.pascal}Bloc(
        const Get${n.pascal}(${n.pascal}RepositoryImpl(${n.pascal}RemoteDataSource())),
      )..add(const ${n.pascal}Requested()),
      child: const _${n.pascal}View(),
    );
  }
}

${_view(n, '${n.pascal}List(items: items)')}''',
};

String _mask(String s) {
  final b = StringBuffer();
  var i = 0;
  while (i < s.length) {
    if (s.startsWith('//', i)) {
      final end = s.indexOf('\n', i);
      final stop = end == -1 ? s.length : end;
      b.write(' ' * (stop - i));
      i = stop;
    } else if (s.startsWith('/*', i)) {
      final end = s.indexOf('*/', i + 2);
      final stop = end == -1 ? s.length : end + 2;
      b.write(s.substring(i, stop).replaceAll(RegExp(r'[^\n]'), ' '));
      i = stop;
    } else if (s[i] == "'" || s[i] == '"') {
      final q = s.startsWith("'''", i) || s.startsWith('"""', i) ? s.substring(i, i + 3) : s[i];
      var j = i + q.length;
      while (j < s.length && !s.startsWith(q, j)) {
        if (s[j] == '\\') j++;
        j++;
      }
      final stop = (j + q.length).clamp(0, s.length);
      b.write(q);
      b.write(s.substring(i + q.length, j.clamp(0, s.length)).replaceAll(RegExp(r'[^\n]'), ' '));
      if (stop > j) b.write(q);
      i = stop;
    } else {
      b.write(s[i]);
      i++;
    }
  }
  return b.toString();
}

int _close(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return code.length - 1;
}

class Member {
  Member(this.start, this.signature, this.name, this.params, this.returnType);

  final int start;
  final String signature;
  final String name;
  final String params;
  final String returnType;
}

List<Member> _publicMethods(String text, String code, int bodyOpen, int bodyClose, String className) {
  final members = <Member>[];
  var i = bodyOpen + 1;
  while (i < bodyClose) {
    while (i < bodyClose && code[i].trim().isEmpty) {
      i++;
    }
    if (i >= bodyClose) break;
    final start = i;
    var end = i;
    var depth = 0;
    while (end < bodyClose) {
      final c = code[end];
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') {
        depth--;
        if (depth == 0 && c == '}' && !RegExp(r'^\s*[;,).]').hasMatch(code.substring(end + 1, bodyClose))) break;
      }
      if (depth == 0 && c == ';') break;
      end++;
    }
    final member = code.substring(start, end + 1);
    i = end + 1;

    final head = member.replaceFirst(RegExp(r'^(\s*@\w+(\([^)]*\))?\s*)+'), '');
    final headStart = start + member.length - head.length;
    if (RegExp(r'^(static|factory|const|final|var|late|external|set)\b').hasMatch(head)) continue;

    final getter = RegExp(r'^(.*?)\bget\s+([a-zA-Z]\w*)').firstMatch(head);
    final paren = head.indexOf('(');
    final arrow = head.indexOf(RegExp(r'=>|\{|='));
    if (getter != null && (paren == -1 || getter.end < paren)) {
      final returnType = getter[1]!.trim();
      members.add(Member(headStart, text.substring(headStart, headStart + getter.end), getter[2]!, '', returnType));
      continue;
    }
    if (paren == -1 || (arrow != -1 && arrow < paren)) continue;
    final name = RegExp(r'([A-Za-z_]\w*)\s*(<[^()]*>)?\s*$').firstMatch(head.substring(0, paren))?[1];
    if (name == null || name.startsWith('_') || name == className || name == 'operator') continue;
    final close = _close(code, headStart + paren);
    final signature = text.substring(headStart, close + 1);
    final returnType = head.substring(0, paren).replaceFirst(RegExp(r'([A-Za-z_]\w*)\s*(<[^()]*>)?\s*$'), '').trim();
    members.add(Member(headStart, signature, name, text.substring(headStart + paren + 1, close), returnType));
  }
  return members;
}

String _forward(String params) {
  final args = <String>[];
  var named = false;
  var depth = 0;
  var current = StringBuffer();
  void flush() {
    final p = current.toString().split('=').first.trim();
    current = StringBuffer();
    if (p.isEmpty) return;
    final name = RegExp(r'([A-Za-z_]\w*)\s*$').firstMatch(p)?[1];
    if (name != null) args.add(named ? '$name: $name' : name);
  }

  for (final c in params.split('')) {
    if ((c == '{' || c == '[') && depth == 0) {
      flush();
      named = c == '{';
      continue;
    }
    if ((c == '}' || c == ']') && depth == 0) continue;
    if (c == '(' || c == '<') depth++;
    if (c == ')' || c == '>') depth--;
    if (c == ',' && depth == 0) {
      flush();
      continue;
    }
    current.write(c);
  }
  flush();
  return args.join(', ');
}

String _relative(String fromDir, String toFile) {
  final from = Directory(fromDir).absolute.uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final to = File(toFile).absolute.uri.pathSegments.where((s) => s.isNotEmpty).toList();
  var common = 0;
  while (common < from.length && common < to.length - 1 && from[common] == to[common]) {
    common++;
  }
  return [for (var i = common; i < from.length; i++) '..', ...to.sublist(common)].join('/');
}

String _normalize(String path) => File(path).absolute.uri.normalizePath().toFilePath();

({String dir, String name})? _package(String root) {
  var dir = Directory(root).absolute;
  for (var i = 0; i < 6; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final name = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec.readAsStringSync())?[1];
      return name == null ? null : (dir: dir.path, name: name);
    }
    dir = dir.parent;
  }
  return null;
}

final _import = RegExp(r'''^import\s+(['"])([^'"]+)\1([^;]*);[ \t]*\n?''', multiLine: true);

String? _resolve(String uri, String fileDir, ({String dir, String name})? pkg) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    if (pkg == null || !uri.startsWith('package:${pkg.name}/')) return null;
    return _normalize('${pkg.dir}/lib/${uri.substring('package:${pkg.name}/'.length)}');
  }
  return _normalize(Directory(fileDir).absolute.uri.resolve(uri).toFilePath());
}

String _uriFor(String target, String fromDir, bool packageStyle, ({String dir, String name})? pkg) {
  final lib = _normalize('${pkg?.dir}/lib/');
  if (packageStyle && pkg != null && target.startsWith(lib)) {
    return 'package:${pkg.name}/${target.substring(lib.length)}';
  }
  return _relative(fromDir, target);
}

void _upgrade(Names n, String feature, Plan plan) {
  final old = '$feature/data/${n.snake}_repository.dart';
  final impl = '$feature/data/repositories/${n.snake}_repository_impl.dart';
  final contract = '$feature/domain/repositories/${n.snake}_repository.dart';
  final useCase = '$feature/domain/usecases/get_${n.snake}.dart';
  final result = '${plan.root}/core/result.dart';

  if (!File(old).existsSync()) {
    stderr.writeln('No lite feature here: $old is missing.');
    exitCode = 1;
    return;
  }
  final taken = [impl, contract, useCase].where((p) => File(p).existsSync()).toList();
  if (taken.isNotEmpty) {
    stderr.writeln('Refusing to upgrade, these files already exist:');
    for (final p in taken) {
      stderr.writeln('  $p');
    }
    exitCode = 1;
    return;
  }

  final text = File(old).readAsStringSync();
  final code = _mask(text);
  final cls = RegExp('\\bclass\\s+${n.pascal}Repository\\b[^{]*\\{').firstMatch(code);
  if (cls == null) {
    stderr.writeln('Could not find class ${n.pascal}Repository in $old.');
    exitCode = 1;
    return;
  }
  final bodyClose = _close(code, cls.end - 1);
  final methods = _publicMethods(text, code, cls.end - 1, bodyClose, '${n.pascal}Repository');
  final pkg = _package(plan.root);

  // Insert from the bottom up so earlier offsets stay valid.
  var moved = text;
  for (final m in methods.reversed) {
    final before = moved.substring(0, m.start);
    if (RegExp(r'@override\s*$').hasMatch(before)) continue;
    final indent = RegExp(r'[ \t]*$').firstMatch(before)![0]!;
    moved = '$before@override\n$indent${moved.substring(m.start)}';
  }
  final header = RegExp('\\bclass\\s+${n.pascal}Repository\\b').firstMatch(moved)!;
  final brace = moved.indexOf('{', header.end);
  final clause = moved.substring(header.end, brace).trimRight();
  final implements = clause.contains(RegExp(r'\bimplements\b'))
      ? clause.replaceFirst(RegExp(r'\bimplements\b'), 'implements ${n.pascal}Repository,')
      : '$clause implements ${n.pascal}Repository';
  moved = '${moved.substring(0, header.start)}class ${n.pascal}RepositoryImpl$implements ${moved.substring(brace)}';
  moved = moved.replaceAllMapped(RegExp('\\b${n.pascal}Repository(?=\\s*\\()'), (_) => '${n.pascal}RepositoryImpl');

  final oldDir = File(old).parent.path;
  final implDir = File(impl).parent.path;
  final imports = StringBuffer();
  moved = moved.replaceAllMapped(_import, (m) {
    final target = _resolve(m[2]!, oldDir, pkg);
    final uri = target == null || m[2]!.startsWith('package:') ? m[2]! : _relative(implDir, target);
    return 'import ${m[1]}$uri${m[1]}${m[3]};\n';
  });
  imports.writeln("import '../../domain/repositories/${n.snake}_repository.dart';");
  final lastImport = _import.allMatches(moved).lastOrNull;
  if (lastImport == null) {
    moved = '$imports\n$moved';
  } else {
    final gap = lastImport[2]!.startsWith('.') ? '' : '\n';
    moved = moved.replaceRange(lastImport.end, lastImport.end, '$gap$imports');
  }

  // Only the app's own imports can hold the types in the signatures. Copying
  // http or dio here would just leave unused imports behind.
  final contractImports = _import.allMatches(text).where((m) => _resolve(m[2]!, oldDir, pkg) != null).map((m) {
    final target = _resolve(m[2]!, oldDir, pkg)!;
    final uri = m[2]!.startsWith('package:') ? m[2]! : _relative(File(contract).parent.path, target);
    return 'import ${m[1]}$uri${m[1]}${m[3]};\n';
  }).join();
  final contractBody = methods.map((m) => '  ${m.signature.trim()};\n').join('\n');
  plan.write(contract, '''
${contractImports.isEmpty ? '' : '$contractImports\n'}abstract interface class ${n.pascal}Repository {
$contractBody}
''');

  if (methods.isNotEmpty) {
    final m = methods.first;
    final future = RegExp(r'^Future<(.+)>$').firstMatch(m.returnType);
    final call = m.params.isEmpty && !m.signature.contains('(')
        ? '_repository.${m.name}'
        : '_repository.${m.name}(${_forward(m.params)})';
    final params = m.signature.contains('(') ? '(${m.params})' : '()';
    final body = future == null
        ? '  ${m.returnType} call$params => $call;\n'
        : '''
  Future<Result<${future[1]}>> call$params async {
    try {
      return Success(await $call);
    } on Exception catch (e) {
      return Failure(e);
    }
  }
''';
    if (future != null) plan.write(result, _resultFile());
    plan.write(useCase, '''
${future == null ? '' : "import '../../../../core/result.dart';\n"}${contractImports.isEmpty ? '' : contractImports}import '../repositories/${n.snake}_repository.dart';

class Get${n.pascal} {
  const Get${n.pascal}(this._repository);

  final ${n.pascal}Repository _repository;

$body}
''');
  }

  plan.move(old, impl, moved);

  final oldPath = _normalize(old);
  final files = Directory(plan.root).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final f in files) {
    if (_normalize(f.path) == oldPath) continue;
    final src = f.readAsStringSync();
    final hit = _import.allMatches(src).where((m) => _resolve(m[2]!, f.parent.path, pkg) == oldPath).firstOrNull;
    if (hit == null) continue;

    final masked = _mask(src);
    var out = src;
    for (final m in RegExp('\\b${n.pascal}Repository(?=\\s*\\()').allMatches(masked).toList().reversed) {
      out = out.replaceRange(m.start, m.end, '${n.pascal}RepositoryImpl');
    }
    final after = _mask(out);
    final style = hit[2]!.startsWith('package:');
    final lines = [
      if (RegExp('\\b${n.pascal}Repository\\b').hasMatch(after))
        _uriFor(_normalize(contract), f.parent.path, style, pkg),
      if (after.contains('${n.pascal}RepositoryImpl')) _uriFor(_normalize(impl), f.parent.path, style, pkg),
    ].map((u) => 'import ${hit[1]}$u${hit[1]};\n').join();
    final at = out.indexOf(hit[0]!);
    out = out.replaceRange(at, at + hit[0]!.length, lines);
    plan.update(f.path, out);
  }
}

void main(List<String> args) {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    stdout.write(_usage);
    return;
  }
  final rootAt = args.indexOf('--root');
  final root = rootAt != -1 && rootAt + 1 < args.length ? args[rootAt + 1] : 'lib';
  final rest = [
    for (var i = 0; i < args.length; i++)
      if (i != rootAt && i != rootAt + 1 || rootAt == -1) args[i],
  ];
  final flags = rest.where((a) => a.startsWith('--')).toSet();
  final names = rest.where((a) => !a.startsWith('--')).toList();
  final unknown = flags.difference({'--lite', '--full', '--upgrade', '--dry-run'});
  final modes = flags.intersection({'--lite', '--full', '--upgrade'});
  if (names.length != 1 || unknown.isNotEmpty || modes.length > 1) {
    stderr.write(_usage);
    exitCode = 2;
    return;
  }

  final snake = _toSnake(names.single);
  if (!RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$').hasMatch(snake)) {
    stderr.writeln("Can't turn '${names.single}' into a snake_case feature name.");
    exitCode = 2;
    return;
  }
  if (!Directory(root).existsSync()) {
    stderr.writeln('No such folder: $root');
    exitCode = 2;
    return;
  }

  final n = Names(snake);
  final mode = modes.isEmpty ? '--full' : modes.single;
  final dryRun = flags.contains('--dry-run');
  final feature = '$root/features/${n.snake}';
  final plan = Plan(root, dryRun);

  stdout.writeln('Feature scaffold: ${n.snake} (${mode.substring(2)})${dryRun ? ', dry run' : ''}');

  if (mode == '--upgrade') {
    _upgrade(n, feature, plan);
    if (exitCode != 0) return;
  } else {
    if (mode == '--full' && File('$feature/data/${n.snake}_repository.dart').existsSync()) {
      stderr.writeln('$feature is a lite feature. Use --upgrade to grow it into the full layout.');
      exitCode = 1;
      return;
    }
    if (mode == '--full') plan.write('$root/core/result.dart', _resultFile());
    final files = mode == '--lite' ? _lite(n) : _full(n);
    files.forEach((path, content) => plan.write('$feature/$path', content));
  }

  // Line breaks depend on the feature name length, so let the formatter settle
  // them. The moved repository isn't in this list, so the user's code keeps its
  // own formatting.
  if (!dryRun && plan.created.isNotEmpty) {
    try {
      Process.runSync(Platform.resolvedExecutable, ['format', ...plan.created]);
    } on ProcessException {
      stderr.writeln('Could not run dart format, the files are unformatted.');
    }
  }

  final verb = dryRun ? 'would ' : '';
  for (final p in plan.created) {
    stdout.writeln('  ${verb}create  $p');
  }
  for (final (from, to) in plan.moved) {
    stdout.writeln('  ${verb}move    $from  ->  $to');
  }
  for (final p in plan.changed) {
    stdout.writeln('  ${verb}update  $p');
  }
  for (final p in plan.skipped) {
    stdout.writeln('  skip    $p (already exists)');
  }

  if (mode == '--upgrade') {
    stdout.writeln(
      '\nThe bloc now depends on the ${n.pascal}Repository contract. '
      'Switch it to Get${n.pascal} when you want the Result type end to end.',
    );
  } else if (plan.created.isNotEmpty) {
    stdout.writeln('\nNeeds flutter_bloc and equatable. Add ${n.pascal}Page to your router, then run flutter analyze.');
  }
}
