# dart-format

Program for formatting source files in DART. The program performs pre-formatting using Dart. This is so that the folder where DART is located is in PATH.

Reformats the standard format:
```dart
if (isTrue){
  call(something);
}
```

On the format :
```dart
if (isTrue)
{
  call(something);
}
```

The parameter can be used to specify the size of the indentation (in steps of 2 spaces).

**Syntax:**
dart-format <source> [tab-size]

  * <source> - Input file or folder. If a folder is specified, it is scanned, and formatting is performed on all files with a .dart extension. Folder searches are performed recursively, and dart files are also searched in nested folders.

  * [tab-size] - indent size.  If 0 is specified, only formatting with DART is performed. The default is 4.

*Processing a macro in a source file*

  * //#set-tab-size - Change the indent size. Valid from the command to the end of the file, or to the next change. A range of 2 to 10 can be specified.

  * //#pop-tab - Restore the indent size set by //#set-tab size

