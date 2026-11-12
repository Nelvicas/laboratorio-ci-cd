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


# Verificar que exista un unico proxy_pass
TOTAL_PROXY=$(grep -Ec '^[[:space:]]*proxy_pass[[:space:]]+http://' "$NGINX_CONF" || true)

if [ "$TOTAL_PROXY" -ne 1 ]; then
    echo "ERROR: se esperaba un unico proxy_pass y se encontraron $TOTAL_PROXY"
    exit 1
fi

echo "Configuracion verificada: un unico proxy_pass"



# Crear respaldo de la configuracion actual
BACKUP_CONF="${NGINX_CONF}.deploy.bak"

echo "Creando respaldo de Nginx..."

cp "$NGINX_CONF" "$BACKUP_CONF"

echo "Respaldo creado en: $BACKUP_CONF"


# Preparar nueva configuracion de Nginx
TEMP_CONF="${NGINX_CONF}.tmp"

echo "Preparando configuracion para: $DESTINO"

sed "s|proxy_pass http://[^;]*;|proxy_pass http://$DESTINO;|" \
    "$NGINX_CONF" > "$TEMP_CONF"

echo "Configuracion preparada:"
grep proxy_pass "$TEMP_CONF"


# Validar la configuracion temporal de Nginx
echo "Validando configuracion temporal de Nginx..."

if docker run --rm \
    --network laboratorio-deploy-net \
    --entrypoint nginx \
    -v "$TEMP_CONF:/etc/nginx/conf.d/default.conf:ro" \
    nginx:stable-alpine -t; then

    echo "Validacion de Nginx exitosa"

else
    echo "ERROR: configuracion de Nginx invalida"
    echo "Despliegue cancelado"
    exit 1
fi




# Aplicar la nueva configuracion
echo "Aplicando configuracion de Nginx..."

cp "$TEMP_CONF" "$NGINX_CONF"



# Validar la configuracion activa
if ! docker exec laboratorio-nginx-proxy nginx -t; then
    echo "ERROR: configuracion activa invalida"
    echo "Restaurando configuracion anterior..."

    cp "$BACKUP_CONF" "$NGINX_CONF"

    if docker exec laboratorio-nginx-proxy nginx -t; then
        docker exec laboratorio-nginx-proxy nginx -s reload || \
            echo "ERROR: no se pudo recargar Nginx"
    else
        echo "ERROR CRITICO: respaldo invalido"
    fi

    exit 1
fi



# Recargar Nginx
if ! docker exec laboratorio-nginx-proxy nginx -s reload; then
    echo "ERROR: fallo la recarga de Nginx"
    cp "$BACKUP_CONF" "$NGINX_CONF"
    docker exec laboratorio-nginx-proxy nginx -s reload
    exit 1
fi

echo "Nginx recargado correctamente"





# Verificar que Nginx responde con la version esperada
echo "Verificando despliegue mediante Nginx..."

RESPUESTA_ESPERADA=""

if [ "$VERSION" = "v1" ]; then
    RESPUESTA_ESPERADA="Esta es la version 2 de mi aplicacion PHP en Docker!"
else
    RESPUESTA_ESPERADA="Aplicacion PHP desplegada correctamente - Version 2"
fi

# Verificar el despliegue con varios intentos
DESPLIEGUE_OK=false

for INTENTO in 1 2 3 4 5; do

    echo "Intento de verificacion: $INTENTO"

    RESPUESTA=$(curl --fail --silent --show-error \
        --max-time 3 \
        http://localhost:8092) || RESPUESTA=""

    if [ "$RESPUESTA" = "$RESPUESTA_ESPERADA" ]; then
        DESPLIEGUE_OK=true
        break
    fi

    echo "Respuesta recibida: $RESPUESTA"
    sleep 2
done

if [ "$DESPLIEGUE_OK" = true ]; then
    echo "Despliegue exitoso: $VERSION"
else
    echo "ERROR: el proxy no responde con la version esperada"
    echo "Iniciando rollback..."

    cp "$BACKUP_CONF" "$NGINX_CONF"

    if docker exec laboratorio-nginx-proxy nginx -t &&
       docker exec laboratorio-nginx-proxy nginx -s reload; then
        echo "Configuracion anterior restaurada"
    else
        echo "ERROR CRITICO: revisar Nginx manualmente"
    fi

    exit 1
fi



echo "Archivo Nginx: $NGINX_CONF"

echo "Destino seleccionado: $DESTINO"
