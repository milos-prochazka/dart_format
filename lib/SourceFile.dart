import 'dart:io';
import 'dart:convert';
import 'dart:async';

class SourceFile
{
  String _fileName;
  final _chars = _Character(_Character.$eof);
  static final codec = Utf8Codec(allowMalformed: true);
  _Character _aChar = _Character(_Character.$eof);
  int _aColumn = 0;
  int _aLevel = 0;

  int tabSize = 0;
  int _aTabSize = 0;
  var _tabSizeStack = <int>[];

  SourceFile(this._fileName) {}

  Future<bool> read() async
  {
    var result = false;

    try
    {
      final file = File(_fileName);
      final bytes = await file.readAsBytes();
      final codes = codec.decode(bytes);

      for (var i = 0; i < codes.length; i++)
      {
        _chars.addPrev(_Character(codes.codeUnitAt(i)));
      }

      reset();
      result = true;
    }
    catch (e, s)
    {
      print('${e.toString()}\r\n${s.toString()}');
    }

    return result;
  }

  Future<bool> write() async
  {
    var result = false;

    try
    {
      final file = File(_fileName);

      await file.writeAsString(this.toString());

      result = true;
    }
    catch (e, s)
    {
      print('${e.toString()}\r\n${s.toString()}');
    }

    return result;
  }

  Future<bool> deleteFile() async
  {
    var result = false;

    try
    {
      final file = File(_fileName);

      await file.delete();

      result = true;
    }
    catch (e, s)
    {
      print('${e.toString()}\r\n${s.toString()}');
    }

    return result;
  }

  Future<bool> identicalFile(String anotherFile) async
  {
    var result = true;

    try
    {
      final file = File(anotherFile);

      var anotherText = await file.readAsString();

      result = anotherText == this.toString();
    }
    catch (e, s)
    {
      print('${e.toString()}\r\n${s.toString()}');
    }

    return result;

  }

  Future<bool> copyTo(String destFile, {bool newSource = true}) async
  {
    bool result = false;

    try
    {
      var file = File(_fileName);

      await file.copy(destFile);

      if (newSource)
      {
        _fileName = destFile;
      }

      result = true;
    }
    catch (e, s)
    {
      print('$e\r\n$s');
    }

    return result;
  }

  Future<bool> renameTo(String destFile, {bool newSource = true}) async
  {
    bool result = false;

    try
    {
      var file = File(_fileName);

      await file.rename(destFile);

      if (newSource)
      {
        _fileName = destFile;
      }

      result = true;
    }
    catch (e, s)
    {
      print('$e\r\n$s');
    }

    return result;
  }

  @override
  String toString()
  {
    var char = _chars.next;
    var buffer = new StringBuffer();

    while (char.charType != _CharacterType.Eof)
    {
      buffer.writeCharCode(char.code);
      char = char.next;
    }

    return buffer.toString().trim();
  }

  bool parse()
  {
    var result = false;

    reset();
    columns();

    reset();
    result = _parseInternal();

    return result;
  }

  bool format()
  {
    reset();

    while (_aChar.charType != _CharacterType.Eof)
    {
      if (_aChar.charType == _CharacterType.Normal)
      {
        if (_aChar.isOpenBrace() && _aChar.lastOnLine())
        {
          var close = _aChar.findLevelClose();

          if (close == null)
          {
            return false;
          }

          if (close.column < _aChar.column)
          {
            if (_aChar.firstOnLine())
            {
              for (var cnt = _aChar.column - close.column; cnt > 0; cnt--)
              {
                _aChar.prev.remove();
              }
            }
            else
            {
              _aChar.prev.insertString('\r\n');
              _aChar.prev.insertSpaces(close.column);
            }
          }
        }
      }

      _next();
    }

    columns();
    reset();

    while (_aChar.charType != _CharacterType.Eof)
    {
      _breakPatternAmongBraces(['else', 'catch', 'while', 'finally']);
      _nextLine();
    }

    if (tabSize > 2)
    {
      columns();
      reset();

      while (_aChar.charType != _CharacterType.Eof)
      {
        var char = _aChar.skipSpace();
        if (char.charType == _CharacterType.Normal ||
            (char.charType == _CharacterType.Comment && char.isLineComment()))
        {
          char.prev.insertSpaces(char.column ~/ 2 * char.tabSize - char.column);
        }
        _nextLine();
      }
    }

    return true;
  }


