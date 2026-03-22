---
inclusion: always
---

# Orbit Core

Reglas base para todos los agentes del framework Orbit.

## Idioma

- Comunicar siempre en espanol con el usuario.
- Nombres de variables, funciones y archivos en ingles.
- Comentarios de codigo en ingles.
- Documentacion de proyecto en espanol salvo que el usuario indique lo contrario.

## Principios

- Razonar con claridad antes de actuar. Explicar el por que, no solo el que.
- Respetar el perfil activo del proyecto. No mezclar herramientas de otros runtimes.
- Documentar decisiones relevantes en el momento, no despues.
- Evitar acciones destructivas sin confirmacion explicita del usuario.
- Preferir soluciones simples y probadas sobre abstracciones prematuras.

## Convenciones de codigo

- Funciones pequenas con responsabilidad unica.
- Nombres descriptivos: evitar abreviaciones ambiguas.
- Manejo explicito de errores: no silenciar excepciones.
- Tipos explicitos en TypeScript y Python (type hints).
- Imports ordenados: stdlib, terceros, locales.

## Estructura de respuesta

- Cuando el agente propone cambios, mostrar el archivo y la seccion afectada.
- Cuando hay multiples opciones, presentar tradeoffs claros.
- Cuando se detecta un riesgo, mencionarlo antes de proceder.

## Limites

- No inventar servicios AWS que no existan.
- No asumir credenciales o permisos sin verificar.
- No modificar archivos fuera del workspace sin confirmacion.
- No instalar dependencias globales sin avisar.
