# Notas sobre la generación de temas

## Archivos `_base` y la directiva `include`

Cada tema generado en `vsDark/` y `GitHubDark/` incluye en su JSON la línea:

```json
"include": "./../../_base/__dark-plus.json"
// o
"include": "./../../_base/__github-dark.json"
```

Esto hace que el tema herede **todos** los colores y tokens del tema base. Para que funcione, los archivos `_base/__dark-plus.json` y `_base/__github-dark.json` deben existir en la carpeta raíz.

**Alternativa sin `_base`:** Si se elimina el campo `include` del JSON del tema, VS Code no hereda nada automáticamente desde un archivo local. En ese caso, el comportamiento del editor/terminal/etc. queda determinado únicamente por el `"workbench.colorTheme"` especificado en el `.code-workspace`. Como los workspaces ya tienen ese campo configurado correctamente (`"forest (Dark+)"` o `"forest (GitHub Dark)"`), el tema base se aplica igual y las customizaciones del JSON del tema solo sobreescriben el chrome de VS Code.

## Las 4 customizaciones opcionales de color

Solo se aplican si el valor en `temas.xml` es un color hex válido (`#RRGGBB`). Si el campo está vacío o tiene otro formato, se usa el default del tema base.

| Campo XML | Qué customiza |
|-----------|--------------|
| `sintaxis` | Keywords, storage types, modificadores (`keyword`, `storage.type`, etc.) |
| `literal`  | Strings y literales (`string`, `string.quoted`, etc.) |
| `diff1`    | Líneas **eliminadas** en diff editor (`diffEditor.removedLine*`) |
| `diff2`    | Líneas **agregadas** en diff editor (`diffEditor.insertedLine*`) |

Los temas `autumn` y `winter` no tienen valores para estas 4 propiedades, por lo que usan el 100% del default del tema base.

## Dónde viven los archivos

- `vsDark/<tema>-vscode-theme-1.0.0/` — extensión de tema para Dark+
- `GitHubDark/<tema>-vscode-theme-1.0.0/` — extensión de tema para GitHub Dark
- `.config/<tema>.dark.code-workspace` — workspace apuntando al tema Dark+
- `.config/<tema>.github.code-workspace` — workspace apuntando al tema GitHub Dark

## Regenerar

Para regenerar todos los temas y workspaces desde `temas.xml`:

```powershell
pwsh -NoProfile -File generate-themes.ps1
```