  void parseTabSize()
  {
      reset();
      _aTabSize = tabSize;

      while (_aChar.charType != _CharacterType.Eof)
      {

          var ch = _aChar.cmpString("//#set-tab");

          if (ch!=null)
          {
              ch = ch.skipSpace();
              final t = ch.parseInt(-1);

              if (t>=2 && t<=10)
              {
                  _tabSizeStack.add(_aTabSize);
                  _aTabSize = t;
              }
          }
          else
          {
              ch = _aChar.cmpString("//#pop-tab");
              if (_tabSizeStack.isNotEmpty)
              {
                  _aTabSize = _tabSizeStack.last;
                  _tabSizeStack.removeLast();
              }
          }
          _aChar.tabSize = _aTabSize;

          _aChar = _aChar.next;
      }
  }

  bool _parseInternal()
  {
    while (_aChar.charType != _CharacterType.Eof)
    {
      if (_aChar.isMultilineString())
      {
        if (!_parseString(true, _aChar.prev.code == _Character.$r))
        {
          return false;
        }
      }
      else if (_aChar.isString())
      {
        if (!_parseString(false, _aChar.prev.code == _Character.$r))
        {
          return false;
        }
      }
      else if (_aChar.isLineComment())
      {
        while (_aChar.charType != _CharacterType.Eof && !_aChar.isEOL())
        {
          _aChar.charType = _CharacterType.Comment;
          _nextUpdate();
        }
      }
      else if (_aChar.isComment())
      {
        int commentLevel = 0;
        _aChar.charType = _CharacterType.Comment;

        do
        {
          if (_aChar.isEndComment())
          {
            commentLevel--;
            _aChar.charType = _CharacterType.Comment;
            _nextUpdate();
          }
          else if (_aChar.isComment())
          {
            commentLevel++;
          }

          _aChar.charType = _CharacterType.Comment;
          _nextUpdate();
        }
        while (commentLevel > 0);
      }
      else if (_aChar.isOpenBrace())
      {
        _aChar.level = ++_aLevel;
        _nextUpdate();
        if (!_parseInternal())
        {
          return false;
        }
      }
      else if (_aChar.isCloseBrace())
      {
        _aChar.level = _aLevel--;
        _nextUpdate();
        return true;
      }
      else
      {
        _nextUpdate();
      }
    }

    return _aLevel == 0;
  }

  bool _parseString(bool multiline, bool raw)
  {
    var stringCode = _aChar.code;
    _aChar.charType = _CharacterType.Str;

    _nextUpdate().charType = _CharacterType.Str;
    if (multiline)
    {
      _nextUpdate().charType = _CharacterType.Str;
      _nextUpdate().charType = _CharacterType.Str;
    }

    while (_aChar.charType != _CharacterType.Eof)
    {
      if (raw || _aChar.code != _Character.$backshlash)
      {
        if (multiline)
        {
          if (_aChar.code == stringCode &&
              _aChar.next.code == stringCode &&
              _aChar.next.next.code == stringCode)
          {
            _nextUpdate().charType = _CharacterType.Str;
            _nextUpdate().charType = _CharacterType.Str;
            _nextUpdate();
            return true;
          }
        }
        else
        {
          if (_aChar.code == stringCode)
          {
            _nextUpdate();
            return true;
          }
          else if (_aChar.isEOL())
          {
            return false;
          }
        }

        if (_aChar.code == _Character.$dolar && _aChar.next.code == _Character.$openBraceCu)
        {
          _nextUpdate().charType = _CharacterType.Normal;
          _aChar.level = ++_aLevel;
          _nextUpdate().charType = _CharacterType.Normal;
          if (!_parseInternal())
          {
            return false;
          }
          else
          {
            _aChar = _aChar.prev;
          }
        }
      }
      else
      {
        _nextUpdate().charType = _CharacterType.Str;
      }

      _nextUpdate().charType = _CharacterType.Str;
    }

    return false;
  }

