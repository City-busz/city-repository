cd pkg
sfood > /tmp/raw-deps.txt
sed "s/(([^(]*(\(.*\)))/\1/
     s/[ ']*//g
     s/,/\//
     s|$PWD|Internal|
     s|/usr/lib/python2.7/site-packages/|Required|
     s|/usr/lib/python2.7/|PythonStandard|
     s|Required|/usr/lib/python2.7/site-packages/|
      /$1/ d
     /None/ d
     /Internal/ d
     /PythonStandard/ d
     s|[^\.]..$|&/__init__.py|" <'/tmp/raw-deps.txt' >'/tmp/filtered-deps.txt'
sort '/tmp/filtered-deps.txt' | uniq | xargs pacman -Qo
