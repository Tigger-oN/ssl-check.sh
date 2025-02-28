# ssl-check.sh

Check the end date and issuer information of SSL certificates.

Usage:

    ssl-check.sh
    ssl-check.sh [ -a | -f file ] [ domain... ]
    ssl-check.sh [ -h | -v ]

With no options passed, a "default list" of domains will be checked. Add any
number of domains to the following file to populate the default list.

    ${HOME}/.ssl-check.sh.list

The options are:

    -a      : Include the alternative subject names in the output.
    -f file : Check the list of domains in "file".
    domain  : One or more domain names to check.
    
    -h | -v : Show this help.

If there are no arguments and the "default list" file does not exist, this
help will also be shown.

Domain name file lists should be seperated by a space or a line return. You can
use a `#` at the beginning of a line for a comment if needed.

The `-f file` option can be used alongside passed in domain names. The domains
passed in will appear at the end of the list.

Examples and output:

    ssl-check.sh github.com

       SSL for: github.com
       Subject: github.com
     Not after: Feb  5 23:59:59 2026 GMT
        Issuer: Sectigo Limited (GB)
                Sectigo ECC Domain Validation Secure Server CA

With the `-a` flag:

    ssl-check.sh -a github.com

       SSL for: github.com
       Subject: github.com
    Alt. names: github.com, www.github.com
     Not after: Feb  5 23:59:59 2026 GMT
        Issuer: Sectigo Limited (GB)
                Sectigo ECC Domain Validation Secure Server CA


