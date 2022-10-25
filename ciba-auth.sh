#!/bin/bash

function ciba_auth {
# First : Make an authentication request
# BACKCHANNEL AUTHENTICATION ENDPOINT to Keycloak
OUTPUT=$(curl --location --request POST "$BACKCHANNEL_ENDPOINT" \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode "client_id=$CLIENT_ID" \
--data-urlencode "client_secret=$CLIENT_SECRET" \
--data-urlencode "login_hint=$USERNAME" \
--data-urlencode "scope=$SCOPE" \
--data-urlencode "binding_message=$HINT" \
--data-urlencode 'is_consent_required=true' )

echo $OUTPUT | jq

AUTH_REQ_ID=$(echo $OUTPUT | jq -r .auth_req_id)
EXPIRES_IN=$(echo $OUTPUT | jq -r .expires_in)
INTERVAL=$(echo $OUTPUT | jq -r .interval)

# Keycloak calls backchanel
# @see backchanel.sh script, gets request then answer 201 to Keycloak.

# start polling for a token
LOOP=0
while ((LOOP<EXPIRES_IN))
do
    OUTPUT=$(curl --location --request POST "$TOKEN_ENDPOINT" \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=urn:openid:params:grant-type:ciba' \
    --data-urlencode "auth_req_id=$AUTH_REQ_ID" \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "client_secret=$CLIENT_SECRET")
    echo $OUTPUT | jq
    if [[ $OUTPUT != *"pending"* ]]; then
        break
    fi
    sleep $INTERVAL
    LOOP=$LOOP+$INTERVAL
done

}


function show_help {
echo "PLEASE-OPEN.IT CIBA BASH CLIENT"
echo "SYNOPSIS"
echo ""
echo "ciba-auth.sh --openid-endpoint [--token-endpoint] --client-id --client-secret --username --scope --hint"



echo "DESCRIPTION"
echo ""
echo "This script is a client for CIBA authentication"

}

PARAMS=""
while (( "$#" )); do
  case "$1" in
    --help)
      show_help
      shift
      ;;
    --openid-endpoint)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        OPENID_ENDPOINT=$2
        shift 2
      fi
      ;;
    --backchannel-authentication-endpoint)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        BACKCHANNEL_ENDPOINT=$2
        shift 2
      fi
      ;;
    --token-endpoint)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        TOKEN_ENDPOINT=$2
        shift 2
      fi
      ;;
    --client-id)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        CLIENT_ID=$2
        shift 2
      fi
      ;;
    --client-secret)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        CLIENT_SECRET=$2
        shift 2
      fi
      ;;
    --username)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        USERNAME=$2
        shift 2
      fi
      ;;
    --scope)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        SCOPE=$2
        shift 2
      fi
      ;;
    --hint)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        HINT=$2
        shift 2
      fi
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

if [ -z "$OPENID_ENDPOINT" ] && [ -z "$TOKEN_ENDPOINT" ]; then
    echo "Error: --token-endpoint is missing, you can also use --openid-endpoint" >&2
    exit 1
fi
if [ -z "$TOKEN_ENDPOINT" ]; then
    TOKEN_ENDPOINT=$(curl -sS $OPENID_ENDPOINT | jq .token_endpoint -r)
fi
if [ -z "$OPENID_ENDPOINT" ] && [ -z "$BACKCHANNEL_ENDPOINT" ]; then
    echo "Error: --backchannel-authentication-endpoint is missing, you can also use --openid-endpoint" >&2
    exit 1
fi
if [ -z "$BACKCHANNEL_ENDPOINT" ]; then
    BACKCHANNEL_ENDPOINT=$(curl -sS $OPENID_ENDPOINT | jq .backchannel_authentication_endpoint -r)
fi
if [ -z "$CLIENT_ID" ]; then
    echo "Error: --client-id is missing" >&2
    exit 1
fi
if [ -z "$CLIENT_SECRET" ]; then
    echo "Error: --client-secret is missing" >&2
    exit 1
fi
if [ -z "$USERNAME" ]; then
    echo "Error: --username is missing" >&2
    exit 1
fi
if [ -z "$HINT" ]; then
    echo "Error: --hint is missing" >&2
    exit 1
fi
if [ -z "$SCOPE" ]; then
    echo "Error: --scope is missing" >&2
    exit 1
fi
ciba_auth