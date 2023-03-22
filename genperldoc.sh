#!/usr/bin/env bash

#
#  Generate a full set of HTML Perl documentation pages to the local directory.
#
#  Note that the perldoc command isn't installed by default on Debian
#  (apt-get install perl-doc).
#

PERLDOCS="$(perldoc -o txt perltoc | perl -ne 'print "$1 " if /^  (perl\w+) - \b/') perltoc perlintro perl"
PERLDOCS_RE="$(perl -pe 'chomp;s/\s+/|/g' <<<"${PERLDOCS}")"

for DOC in ${PERLDOCS}
do
	perldoc -o html -d ${DOC}.html ${DOC}
done

perl -i -pe 's,href="https?://(?:search.cpan.org/perldoc\?|metacpan.org/pod/)('"${PERLDOCS_RE}"')\b,href="./\1.html,g' perl*.html

perl -i -pe 's,(^(?:<pre>)?\s+)('"${PERLDOCS_RE}"')(\s+),\1<a href="./\2.html">\2</a>\3,g' perl.html
ln -s perl.html index.html

