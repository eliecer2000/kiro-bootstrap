# Orbit Bootstrap Flow

1. Orbit pregunta si deseas preparar el entorno.
2. Si el contexto esta en `HOME`, ofrece crear una carpeta de proyecto una vez por sesion.
3. Detecta perfiles activos; si no puede decidir, usa el wizard AWS-first.
4. Valida el entorno del perfil.
5. Carga agentes, steering, skills locales y hooks del perfil.
6. Propone e instala skills remotas solo con confirmacion.
7. Instala extensiones recomendadas.
8. Escribe `.kiro/.orbit-project.json`.

Para resincronizar manualmente:

```bash
~/.kiro/orbit/install.sh --resync-project .
```
