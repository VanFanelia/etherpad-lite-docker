#!/bin/bash
set -e

if [ "$1" = 'node' ]; then
	: ${ETHERPAD_DB_HOST:=mysql}
	: ${ETHERPAD_DB_PORT:=3306}
	: ${ETHERPAD_DB_USER:=root}
	: ${ETHERPAD_DB_NAME:=etherpad}
	: ${ETHERPAD_DB_CHARSET:=utf8mb4}
	ETHERPAD_DB_NAME=$( echo $ETHERPAD_DB_NAME | sed 's/\./_/g' )

	# ETHERPAD_DB_PASSWORD is mandatory in mysql container, so we're not offering
	# any default. If we're linked to MySQL through legacy link, then we can try
	# using the password from the env variable MYSQL_ENV_MYSQL_ROOT_PASSWORD
	if [ "$ETHERPAD_DB_USER" = 'root' ]; then
		: ${ETHERPAD_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
	fi

	if [ -z "$ETHERPAD_DB_PASSWORD" ]; then
		echo >&2 'error: missing required ETHERPAD_DB_PASSWORD environment variable'
		echo >&2 '  Did you forget to -e ETHERPAD_DB_PASSWORD=... ?'
		echo >&2
		echo >&2 '  (Also of interest might be ETHERPAD_DB_USER and ETHERPAD_DB_NAME.)'
		exit 1
	fi

	: ${ETHERPAD_TITLE:=Etherpad}
	: ${ETHERPAD_PORT:=9001}

	# Wait for database host to start up mysql
	while ! mysqlshow -h$ETHERPAD_DB_HOST -P$ETHERPAD_DB_PORT \
		-u"${ETHERPAD_DB_USER}" -p"${ETHERPAD_DB_PASSWORD}"
	do
		echo "$(date) - still trying connect to DBMS on "
		echo "$ETHERPAD_DB_HOST:$ETHERPAD_DB_PORT as user ${ETHERPAD_DB_USER}"
		sleep 1
	done

	# Check if database already exists
	RESULT=`mysql -u${ETHERPAD_DB_USER} -p${ETHERPAD_DB_PASSWORD} \
		-h${ETHERPAD_DB_HOST} -P${ETHERPAD_DB_PORT} --skip-column-names \
		-e "SHOW DATABASES LIKE '${ETHERPAD_DB_NAME}'"`

	if [ "$RESULT" != $ETHERPAD_DB_NAME ]; then
		# mysql database does not exist, create it
		echo "Creating database ${ETHERPAD_DB_NAME}"

		mysql -u${ETHERPAD_DB_USER} -p${ETHERPAD_DB_PASSWORD} -h${ETHERPAD_DB_HOST} \
		      -P${ETHERPAD_DB_PORT} -e "CREATE DATABASE ${ETHERPAD_DB_NAME} CHARACTER SET = '${ETHERPAD_DB_CHARSET}'"
	fi

	echo "Creating settings.json"
	env \
		ETHERPAD_DB_HOST="$ETHERPAD_DB_HOST" \
		ETHERPAD_DB_PORT="$ETHERPAD_DB_PORT" \
		ETHERPAD_DB_USER="$ETHERPAD_DB_USER" \
		ETHERPAD_DB_NAME="$ETHERPAD_DB_NAME" \
		ETHERPAD_TITLE="$ETHERPAD_TITLE" \
		ETHERPAD_PORT="$ETHERPAD_PORT" \
		ETHERPAD_DB_CHARSET="$ETHERPAD_DB_CHARSET" \
		ETHERPAD_USER_NAME="$ETHERPAD_USER_NAME" \
		ETHERPAD_USER_PASSWORD="$ETHERPAD_USER_PASSWORD" \
		node /settings-generator.js > settings.json

	if [ ! -f APIKEY.txt ]; then
		if (( ${#ETHERPAD_API_KEY} > 20 )); then
			echo "Writing API key"
			echo "$ETHERPAD_API_KEY" > APIKEY.txt
		fi
	fi
fi
exec "$@"

