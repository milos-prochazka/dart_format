import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dart_format/SourceFile.dart';

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
  bool result = true;
  var fileName = args[0];
  var tabSize = 4;

  if (args.length >= 2) 
  {
    tabSize = int.tryParse(args[1]) ?? tabSize;
  }

  if (await FileSystemEntity.isFile(fileName)) 
  {
    result = await processFile(fileName, tabSize);
  } 
  else if (await FileSystemEntity.isDirectory(fileName)) 
  {
    Directory dir = Directory(fileName);

    await for (var file in dir.list(recursive: true, followLinks: false)) 
    {
      if (await FileSystemEntity.isFile(file.path) && file.path.endsWith('.dart')) 
      {
        processFile(file.path, tabSize);
        /*if (!await processFile(file.path, tabSize)) 
                {
                    break;
                }*/
      }
    }
  } 
  else 
  {
    print("file '$fileName' does not exist");
  }
}

Future<bool> processFile(String fileName, int tabSize) async 
{
  bool result = false;
  var src = SourceFile(fileName);

  print("The file '$fileName'");

  if (await src.copyTo(path.setExtension(fileName, '.bak'), newSource: false)) 
  {
    var res = await Process.run('dart.bat', ['format', fileName, '-l', '120']);
    if (res.exitCode == 0) 
    {
      result = (tabSize == 0) ||
          ((await src.read()) && (await src.parse()) && (await src.format(tabSize)) && (await src.write()));
    }
  }

  return result;
}
