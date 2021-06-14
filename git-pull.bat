git stash push --all -m "%pull - date% %time%"
git checkout master
git fetch origin master
git rebase -i origin/master
git pull
rem test