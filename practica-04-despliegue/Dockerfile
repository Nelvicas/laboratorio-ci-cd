FROM php:8.3-cli

WORKDIR /app

COPY practica-04-despliegue/index.php .

CMD ["php", "-S", "0.0.0.0:8000", "-t", "/app"]