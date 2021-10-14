#!/bin/bash
cd ..
delete dart-format
dart-prep +RELEASE +UNIX ./
dart compile exe bin/dart_format.dart -o ./dart-format
rem dart compile js bin/dart_format.dart -o ./dart-format.js
