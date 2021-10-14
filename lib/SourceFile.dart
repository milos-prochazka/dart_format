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
  int _aLine = 0;

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
    parseTabSize();
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
        if (_aChar.isOpenBracket() && !_aChar.firstOnLine())
        {
          var close = _aChar.findLevelClose();

          if (close == null)
          {
            return false;
          }
          else if ( (close.line > _aChar.line &&  _aChar.lastOnLine()) ||
                    (close.line > _aChar.line+1 ))
          {
              if (!_aChar.lastOnLine()) _aChar.insertString("\r\n");

              _aChar.prev.insertString('\r\n');

              if (!close.firstOnLine()) close.prev.insertString('\r\n');

          }
        }
      }

      _next();
    }

    reset();
    while (_aChar.charType != _CharacterType.Eof)
    {
      _breakPatternAmongBrackets(['else', 'catch', 'while', 'finally']);
      _nextLine();
    }

    reset();
    _setIntent(-1,0);

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
              var t = ch.parseInt(-1);

              if (t>0)
              {

                  if (t<2) t= 2;
                  else if (t > 10) t=10;

                  _tabSizeStack.add(_aTabSize);
                  _aTabSize = t;
              }
          }
          else
          {
              ch = _aChar.cmpString("//#pop-tab");
              if (ch!=null)
              {
                  if (_tabSizeStack.isNotEmpty)
                  {
                      _aTabSize = _tabSizeStack.last;
                      _tabSizeStack.removeLast();
                  }
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
      else if (_aChar.isOpenBracket())
      {
        _aChar.level = ++_aLevel;
        _nextUpdate();
        if (!_parseInternal())
        {
          return false;
        }
      }
      else if (_aChar.isCloseBracket())
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
    _aChar.startString = true;

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

        if (_aChar.code == _Character.$dolar && _aChar.next.code == _Character.$openBracketCu)
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
    _aChar.line = 0;
    _aColumn = 1;
    _aLevel = 0;
    _aLine = 0;
    _aTabSize = tabSize;
  }

  _Character _nextUpdate()
  {
    if (_aChar.charType != _CharacterType.Eof)
    {
      _aChar = _aChar.next;
      _aChar.level = _aLevel;
      _aChar.line = _aLine;
//#debug
//##      print("${_aChar.level}:${String.fromCharCode(_aChar.code & 0xffff)}");
//#end DEBUG line:444
      if (_aChar.code == _Character.$lf)
      {
        if (_aChar.prev.code == _Character.$cr)
        {
            _aChar.column = _aChar.prev.column;
            _aChar.line = _aChar.prev.line;
        }
        else
        {
          _aChar.column = _aColumn;
          _aLine++;
          _aColumn = 0;
        }
      }
      else if (_aChar.code == _Character.$cr)
      {
        _aChar.column = _aColumn;
        _aLine++;
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

  bool _breakPatternAmongBrackets(List<String> patterns)
  {
    var result = false;
    var char = _aChar.skipSpace();

    if (char.code == _Character.$closeBracketCu && char.charType == _CharacterType.Normal)
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


  void _setIntent(int switchBracketLevel,int switchNestingLevel)
  {

      while (_aChar.charType != _CharacterType.Eof && _aChar.level >= switchBracketLevel)
      {
          final linebegin = _aChar.prev;

          if (_aChar.charType == _CharacterType.Normal || _aChar.startString)
          {
              var first =_aChar.skipSpace();
//#debug
//##              print ('Intent ${first.level}:${first.code.toRadixString(16)} "${String.fromCharCode(first.code)}"');
//#end DEBUG line:553
              linebegin.next = first;

              var level = first.level - ((first.isOpenBracket() || first.isCloseBracket()) ? 1: 0 );

              if (first.cmpString(';') != null)
              {
                  var char = linebegin;

                  while (char.isEOL() || char.isSpace())
                  {
                      char = char.prev;
                  }

                  if(char.charType == _CharacterType.Normal)
                  {
                      char.next = first;
                      _nextLine();
                      continue;
                  }
              }

              if ((first.cmpString('case') ?? first.cmpString('default')) != null)
              {
                  if (first.level > switchBracketLevel)
                  {
                      _setIntent(first.level,switchNestingLevel+1);
                      continue;
                  }
                  else
                  {
                      linebegin.insertSpaces((level+switchNestingLevel-1)*first.tabSize);
                  }
              }
              else
              {
                  if (switchNestingLevel>0)
                  {
                    if (first.code == _Character.$closeBracketCu && first.level == switchBracketLevel )
                    {
                        level--;
                    }
                    level+=switchNestingLevel;
                  }
                  linebegin.insertSpaces(level*first.tabSize);
              }
          }

          _nextLine();
      }
  }

}

class _Character
{
  _CharacterType charType = _CharacterType.Normal;
  int level = 0;
  int line = 0;
  int tabSize = 2;
  int column = 0;
  bool startString = false;
  int code;
  late _Character prev, next;

  static const $eof = -1;
  static const $openBracket = /*$(*/(0x28);
  static const $closeBracket = 0x29; //')'
  static const $openBracketSq = 0x5b; // '['
  static const $closeBracketSq = 0x5d; //']'
  static const $openBracketCu = 0x7b; //'{'
  static const $closeBracketCu = 0x7d; //'}'
  static const $singleQuotes = 0x27; //'\''
  static const $doubleQuotes = 0x22; //'"'
  static const $backshlash = 0x5c; //'\\'
  static const $shlash = 0x2f; //'/'
  static const $asterisks = 0x2a; //'*'
  static const $dolar = /*$$*/(0x24);
  static const $r = /*$r*/(0x72);

  static const $cr = /*$\r*/(0xD);
  static const $lf = /*$\n*/(0xA);

  static final $openBracketList = {$openBracket, $openBracketCu, $openBracketSq};

  static final $closeBracketList = {$closeBracket, $closeBracketCu, $closeBracketSq};

  _Character(this.code)
  {
    prev = this;
    next = this;

    if (code < 0)
    {
      charType = _CharacterType.Eof;
    }
  }

  bool isOpenBracket() => $openBracketList.contains(code);

  bool isCloseBracket() => $closeBracketList.contains(code);

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
          result = result.next;
      }

      return result;
  }

  int parseInt(int defValue)
  {
      int result = 0;
      _Character ch = this;

      if (ch.code < /*$0*/(0x30)|| ch.code > /*$9*/(0x39))
      {
          return defValue;
      }
      else
      {
          while (ch.code >= /*$0*/(0x30)&& ch.code <= /*$9*/(0x39))
          {
              result = 10*result + (ch.code - /*$0*/(0x30));
              ch = ch.next;
          }

          return result;
      }

  }


  int getCloseBracket()
  {
    switch (code)
    {
      case $openBracket:
        return $closeBracket;

      case $openBracketSq:
        return $closeBracketSq;

      case $openBracketCu:
        return $closeBracketCu;

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

  bool firstOnLine()
  {
    var char = this.prev;

    while (true)
    {
      if (char.charType == _CharacterType.Eof ||  char.isEOL())
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

  bool closeBracketsFirstOnLine()
  {
    var char = this.prev;

    while (true)
    {
      if (char.charType == _CharacterType.Eof ||  char.isEOL())
      {
        return true;
      }
      else if (!char.isSpace() && !char.isCloseBracket())
      {
        return false;
      }
      else
      {
        char = char.prev;
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

    if (isOpenBracket())
    {
      var char = next;

      while (char.charType != _CharacterType.Eof)
      {

        if (char.isCloseBracket() && char.charType == _CharacterType.Normal && char.level == this.level)
        {
          if (char.code == this.getCloseBracket())
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