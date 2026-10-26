<?php

require_once __DIR__ . '/calculadora.php';

$resultado = sumar(5, 3);

if ($resultado === 8) {
    echo "PRUEBA EXITOSA: 5 + 3 = 8\n";
    exit(0);
}

echo "PRUEBA FALLIDA: se esperaba 8, pero se obtuvo $resultado\n";
exit(1);