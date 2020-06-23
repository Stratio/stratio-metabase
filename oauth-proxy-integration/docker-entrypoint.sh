#!/bin/bash

###-- Override with custom entrypoint --###

nginx_conf_dir=/usr/local/openresty/nginx/conf
NGINX_ERROR_LOG_LEVEL="${NGINX_ERROR_LOG_LEVEL:-error}"

export NGINX_ERROR_LOG_LEVEL
export PROXY_READ_TIMEOUT

# we use a different env. variable to not make it confusing when someone uses the "native JWT auth"
# only if varible is defined and set to true do we use dcos-oauth
if [[ "$USE_GOSEC_SSO_AUTH" != "true" ]]; then
    # we are using native authentication so we use the corresponding nginx.conf
    envsubst '\$NGINX_ERROR_LOG_LEVEL \$PROXY_READ_TIMEOUT' < ${nginx_conf_dir}/nginx.conf.native-auth > ${nginx_conf_dir}/nginx.conf
else
    # we are delegating authentication in dcos-oauth so we use the corresponding nginx.conf
    envsubst '\$NGINX_ERROR_LOG_LEVEL \$PROXY_READ_TIMEOUT' < ${nginx_conf_dir}/nginx.conf.sso-auth > ${nginx_conf_dir}/nginx.conf
fi

source /usr/local/lib/kms_utils.sh
source /usr/local/lib/b-log.sh

source /root/kms/secrets.sh
