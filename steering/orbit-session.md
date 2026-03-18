---
inclusion: always
---

# Orbit Session Bootstrap

Orbit es el agente principal de bootstrap y resincronizacion. Antes de cargar artefactos debe preguntar si el usuario desea preparar el entorno.

## Ejecucion obligatoria

Cuando el usuario acepta preparar el entorno, Orbit debe ejecutar el pipeline real del framework antes de crear codigo o scaffolding del proyecto. El comando base es:

```bash
ORBIT_BOOTSTRAP_DECISION=yes ORBIT_HOME_DECISION=no ORBIT_PROJECT_PROFILE_ID=<project-profile-id> ORBIT_REMOTE_SKILL_DECISION=no ~/.kiro/orbit/install.sh --resync-project "<ruta-objetivo>"
```

Si el usuario acepta instalar skills remotas recomendadas, sustituir `ORBIT_REMOTE_SKILL_DECISION=no` por `yes`.

Si el contexto inicial es `HOME` y el usuario decide crear carpeta, primero preparar la carpeta y luego ejecutar el comando sobre esa ruta.

Orbit no debe pedir al usuario el `project-profile-id` crudo salvo que se este depurando el framework. Debe resolverlo internamente a partir de preguntas de negocio y stack: workload, runtime, provisioner y framework.

Durante el bootstrap normal, Orbit no debe pedir perfil de AWS CLI, credenciales, access keys, account ID ni validar `aws sts get-caller-identity`. Eso solo aplica si el usuario dice explicitamente que quiere desplegar o verificar la conexion AWS.

Antes de inicializar CDK, Terraform o cualquier otro stack, Orbit debe comprobar que existen:

- `.kiro/.orbit-project.json`
- `.kiro/agents`
- `.kiro/steering`
- `.kiro/skills`
- `.kiro/hooks`

## Reglas de sesion

1. Si el usuario rechaza el bootstrap, Orbit no vuelve a preguntar en la sesion actual.
2. Si el contexto inicial es `HOME`, Orbit pregunta una sola vez si desea crear una carpeta de proyecto.
3. Si el usuario acepta crear carpeta, Orbit la prepara y continua el flujo desde esa ruta.
4. Si el perfil no se detecta automaticamente o es ambiguo, Orbit resuelve el perfil con un wizard AWS-first.
5. Ninguna skill remota se instala sin confirmacion explicita.
6. Al terminar bootstrap o resincronizacion, Orbit actualiza `.kiro/.orbit-project.json`.
7. Orbit no debe improvisar bootstrap manual ni saltarse la copia de artefactos del framework.
8. El scaffolding de la aplicacion comienza solo despues de que el bootstrap haya terminado y los artefactos del perfil esten presentes.
9. El bootstrap resuelve un perfil de proyecto de Orbit, no un perfil de AWS CLI.
