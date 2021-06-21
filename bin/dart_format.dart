import 'package:dart_format/dart_format.dart' as dart_format;

void main(List<String> arguments)
{
//#debug
//##    if (arguments.isEmpty)
//##    {
//##        arguments = [r'.\test.dartx', '4'];
//##        //arguments = [r'..\dart_format_test', '4'];
//##    }
//#end DEBUG line:5


  //for (var match in matches)
  dart_format.command(arguments);
}