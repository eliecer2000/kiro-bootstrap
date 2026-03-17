---
inclusion: always
---

# Bootstrap Init – Pipeline de Configuración de Jarvis

Este steering file define el comportamiento del agente Jarvis durante el pipeline de bootstrap.
Se ejecuta automáticamente al inicio de cada sesión de Kiro.

## Pipeline de Configuración

El pipeline se ejecuta en 3 pasos secuenciales definidos en `~/.kiro/kiro-bootstrap/manifest.json`.
Solo se ejecutan los pasos con `enabled: true`, en el orden definido por el campo `order`.
Si un paso falla, se registra el error y se continúa con el siguiente paso.

### Paso 1: Detección de Perfil de Proyecto

1. Leer las reglas de detección desde `manifest.json` → `profiles.{perfil}.detection`.
2. Analizar los archivos del directorio raíz del proyecto en orden de prioridad:

| Prioridad | Archivos indicadores                                            | Perfil                      |
| --------- | --------------------------------------------------------------- | --------------------------- |
| 1         | `nuxt.config.ts` + dependencia `nuxt` en `package.json`         | `frontend-nuxt`             |
| 2         | Archivos `*.tf` + `backend.tf`                                  | `infraestructura-terraform` |
| 3         | Dependencia `@aws-sdk/*` en `package.json` sin `nuxt.config.ts` | `backend-lambda`            |
| 4         | `pyproject.toml` o `requirements.txt`                           | `backend-python`            |

3. Si se detecta exactamente un perfil, continuar al paso 2.
4. Si se detectan múltiples perfiles (monorepo), aplicar el manejo de ambigüedad (ver sección abajo).
5. Si no se detecta ningún perfil, aplicar el manejo de ambigüedad.

### Paso 2: Validación de Entorno

1. Leer las validaciones del perfil detectado desde `manifest.json` → `profiles.{perfil}.validations`.
2. Para cada herramienta requerida:
   - Verificar presencia en el PATH del sistema.
   - Si está presente, verificar que la versión instalada cumple con `minVersion` (comparación semántica major.minor.patch).
   - Si no está presente, registrar como fallido e incluir el `installHint`.
3. Si el perfil tiene `envCheck.required: true`, verificar la existencia de los archivos `.env` y las variables requeridas.
4. Si el perfil tiene `awsCheck: true`, ejecutar `aws sts get-caller-identity` para verificar la sesión AWS.
5. Generar reporte con estado por verificación: aprobado, advertencia o fallido.

### Paso 3: Carga de Artefactos

1. Leer el registro de agentes desde `~/.kiro/kiro-bootstrap/agents-registry.json`.
2. Filtrar los agentes compatibles con el perfil detectado (campo `profiles` del agente contiene el perfil o `"*"`).
3. Para cada agente compatible:
   - Copiar el archivo del agente a `.kiro/agents/`.
   - Copiar los steering files asociados a `.kiro/steering/`.
   - Copiar las skills referenciadas a `.kiro/skills/`.
4. Copiar los `globalSteeringFiles` con `inclusion: always` independientemente del perfil.
5. Antes de copiar cada artefacto:
   - Si el archivo local es idéntico al central, omitir y reportar como "sin cambios".
   - Si el archivo local difiere, preguntar al usuario si desea sobrescribir, conservar la versión local o ver las diferencias.

## Manejo de Ambigüedad

Cuando no se puede determinar el perfil automáticamente, MUST presentar opciones al usuario usando `userInput`.

### Caso: Ningún perfil detectado

Usar `userInput` con el siguiente formato:

```
Pregunta: "No se detectó un perfil de proyecto automáticamente. ¿Qué tipo de proyecto es?"
Opciones:
  - "Frontend Nuxt" — Proyecto frontend con Nuxt 4, Vue 3, PrimeVue, Tailwind
  - "Infraestructura Terraform" — Proyecto de infraestructura como código con Terraform
  - "Backend Lambda" — Proyecto backend serverless con AWS Lambda y TypeScript
  - "Backend Python" — Proyecto backend con Python
```

### Caso: Múltiples perfiles detectados (monorepo)

Usar `userInput` con el siguiente formato:

```
Pregunta: "Se detectaron múltiples perfiles en este proyecto. ¿Cuál deseas configurar?"
Opciones: [lista de perfiles detectados con su descripción del manifiesto]
```

## Formato del Resumen

Al finalizar el pipeline, MUST mostrar un resumen en español con el siguiente formato:

```
✅ Bootstrap completado — Perfil: {nombre del perfil}

📦 Artefactos cargados:
  - Agentes: {lista de nombres de agentes}
  - Steering files: {lista de archivos steering}
  - Skills: {lista de skills}

🔍 Validación de entorno:
  - {herramienta}: {estado} ({versión instalada})
  - ...

⚠️ Advertencias: {lista de advertencias, si las hay}
```

Si algún paso falló, incluir la sección:

```
❌ Pasos con error:
  - {nombre del paso}: {mensaje de error}
```
