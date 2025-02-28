#!/bin/sh
#
# Show date information for a SSL cert.
#

# Script version
VERSION="20250228"
# The location of the default domain list.
DEFAULT_LIST_FILE="${HOME}/.${0##*/}.list"
# Show subject alternative names. Defaults to "no" (not shown).
ALT_NAMES="no"
# Will be populated when needed.
REQUEST_FILE=""
REQUEST_LIST=""
LIST=""
# Used to work out the number of days
TODAY=`TZ=GMT date +%s`
DAYS=""
# Because `date` is non-standard
OS=`uname`

usage () {
	app=${0##*/}
	if [ -f "${DEFAULT_LIST_FILE}" ]
	then
		defaultList="File found."
	else
		defaultList="No file found."
	fi
	out="
Check the end date and issuer information of SSL certificates.

Usage:

 ${app} 
 ${app} [ -a | -f file ] [ domain... ]
 ${app} [ -h | -v ]

With no options passed, a \"default list\" of domains will be checked. Add any
number of domains to the following file to populate the default list.

 \"${DEFAULT_LIST_FILE}\"

 -a      : Include the alternative subject names in the output.
 -f file : Check the list of domains in \"file\".
 domain  : One or more domain names to check.

 -h | -v : Show this help.

If there are no arguments and the \"default list\" file does not exist, this
help will also be shown.

Domain name file lists should be seperated by a space or a line return. You can
use a \"#\" at the beginning of a line for a comment if needed.

The \"-f file\" option can be used alongside passed in domain names. The domains
passed in will appear at the end of the list.

Default list information.

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

invalidAltRequest () {
	out="
At least one domain name is required with the \"-a\" flag. The domain name can 
be in the default list, a file (request with \"-f file\") or passed in on the 
command line.
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
	if [ -f "${REQUEST_FILE}" ]
	then
		LIST=`grep -v '^#\|^[[:space:]]*#\|^[[:space:]]*$' "${REQUEST_FILE}"`
	fi
}

listFromArg () {
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
	# date is OS dependent.
	if [ "${OS}" = "FreeBSD" ]
	then
		# Highly possible that Darwin would be the same here. Currently untested.
		# Confirmed "%e" (no leading 0) is correct for the day.
		expireDate=`TZ=GMT date -j -f "%b %e %T %Y %Z" "${notAfter}" "+%s" 2> /dev/null`
	elif [ "${OS}" = "Linux" ]
	then
		expireDate=`date -d "${notAfter}" "+%s" 2> /dev/null`
	else
		# Because we can not trust `date` :(
		DAYS=""
		return
	fi
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

# What options have been requetsed?
if [ -n "${1}" ]
then
	# At least one option to check
	while getopts "ahf:v" opt
	do
		case "${opt}" in
			a) ALT_NAMES="yes" ;;
			h|v) usage ;;
			f) REQUEST_FILE="${OPTARG}" ;;
		esac
	done
	shift $((OPTIND - 1))
	REQUEST_LIST=$*
fi

# Nothing to do check
if [ -z "${REQUEST_LIST}" -a -z "${REQUEST_FILE}" -a ! -f "${DEFAULT_LIST_FILE}" ]
then
	usage
fi

# Default list check
if [ -z "${REQUEST_LIST}" -a -z "${REQUEST_FILE}" -a -f "${DEFAULT_LIST_FILE}" ]
then
	REQUEST_FILE="${DEFAULT_LIST_FILE}"
	listFromFile
else
	# We can support both a file list and passed in domains like this. File
	# list must be done first.
	if [ -n "${REQUEST_FILE}" ]
	then
		if [ -f "${REQUEST_FILE}" ]
		then
			listFromFile
			if [ -z "${LIST}" ]
			then
				invalidFileEmpty
			fi
		else
			invalidFilePath
		fi
	fi
	if [ -n "${REQUEST_LIST}" ]
	then
		listFromArg $@
	fi
fi

# Sanity checks
if [ -z "${LIST}" ]
then
	if [ "${ALT_NAMES}" = "yes" ]
	then
		invalidAltRequest 
	else
		listIsEmpty
	fi
fi

# Main logic
for s in ${LIST}
do
	printf "\nChecking ${s}"
	raw=`yes | openssl s_client -connect ${s}:443 2> /dev/null | openssl x509 -noout -text -ext subjectAltNames 2> /dev/null | sed 's/^[[:space:]]*//g'`
	subject=`printf "%s" "${raw}" | grep "^Subject: " | sed 's/.* CN = //g; s/,.*//'`
	notAfter=`printf "%s" "${raw}" | grep "^Not After : " | sed 's/Not After : //'`
	issuerCountry=`printf "%s" "${raw}" | grep "^Issuer: " | sed 's/.* C = //; s/,.*//'`
	issuerOrg=`printf "%s" "${raw}" | grep "^Issuer: " | sed 's/.* O = //; s/,.*//'`
	issuerCommon=`printf "%s" "${raw}" | grep "^Issuer: " | sed 's/.* CN = //; s/,.*//'`
	if [ -n "${subject}" -a "${ALT_NAMES}" = "yes" ]
	then
		altNames=`printf "%s" "${raw}" | grep -A1 "^X509v3 Subject Alternative Name:" | grep -o "DNS:.*" | sed 's/DNS://g'`
		if [ -z "${altNames}" ]
		then
			altNames="n/a"
		fi
		subject="${subject}
Alt. names: ${altNames}"
	fi
	if [ -z "${subject}" ]
	then
		printf "\rUnable to obtain an SSL certificate for %s\n" "${s}"
	else
		# How soon does the cert expire?
		getDays
		# Display
		printf "\r   SSL for: %s\n\
   Subject: %s\n\
 Not after: %s%s\n\
    Issuer: %s (%s)\n\
            %s\n" "${s}" "${subject}" "${notAfter}" "${DAYS}" "${issuerOrg}" "${issuerCountry}" "${issuerCommon}"
	fi
done

printf "\n"
exit

