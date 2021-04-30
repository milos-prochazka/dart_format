import 'package:dart_format/dart_format.dart' as dart_format;

void main(List<String> arguments) 
{
/*#debug
    if (arguments.isEmpty) 
    {
        arguments = [r'.\', '4'];
    }
//#end*/

  //for (var match in matches)
  dart_format.command(arguments);
}
