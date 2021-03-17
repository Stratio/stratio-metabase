#!/bin/bash

if [[ "$LOG_ACCESS_DATA" = "true" ]]; then
  INFO "Obtaining passwords to encrypt data audit"
  INFO "Log data audit enabled, getting encrypt passwords"

  # Get passwords to encrypt logs of data audit as $DATA_AUDIT_ENCRYPTION-KEY_PASS and $DATA_AUDIT_ENCRYPTION-IV_PASS
  if getPass "userland" "$DISCOVERY_INSTANCE_NAME" "encryption-key"; then
      INFO "Encryption key pass downloaded successfully"
      prefix=${DISCOVERY_INSTANCE_NAME//-/_}
      prefix=${prefix//./_}
      prefix=${prefix^^}
      MYVAR_USER=${prefix}_ENCRYPTION_KEY_USER
      MYVAR_PASS=${prefix}_ENCRYPTION_KEY_PASS
      echo ${!MYVAR_PASS} > /env_vars/DATA_AUDIT_ENCRYPTION_KEY_PASS
  else
      ERROR "Encryption key pass download failed"
      exit 1
  fi

  if getPass "userland" "$DISCOVERY_INSTANCE_NAME" "encryption-iv"; then
      INFO "Encryption IV pass downloaded successfully"
      prefix=${DISCOVERY_INSTANCE_NAME//-/_}
      prefix=${prefix//./_}
      prefix=${prefix^^}
      MYVAR_USER=${prefix}_ENCRYPTION_IV_USER
      MYVAR_PASS=${prefix}_ENCRYPTION_IV_PASS
      echo ${!MYVAR_PASS} > /env_vars/DATA_AUDIT_ENCRYPTION_IV_PASS
  else
      ERROR "Encryption IV pass download failed"
      exit 1
  fi
  INFO "Passwords to encrypt data audit: OK"
fi


