#!/bin/sh
#
# Show date information for a SSL cert.

# Script version
VERSION="20250226"
# The location of the default domain list.
DEFAULT_LIST_FILE="${HOME}/.${0##*/}.list"
# Will be populated if needed.
LIST_FILE=""
# Used to work out the number of days
TODAY=`TZ=GMT date +%s`
DAYS=""

usage () {
	app=${0##*/}
	if [ -f "${DEFAULT_LIST_FILE}" ]
	then
		defaultList="File found."
	else
		defaultList="No file found."
	fi
	out="
Check the dates and issuer information of any number of SSL certificates.

Usage:

 ${app}
 ${app} domain.name [ domain2.name... ]
 ${app} -f /path/to/domain/list
 ${app} [ -h | -v ] 

With no options passed, a \"default list\" of domains will be checked. Add any
number of domains to the following file to populate the default list.

 \"${DEFAULT_LIST_FILE}\"

If a list of domains are passed in, that list will be checked instead.

You can specify a file to be used instead with \"-f /path/to/domain/list\".  

This help can be shown with either \"-h\" or \"-v\" and will also be shown if 
there are no arguments and the \"default list\" file does not exists.

Domain name file lists should be seperated by a space or a line return. You can
use a \"#\" at the beginning of a line for a comment if needed.

Default domain list information.
 Location: ${DEFAULT_LIST_FILE}
   Status: ${defaultList}

Version: ${VERSION}
"
	printf "%s\n" "${out}"
	exit
}

invalidFilePath () {
	out="
A request to use a list of domains in a file was made, but the path to that
file is not valid. Please check and try again.
"
	printf "%s\n" "${out}"
	exit
}

invalidFileEmpty () {
	out="
A request to use a list of domains in a file was made, but there are no domains
located within that file.

At list one domain name is needed.
"
	printf "%s\n" "${out}"
	exit
}

listIsEmpty () {
	out="
Somehow we have an empty list of domains to check. As there is nothing to 
check, there is also nothing to do other than to try and work out how this has
happened.
"
	printf "%s\n" "${out}"
	exit
}

listFromFile () {
	if [ -f "${LIST_FILE}" ]
	then
		LIST=`grep -v '^#\|^[[:space:]]*#\|^[[:space:]]*$' "${LIST_FILE}"`
	fi
}

listFromArg () {
	LIST=""
	for d in $@
	do
		LIST="${LIST}
${d}"
	done
}

getDays () {
	if [ -z "${notAfter}" ]
	then
		DAYS=""
		return
	fi
	# Confirmed "%e" (no leading 0) is correct for the day.
	expireDate=`TZ=GMT date -j -f "%b %e %T %Y %Z" "${notAfter}" "+%s" 2> /dev/null`
	if [ -z "${expireDate}" ]
	then
		DAYS=" (Unable to confirm days)"
	else
		DAYS=$((${expireDate} - ${TODAY}))
		DAYS=$((DAYS / 86400))
		if [ ${DAYS} -lt 30 ]
		then
			if [ ${DAYS} -eq 0 ]
			then
				DAYS=" !! EXPIRES TODAY !!"
			elif [ ${DAYS} -lt 0 ]
			then
				DAYS=" !! HAS EXPIRED !!"
			elif [ ${DAYS} -eq 1 ]
			then
				DAYS=" !! EXPIRES TOMORROW !!"
			else
				DAYS=" - Expires in ${DAYS} days."
			fi
		else
			DAYS=""
		fi
	fi
}

# What type of request was made.
if [ "${1}" = "-h" -o "${1}" = "-v" ]
then
	usage
elif [ -z "${1}" -a ! -f "${DEFAULT_LIST_FILE}" ]
then
	usage
elif [ -z "${1}" -a -f "${DEFAULT_LIST_FILE}" ]
then
	LIST_FILE="${DEFAULT_LIST_FILE}"
	listFromFile
elif [ "${1}" = "-f" -a -z "${2}" ]
then
	invalidFilePath
elif [ "${1}" = "-f" -a ! -f "${2}" ]
then
	invalidFilePath
elif [ "${1}" = "-f" -a -f "${2}" ]
then
	LIST_FILE="${2}"
	listFromFile
elif [ -z "${1}" ]
then
	usage
else
	# Must be a list of domains
	listFromArg $@
fi

# Should not be possible, but check anyway
if [ -z "${LIST}" ]
then
	listIsEmpty
fi

for s in ${LIST}
do
	printf "\nChecking ${s}"
	raw=`yes | openssl s_client -connect ${s}:443 2> /dev/null | openssl x509 -noout -subject -dates -issuer 2> /dev/null | grep "^subject=\|^notAfter=\|^issuer="`
	subject=`printf "%s" "${raw}" | grep "^subject=.*CN = .*" | sed 's/subject=.*CN = //g'`
	notAfter=`printf "%s" "${raw}" | grep "^notAfter=.*" | sed 's/notAfter=//g'`
	issuerCountry=`printf "%s" "${raw}" | grep "^issuer=C.*" | sed 's/^issuer=C = //g; s/,.*//g'`
	issuerOrg=`printf "%s" "${raw}" | grep "^issuer=C.*, O = " | sed 's/^issuer=C.*, O = //g; s/,.*//g'`
	issuerCommon=`printf "%s" "${raw}" | grep "^issuer=C.*, CN = " | sed 's/^issuer=C.*, CN = //g; s/,.*//g'`
	# How soon does the cert expire?
	if [ -z "${subject}" ]
	then
		printf "\rUnable to obtain an SSL certificate for %s\n" "${s}"
	else
		getDays
		printf "\r   SSL for: %s\n\
   Subject: %s\n\
 Not after: %s%s\n\
    Issuer: %s (%s)\n\
            %s\n" "${s}" "${subject}" "${notAfter}" "${DAYS}" "${issuerOrg}" "${issuerCountry}" "${issuerCommon}"
	fi
done

printf "\n"
exit

