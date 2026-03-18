# Orbit Bootstrap Flow

1. Orbit pregunta si deseas preparar el entorno.
2. Si el contexto esta en `HOME`, ofrece crear una carpeta de proyecto una vez por sesion.
3. Detecta perfiles activos; si no puede decidir, usa el wizard AWS-first.
4. Valida el entorno del perfil.
5. Carga agentes, steering, skills locales y hooks del perfil.
6. Propone e instala skills remotas solo con confirmacion.
7. Instala extensiones recomendadas.
8. Escribe `.kiro/.orbit-project.json`.

Cuando Orbit opera desde el chat de Kiro, primero debe ejecutar el pipeline real del framework:

```bash
ORBIT_BOOTSTRAP_DECISION=yes ORBIT_HOME_DECISION=no ORBIT_PROJECT_PROFILE_ID=<project-profile-id> ORBIT_REMOTE_SKILL_DECISION=no ~/.kiro/orbit/install.sh --resync-project "<ruta>"
```

Solo despues de verificar `.kiro/.orbit-project.json`, `.kiro/agents`, `.kiro/steering`, `.kiro/skills` y `.kiro/hooks` puede iniciar scaffolding del stack.

Ese `project-profile-id` se resuelve internamente desde el tipo de proyecto. Orbit no debe pedir al usuario el ID crudo del catalogo, ni tampoco perfiles o credenciales AWS durante el bootstrap normal. La validacion de identidad AWS queda diferida hasta despliegue o verificacion explicita.

Para resincronizar manualmente:

```bash
~/.kiro/orbit/install.sh --resync-project .
```
