import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dart_format/SourceFile.dart';
import 'package:tuple/tuple.dart';

void command(List<String> args)
{
  if (args.isEmpty)
  {
    print('Syntax: dart_format <file or directory> [size of tabulator]');
  }
  else
  {
    _main(args);
  }
}

Future<bool> renameFile(String oldPath, String newPath) async
{
  bool result = false;

  try
  {
    var oldFile = File(oldPath);
    await oldFile.rename(newPath);
    result = true;
  }
  catch (e)
  {
    print(e);
  }

  return result;
}

void _main(List<String> args) async
{
  var fileName = args[0];
  var tabSize = 4;

  if (args.length >= 2)
  {
    tabSize = int.tryParse(args[1]) ?? tabSize;
  }

  if (await FileSystemEntity.isFile(fileName))
  {
    _showResult(await processFile(fileName, tabSize));
  }
  else if (await FileSystemEntity.isDirectory(fileName))
  {
    Directory dir = Directory(fileName);

    var futures = <Future<Tuple2<bool,String>>>[];

    await for (var file in dir.list(recursive: true, followLinks: false))
    {
      if (await FileSystemEntity.isFile(file.path) && file.path.endsWith('.dart'))
      {
        futures.add(processFile(file.path, tabSize));
      }
    }

    var results = <Tuple2<bool,String>>[];

    for (var future in futures)
    {
        results.add(await future);
    }

    for (var result in results)
    {
        _showResult(result);
    }
  }
  else
  {
    print("File '$fileName' does not exist");
  }
}

void _showResult(Tuple2<bool,String> result)
{
    print("The file '${result.item2}' ${result.item1?'OK':'ERROR'}");
}

Future<Tuple2<bool,String>> processFile(String fileName, int tabSize) async
{
  bool result= false;

  final ccc = '${'''aaa'''}';

  final tmpName = path.setExtension(fileName, r'.$$$');
  final backupName = path.setExtension(fileName, r'.bak');
  final tmp = SourceFile(tmpName);

  var src = SourceFile(fileName);

  print("Load file '$fileName'");

  if (await src.copyTo(tmpName, newSource: false))
  {
    var res = await Process.run('dart.bat', ['format', tmpName, '-l', '120']);
    if (res.exitCode == 0)
    {
      tmp.tabSize = tabSize;
      result = (tabSize == 0) ||
          ((await tmp.read()) && (await tmp.parse()) && (await tmp.format()) && (await tmp.write()));

      if (result && ! await tmp.identicalFile(fileName))
      {

        result = await src.renameTo(backupName,newSource: false) &&
                 await tmp.renameTo(fileName,newSource: false);
      }
      else
      {
        await tmp.deleteFile();
      }
    }
  }

/*
  if (await src.copyTo(path.setExtension(fileName, '.bak'), newSource: false))
  {
    var res = await Process.run('dart.bat', ['format', fileName, '-l', '120']);
    if (res.exitCode == 0)
    {
      result = (tabSize == 0) ||
          ((await src.read()) && (await src.parse()) && (await src.format(tabSize)) && (await src.write()));
    }
  }


*/
  return Tuple2<bool,String>(result,fileName);
}