  void columns()
  {
    reset();

    while (_nextUpdate().charType != _CharacterType.Eof);
  }

  void reset()
  {
    _aChar = _chars.next;
    _aChar.column = 0;
    _aChar.level = 0;
    _aColumn = 1;
    _aLevel = 0;
    _aTabSize = tabSize;
  }

  _Character _nextUpdate()
  {
    if (_aChar.charType != _CharacterType.Eof)
    {
      _aChar = _aChar.next;
      _aChar.level = _aLevel;
      //print(String.fromCharCode(_aChar.code & 0xffff));

      if (_aChar.code == _Character.$cr || _aChar.code == _Character.$lf)
      {
        _aColumn = 0;
      }
      else
      {
        _aChar.column = _aColumn++;
      }
    }

    return _aChar;
  }

  _Character? _next()
  {
    if (_aChar.charType != _CharacterType.Eof)
    {
      _aChar = _aChar.next;
      //stdout.write(String.fromCharCode(_aChar.code&0xffff));
    }

    return _aChar;
  }

  _Character? _nextLine()
  {
    while (_aChar.charType != _CharacterType.Eof && _aChar.code != _Character.$cr && _aChar.code != _Character.$lf)
    {
      _next();
    }

    while (_aChar.charType != _CharacterType.Eof && (_aChar.code == _Character.$cr || _aChar.code == _Character.$lf))
    {
      _next();
    }

    return _aChar;
  }

  bool _breakPatternAmongBraces(List<String> patterns)
  {
    var result = false;
    var char = _aChar.skipSpace();

    if (char.code == _Character.$closeBraceCu && char.charType == _CharacterType.Normal)
    {
      var closeColumn = char.column;

      char = char.next.skipSpace();
      var wordBeginChar = char;

      for (var i = 0; i < patterns.length; i++)
      {
        _Character? pchar = char;
        var pattern = patterns[i];

        var ci;
        for (ci = 0; ci < pattern.length; ci++, pchar = pchar.next)
        {
          //print("${String.fromCharCode(pchar.code&0xffff)}:${String.fromCharCode(pattern.codeUnitAt(ci))}");
          if (pattern.codeUnitAt(ci) != pchar!.code)
          {
            break;
          }
        }

        if (ci == pattern.length)
        {
          wordBeginChar.prev.insertString("\r\n");
          wordBeginChar.prev.insertSpaces(closeColumn);
          result = true;
          break;
        }
      }
    }

    return result;
  }
}

class _Character
{
  _CharacterType charType = _CharacterType.Normal;
  int level = 0;
  int tabSize = 2;
  int column = 0;
  int code;
  late _Character prev, next;

  static const $eof = -1;
  static const $openBrace = 0x28; //'('
  static const $closeBrace = 0x29; //')'
  static const $openBraceSq = 0x5b; // '['
  static const $closeBraceSq = 0x5d; //']'
  static const $openBraceCu = 0x7b; //'{'
  static const $closeBraceCu = 0x7d; //'}'
  static const $singleQuotes = 0x27; //'\''
  static const $doubleQuotes = 0x22; //'"'
  static const $backshlash = 0x5c; //'\\'
  static const $shlash = 0x2f; //'/'
  static const $asterisks = 0x2a; //'*'
  static const $dolar = 0x24; //'$'
  static const $r = 0x72; //'r'

  static const $cr = 0x0d; //'\r'
  static const $lf = 0x0a; //'\n'

  static final $openBraceList = {$openBrace, $openBraceCu, $openBraceSq};

  static final $closeBraceList = {$closeBrace, $closeBraceCu, $closeBraceSq};

