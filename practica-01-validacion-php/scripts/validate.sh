#!/bin/bash

set -e

echo "Iniciando validación de código PHP..."

php -l index.php

echo "Validación completada correctamente."
