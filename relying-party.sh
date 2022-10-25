#!/bin/bash

function listen_for_post_request_and_authenticate {
      # get the request, from the auth backchannel. Listen on port 8081.
      echo -e 'HTTP/1.1 201 OK\r\n'  | nc -l 8081 > output.file
      echo >> output.file
      tail -2 output.file | jq

      SCOPE=$(tail -2 output.file | jq -r .scope)
      BINDING_MESSAGE=$(tail -2 output.file | jq -r .binding_message)
      LOGIN_HINT=$(tail -2 output.file | jq -r .login_hint)
      IS_CONSENT_REQUIRED=$(tail -2 output.file | jq -r .is_consent_required)
      AUTHORIZATION_BEARER=$(cat output.file | grep Authorization)

      rm output.file


      read -p "For user $LOGIN_HINT : $BINDING_MESSAGE (Succeed/Unauthorized/Cancelled)" STATUS
      case "$STATUS" in
         s)
         STATUS="SUCCEED"
         ;;
         u)
         STATUS="UNAUTHORIZED"
         ;;
         c)
         STATUS="CANCELLED"
         ;;
      esac

      # Then, we notice our Keycloak server that the authentication process is done.
      # By using the Bearer token we go previously in the POST request.
      #
      # Of course, we can also notice the server that the authentication status is failed.
      curl --location --request POST "$CIBA_CALLBACK_ENDPOINT" \
      --header "$AUTHORIZATION_BEARER" \
      --header 'Content-Type: application/json' \
      --data-raw "{
      \"status\" : \"$STATUS\"
      }"
}


function show_help {
      echo "PLEASE-OPEN.IT CIBA BASH BACKCHANNEL"
      echo "SYNOPSIS"
      echo ""
      echo "ciba-backchannel.sh --ciba-callback-endpoint"
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
    --ciba-callback-endpoint)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        CIBA_CALLBACK_ENDPOINT=$2
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

if [ -z "$CIBA_CALLBACK_ENDPOINT" ]; then
      echo "Error: --ciba-callback-endpoint is missing" >&2
      exit 1
fi
listen_for_post_request_and_authenticate