  _Character(this.code)
  {
    prev = this;
    next = this;

    if (code < 0)
    {
      charType = _CharacterType.Eof;
    }
  }

  bool isOpenBrace() => $openBraceList.contains(code);

  bool isCloseBrace() => $closeBraceList.contains(code);

  bool isString() => (code == $singleQuotes || code == $doubleQuotes);

  bool isMultilineString() => (isString() && this.next.code == code && this.next.next.code == code);

  bool isComment() => (code == $shlash && next.code == $asterisks);

  bool isEndComment() => (code == $asterisks && next.code == $shlash);

  bool isLineComment() => (code == $shlash && next.code == $shlash);

  bool isEOL() => (code == $cr || code == $lf);

  bool isSpace() => (code == 0x20 || code == 0x09 || code == 0xc || code == 0xb || code == 0xa0);

  _Character? cmpString(String string)
  {
      _Character result = this;
      for(final code in string.codeUnits)
      {
          if (code != result.code)
          {
              return null;
          }
      }

      return result;
  }

  int parseInt(int defValue)
  {
      int result = 0;
      _Character ch = this;

      if (ch.code < /*$0*/0x30 || ch.code > /*$9*/0x39)
      {
          return defValue;
      }
      else
      {
          while (ch.code >= /*$0*/0x30 && ch.code <= /*$9*/0x39)
          {
              result = 10*result + (ch.code - /*$0*/0x30);
              ch = ch.next;
          }

          return result;
      }

  }


  int getCloseBrace()
  {
    switch (code)
    {
      case $openBrace:
        return $closeBrace;

      case $openBraceSq:
        return $closeBraceSq;

      case $openBraceCu:
        return $closeBraceCu;

      default:
        return 0;
    }
  }

  bool lastOnLine()
  {
    var char = this.next;

    while (true)
    {
      if (char.charType == _CharacterType.Eof || char.isLineComment() || char.isEOL())
      {
        return true;
      }
      else if (!char.isSpace())
      {
        return false;
      }
      else
      {
        char = char.next;
      }
    }
  }

  _Character skipSpace()
  {
    _Character char = this;

    while (char.isSpace())
    {
      char = char.next;
    }

    return char;
  }

  bool firstOnLine()
  {
    var char = this.prev;

    while (true)
    {
      if (char.charType == _CharacterType.Eof || char.isEOL())
      {
        return true;
      }
      else if (!char.isSpace())
      {
        return false;
      }
      else
      {
        char = char.prev;
      }
    }
  }

  bool removeSpacesRight()
  {
    var char = this.prev;

    while (true)
    {
      if (char.charType == _CharacterType.Eof || char.isEOL())
      {
        return true;
      }
      else if (!char.isSpace())
      {
        return false;
      }
      else
      {
        char = char.prev;
      }
    }
  }

  _Character? findLevelClose()
  {
    // ignore: avoid_init_to_null
    _Character? result = null;

    if (isOpenBrace())
    {
      var char = next;

      while (char.charType != _CharacterType.Eof)
      {

        if (char.isCloseBrace() && char.charType == _CharacterType.Normal && char.level == this.level)
        {
          if (char.code == this.getCloseBrace())
          {
            result = char;
          }
          break;
        }

        char = char.next;
      }
    }

    return result;
  }

  void remove()
  {
    this.prev.next = next;
    this.next.prev = prev;
    this.next = this;
    this.prev = this;
  }

  _Character add(_Character char)
  {
    char.prev = this;
    char.next = this.next;
    this.next.prev = char;
    this.next = char;
    return char;
  }

  _Character addPrev(_Character char) => prev.add(char);

  void insertSpaces(int count)
  {
    while (count-- > 0)
    {
      add(_Character(0x20));
    }
  }

  void insertString(String text)
  {
    var char = next;

    for (int i = 0; i < text.length; i++)
    {
      char.addPrev(_Character(text.codeUnitAt(i)));
    }
  }
}

enum _CharacterType { Normal, Comment, Str, Eof }