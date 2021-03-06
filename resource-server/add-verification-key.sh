#!/usr/bin/env bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }
which base64 > /dev/null || { echo >&2 "error: base64 not found"; exit 3; }
which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-f file] [-k kid] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # resource-server id
        -f file         # PEM certificate file
        -k kid          # key id
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 5c1ffff8446f3135f36829ba -k mykid -f ../ca/mykey.local.crt
END
    exit $1
}

declare rs_id=''
declare pem_file=''
declare kid=''

while getopts "e:a:i:f:k:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        i) rs_id=${OPTARG};;
        f) pem_file=${OPTARG};;
        k) kid=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${rs_id}" ]] && { echo >&2 "ERROR: rs_id undefined."; usage 1; }
[[ -z "${kid}" ]] && { echo >&2 "ERROR: kid undefined."; usage 1; }
[[ -z "${pem_file}" ]] && { echo >&2 "ERROR: pem_file undefined."; usage 1; }
[[ -f "${pem_file}" ]] || { echo >&2 "ERROR: pem_file missing: ${pem_file}"; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare -r pem_single_line=`sed 's/$/\\\\n/' ${pem_file} | tr -d '\n'`

declare BODY=$(cat <<EOL
{
 "verificationKeys" : [
    {
      "kid": "${kid}",
      "pem": "${pem_single_line}"
    }
   ]
}

EOL
)

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/resource-servers/${rs_id} \
    --header 'content-type: application/json' \
    --data "${BODY}"
