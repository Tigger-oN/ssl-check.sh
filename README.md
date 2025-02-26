# ssl-check.sh

Check the dates and issuer information of any number of SSL certificates.

Usage:

 ssl-check.sh
 ssl-check.sh domain.name [ domain2.name... ]
 ssl-check.sh -f /path/to/domain/list
 ssl-check.sh [ -h | -v ] 

With no options passed, a "default list" of domains will be checked. Add any
number of domains to the following file to populate the default list.

    ${HOME}/.ssl-check.sh.list

If a list of domains are passed in, that list will be checked instead.

You can specify a file to be used instead with:

    -f /path/to/domain/list

This help can be shown with either `-h` or `-v` and will also be shown if 
there are no arguments and the "default list" file does not exists.

Domain name file lists should be seperated by a space or a line return. You can
use a `#` at the beginning of a line for a comment if needed.

