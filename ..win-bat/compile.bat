cd ..
delete dart-format.exe
dart-prep +RELEASE ./
dart compile exe bin/dart_format.dart -o ./dart-format.exe
rem dart compile js bin/dart_format.dart -o ./dart-format.js
