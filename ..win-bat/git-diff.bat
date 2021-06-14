cd ..
git archive -o .git_tmp.zip %1
rd "%TEMP%\gitdiff" /q /s
mkdir "%TEMP%\gitdiff"
c:\meld\unzip .git_tmp.zip -d "%TEMP%\gitdiff"
del .git_tmp.zip

if .%2. == .. goto workcomp

git archive -o .git_tmp.zip %2
rd "%TEMP%\gitdiff2" /q /s
mkdir "%TEMP%\gitdiff2"
c:\meld\unzip .git_tmp.zip -d "%TEMP%\gitdiff2"
del .git_tmp.zip
start c:\meld\meld "%TEMP%\gitdiff" "%TEMP%\gitdiff2"
goto end

:workcomp
start c:\meld\meld .\ "%TEMP%\gitdiff"
:end
