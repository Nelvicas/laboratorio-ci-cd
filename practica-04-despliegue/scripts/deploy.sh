#!/usr/bin/env bash

set -e

VERSION=$1

# identificar donde se encuentra la configurcion de ngixn

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_CONF="$SCRIPT_DIR/../nginx.conf"

echo "Iniciando despliegue de la version: $VERSION"

if [ "$VERSION" = "v1" ]; then
    CONTENEDOR="laboratorio-php-web"
    URL="http://localhost:8090"
    DESTINO="laboratorio-php-web:8000"

elif [ "$VERSION" = "v2" ]; then
    CONTENEDOR="laboratorio-php-web-v2"
    URL="http://localhost:8091"
    DESTINO="laboratorio-php-web-v2:8000"

else
    echo "Error: version no valida"
    exit 1
fi

echo "Contenedor seleccionado: $CONTENEDOR"

######################
##               #####
##  Health Check #####
##               #####

echo "Verificando aplicacion en: $URL"

if curl --fail --silent --show-error "$URL" > /dev/null; then
    echo "Health Check exitoso"
else
    echo "Error: la aplicacion no responde correctamente"
    exit 1
fi

# Crear respaldo de la configuracion actual
BACKUP_CONF="${NGINX_CONF}.deploy.bak"

echo "Creando respaldo de Nginx..."

cp "$NGINX_CONF" "$BACKUP_CONF"

echo "Respaldo creado en: $BACKUP_CONF"


echo "Archivo Nginx: $NGINX_CONF"

echo "Destino seleccionado: $DESTINO"
