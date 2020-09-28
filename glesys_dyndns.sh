#!/bin/bash
GLOBIGNORE="*"

# Credits to https://github.com/jakeru/dyndns_glesys
# Most parts of the script have been copied from there

set -e

# Performs a POST to a URL using basic authentication.
# Usage:
# response=$(post body, URL, user, password, header)
post() {
  body="$1"
  url="$2"
  user="$3"
  passwd="$4"
  h1="$5"
  echo $(curl -u "$user:$passwd" -H "$h1" --data "$body" "$url")
}

# Performs a request to the GleSYS API.
# Usage:
# GLESYS_USER=API user
# GLESYS_TOKEN=API token
# response = $(glesys_rest body path)
# Body is expected to be JSON.
glesys_rest() {
  body="$1"
  url="https://api.glesys.com/$2"
  h1="Content-Type: application/json"
  response=$(post "$body" "$url" "$GLESYS_USER" "$GLESYS_TOKEN" "$h1")
  code=$(echo "$response" | jq .response.status.code)

  if [ "$code" != "200" ]; then
    echo "Error when visiting $url: Bad response:"
    echo $response
    exit 1
  fi

  echo $response
}

# Usage:
# record_id=$(glesys_dns_find_record domain subdomain type)
glesys_dns_find_record() {
  body="{\"domainname\":\"$1\"}"
  response=$(glesys_rest "$body" "domain/listrecords")
  #echo "$response"
  echo "$response" | jq ".response.records[]|select(.host==\"$2\" and .type==\"$3\")|.recordid"
}

# Usage:
# glesys_dns_update_record recordid ipv4-address
glesys_dns_update_record() {
  body="{\"recordid\":\"$1\",\"data\":\"$2\"}"
  response=$(glesys_rest "$body" "domain/updaterecord")
}

full_domain=$1

if [ -z "$full_domain" ]; then
  echo "Parameter domain is missing."
  echo "Usage: $0 <domain>."
  echo "This tool gets the IP address of an EdgeRouter and updates a A record"
  echo "using the GleSYS API."
  echo "You need to get an API token and set GLESYS_USER and GLESYS_TOKEN in"
  echo "order to use this tool."
  echo "Example of usage: $0 home.example.com"
  exit 1
fi

type="A"
domain="$(echo $full_domain | rev | cut -d . -f 1,2 | rev)"
subdomain="$(echo $full_domain | rev | cut -d . -f 3- | rev)"

if [ -z "$subdomain" ]; then
  subdomain="@"
fi

if [ -z "$GLESYS_USER" ]; then
  echo "GLESYS_USER is not set. It should be set to the username of your GleSYS account"
  exit 1
fi

if [ -z "$GLESYS_TOKEN" ]; then
  echo "GLESYS_TOKEN is not set. It should be set to the GleSYS API token"
  exit 1
fi

my_address=$(curl ifconfig.me)

echo "My IP address: $my_address"

echo "Searching for record $subdomain of type $type in domain $domain"
record_id=$(glesys_dns_find_record $domain $subdomain $type)
echo "Updating record_id $record_id"
glesys_dns_update_record $record_id $my_address

echo "Done".
