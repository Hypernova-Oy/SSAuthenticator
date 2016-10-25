#/bin/bash

#See.
#  https://www.gnu.org/software/gettext/manual/gettext.html#xgettext-Invocation

ll="fi"
cc="FI"
lang=$ll"_"$cc
textdomain="SSAuthenticator"

#1. Extract translateable strings from source files.
# Define character encoding, programming language, output file
# Define the extractable string keywords
# Define source code files to include in this output file
mkdir -p po
translateableFiles=$(find lib/ -iname '*.pm')
xgettext --from-code=UTF-8 -L Perl -o po/$textdomain.pot \
    -k -k__ -k\$__ -k%__ -k__x -k__n:1,2 -k__nx:1,2 -k__xn:1,2 -kN__ \
    $translateableFiles

#2. Update old translation files
msgmerge po/$lang.po po/$textdomain.pot -o po/$lang.po

#3. Build binary machine object files
mkdir -p LocaleData/$lang/LC_MESSAGES
msgfmt  -o LocaleData/$lang/LC_MESSAGES/$textdomain.mo --check po/$lang.po

#4. Install translated machine objects to system
mkdir -p /usr/share/locale/$lang/LC_MESSAGES/
cp LocaleData/$lang/LC_MESSAGES/$textdomain.mo /usr/share/locale/$lang/LC_MESSAGES/
