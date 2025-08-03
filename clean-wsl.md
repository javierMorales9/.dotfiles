# Limpieza del WSL (espacio en disco + compactación VHDX)

Guía práctica para pasar de un WSL “pesado” a uno ligero y **compactar el VHDX** para que ocupe **solo lo necesario**.

> **Resumen del flujo**
>
> 1. Auditar el espacio con `du`/`ncdu` → localizar dónde se va el tamaño.
> 2. Limpiar **Docker** (`/var/lib/docker`).
> 3. Vaciar **/tmp**.
> 4. En **\$HOME**, borrar `node_modules` de proyectos que ya no uses.
> 5. Limpiar **\$HOME/.cache** y **\$HOME/.npm**.
> 6. “Prune” de gestores: **npm**, **pip/poetry**, **conda** (y opcionales yarn/pnpm).
> 7. **Compactar el VHDX** con `diskpart` (Windows) tras `fstrim` y `wsl --shutdown`.

---

## 1) Audita el uso de disco con `du` / `ncdu`

> Objetivo: ver rápido **qué directorios** concentran el espacio. En WSL usa siempre la opción `-x` para no cruzar a otros sistemas de archivos montados (como `/mnt/c`).

**Opción interactiva (recomendada):**

```bash
# Instala ncdu si no lo tienes
sudo apt-get update && sudo apt-get install -y ncdu

# Audita todo el rootfs de la distro (sin cruzar montajes)
sudo ncdu -x /
```

**Opción no interactiva con du:**

```bash
# Top-level del rootfs
sudo du -xh -d1 / | sort -h

# Carpeta del usuario
du -xh -d1 "$HOME" | sort -h

# Los subárboles típicos que más pesan
sudo du -xh -d1 /var | sort -h
sudo du -xh -d1 /var/lib | sort -h
sudo du -xh -d1 /var/lib/docker | sort -h
```

**Comprobación de raíz de Docker (por si fuese distinta):**

```bash
docker info --format 'Docker Root Dir: {{.DockerRootDir}}'
```

---

## 2) Limpia Docker (`/var/lib/docker`)

> Orden recomendado: **Buildx/BuildKit → imágenes → contenedores → volúmenes**. Después, repasa logs grandes.

### 2.1 Buildx / BuildKit

```bash
# (A) Prune de caché de buildkit (builder actual)
docker builder prune --all --force
# Opcionales:
#   --keep-storage 10GB   # conserva hasta 10 GB de cache
#   --filter "until=240h" # sólo mayor de 10 días

# (B) Equivalente con buildx (por compatibilidad)
docker buildx prune --all --force

# (C) Remueve builders inactivos (driver docker-container) que dejan volúmenes de estado
#    ⚠️ Mantiene el builder "default" (driver docker)
for b in $(docker buildx ls | awk '/inactive/ {print $1}' | sed 's/\*$//'); do
  docker buildx rm "$b" || true
done

# (D) Volúmenes huérfanos de buildx (si quedaron)
for v in $(docker volume ls -q | grep -E '^buildx_buildkit_.*_state$'); do
  if ! docker ps -a --filter volume="$v" --format '{{.ID}}' | grep -q .; then
    docker volume rm "$v"
  fi
done
```

### 2.2 Imágenes, contenedores y redes no usados

```bash
# Imágenes sin etiqueta (dangling)
docker image prune -f

# Contenedores parados
docker container prune -f

# Redes que no usa nadie
docker network prune -f

# (Opcional, agresivo) Imágenes no usadas por ningún contenedor
# ⚠️ Puede borrar imágenes con etiqueta que luego habrá que re-descargar
docker image prune -a -f

# (Opcional, todo junto y agresivo)
# ⚠️ -a borra imágenes no usadas; --volumes borra volúmenes no referenciados
docker system prune -a --volumes -f
```

### 2.3 Volúmenes dangling (no referenciados)

```bash
# Limpieza básica
docker volume prune -f

# Si persisten volúmenes "dangling", elimínalos explícitamente
for v in $(docker volume ls -qf dangling=true); do
  if ! docker ps -a --filter volume="$v" --format '{{.ID}}' | grep -q .; then
    docker volume rm "$v" || true
  fi
done

# Top 20 volúmenes por tamaño (para localizar gordos)
sudo sh -c 'du -m $(docker info --format {{.DockerRootDir}})/volumes/*/_data 2>/dev/null' | sort -n | tail -n 20
```

### 2.4 Logs de contenedores muy grandes (opcional)

```bash
# Localiza logs JSON enormes
sudo find /var/lib/docker/containers -name '*-json.log' -size +200M -printf '%p\t%k KB\n'

# Truncar un log concreto (no borra el contenedor)
# ⚠️ Reemplaza la ruta por la que corresponda
sudo sh -c '> /var/lib/docker/containers/<ID>/<ID>-json.log'
```

---

## 3) Vacía `/tmp`

> Espacio temporal. Borrarlo es seguro; hazlo cuando no estés usando procesos que escriban en `/tmp`.

```bash
# Ver qué hay (opcional)
sudo find /tmp -xdev -mindepth 1 -maxdepth 1 -printf '%p\n' | head -n 50

# Borrar todo el contenido de /tmp (no el directorio en sí)
sudo find /tmp -xdev -mindepth 1 -print -exec rm -rf -- {} +

# (Opcional) sólo ficheros/dirs más antiguos de N días (ej. 3 días)
sudo find /tmp -xdev -mindepth 1 -mtime +3 -print -exec rm -rf -- {} +
```

---

## 4) En \$HOME: borra `node_modules` de proyectos que ya no uses

> `node_modules` puede crecer **mucho** por proyecto. Borrarlo es seguro: se regenera con `npm ci`/`npm install` cuando lo vuelvas a necesitar.

**Listar los `node_modules` más pesados en tu home o workspace:**

```bash
# Cambia ~/work por tu carpeta de proyectos si procede
BASE=~
# BASE=~/work
find "$BASE" -type d -name node_modules -prune -print0 \
  | xargs -0 du -sh 2>/dev/null \
  | sort -h | tail -n 30
```

**Eliminar selectivamente los que ya no uses:**

```bash
# ⚠️ Revisa primero la lista anterior y borra a mano los que no necesites
rm -rf /ruta/a/tu/proyecto-antiguo/node_modules
```

**Borrado por patrón (con confirmación manual):**

```bash
# Imprime los candidatos sin borrar
echo "Candidatos:" && find "$BASE" -type d -name node_modules -prune -print
# Cuando estés seguro, borra los que indiques
# (o combina con grep para filtrar por nombre de proyecto)
```

> Tip en repos Git: si quieres una limpieza profunda de archivos ignorados (incluye `node_modules/`), dentro del repo:
> `git clean -fdX` → borra **solo** lo que está en `.gitignore`.
> `git clean -fdx` → borra **todo lo ignorado y sin trackear** (más agresivo).
> **Cuidado:** revisar con `git clean -n` primero (dry-run).

---

## 5) Limpia `$HOME/.cache` y `$HOME/.npm`

**.cache (genérico):**

```bash
# Revisión rápida
du -xh -d1 ~/.cache | sort -h
# Borrado directo (se recrea solo)
rm -rf ~/.cache/*
```

**.npm (caché de npm):**

```bash
npm cache verify         # opcional
npm cache clean --force  # purga toda la caché (~/.npm)
```

**(Opcionales si los usas)**

```bash
# yarn
yarn cache clean
# pnpm
pnpm store prune
```

---

## 6) “Prune” de gestores: npm, pip/poetry, conda (y opcionales)

> Aquí no eliminamos tus proyectos, solo **cachés** y **artefactos** que se regeneran.

**npm (por proyecto):**

```bash
# Dentro de un proyecto Node, elimina dependencias "extraneous" (no listadas en package.json)
npm prune
# (Opcional) deduplica dependencias
npm dedupe
```

**pip (global del usuario):**

```bash
pip cache dir     # ver ubicación
pip cache purge   # purgar caché de paquetes
```

**Poetry:**

```bash
# Limpiar cachés de índices y paquetes
poetry cache clear pypi --all -n
# Si usas virtualenvs de Poetry y quieres regenerarlos, puedes limpiar su caché
poetry cache clear virtualenvs --all -n  # (opcional)
```

**Conda:**

```bash
# Limpieza de tarballs, paquetes no usados, caches, etc.
conda clean --all -y
# (Opcional) elimina entornos que ya no uses
conda env list
conda env remove -n <nombre_del_entorno>
```

**Extras útiles (opcionales):**

```bash
# Go: limpia la caché de módulos
go clean -modcache
# Rust: limpia registros/git del cargo (se regeneran)
rm -rf ~/.cargo/registry ~/.cargo/git
```

---

## 7) Compacta el VHDX para recuperar espacio en Windows (método universal: `diskpart`)

> Esto reduce físicamente el archivo `ext4.vhdx` para que **refleje** el nuevo uso real (tras las limpiezas).

**Paso 7.1 — Marca bloques libres (TRIM) dentro de WSL**

```bash
sudo fstrim -av
```

**Paso 7.2 — Apaga WSL (y Docker Desktop si lo usas con backend WSL)**

```powershell
wsl --shutdown
```

**Paso 7.3 — Compacta el VHDX con `diskpart` (PowerShell como Administrador)**

```powershell
# 1) Localiza el VHDX de tu distro (algunas rutas típicas):
#    C:\Users\<TU_USUARIO>\AppData\Local\Packages\CanonicalGroupLimited...\LocalState\ext4.vhdx
#    o usa:
Get-ChildItem "$env:LOCALAPPDATA\Packages\*\LocalState\ext4.vhdx" -Recurse -ErrorAction SilentlyContinue

# 2) Compacta con diskpart (sustituye la ruta exacta)
diskpart
select vdisk file="C:\\RUTA\\A\\ext4.vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
```

**(Opcional) Compacta también el VHDX de Docker Desktop**

```powershell
# Ruta típica del VHDX de Docker Desktop (WSL backend)
$dockerVhd = "$Env:LocalAppData\Docker\wsl\data\ext4.vhdx"
if (Test-Path $dockerVhd) {
  diskpart
  select vdisk file="$dockerVhd"
  attach vdisk readonly
  compact vdisk
  detach vdisk
  exit
}
```

**Paso 7.4 — Verifica y arranca de nuevo**

```powershell
# Compara el tamaño del archivo VHDX antes/después en el Explorador
wsl   # vuelve a iniciar la distro
```

> **Notas**
>
> * Si tienes el módulo **Hyper-V** y prefieres `Optimize-VHD`, también sirve:
>   `Optimize-VHD -Path "C:\ruta\ext4.vhdx" -Mode Full`  (PowerShell Admin).
>   Pero `diskpart` funciona en Home/Pro sin Hyper-V.
> * En versiones recientes de WSL existe `wsl --manage <Distro> --set-sparse true` para VHDX “sparse”; si tu WSL no lo soporta, no pasa nada: `diskpart` sigue siendo el método universal.

---

## Checklist rápido

* [ ] `ncdu -x /` y notas de qué pesa más.
* [ ] Limpieza de Docker (Buildx → imágenes → contenedores → volúmenes → logs).
* [ ] Vaciar `/tmp`.
* [ ] Borrar `node_modules` de proyectos antiguos.
* [ ] Limpiar `~/.cache` y `~/.npm` (y opcional: yarn/pnpm).
* [ ] Prune de npm/pip/poetry/conda (y opcional: Go/Rust).
* [ ] `fstrim -av` → `wsl --shutdown` → `diskpart` (compact vdisk) → comprobar tamaño.

---

### Troubleshooting rápido

* **`docker volume prune` no borra volúmenes:** intenta borrado explícito por ID y confirma que ningún contenedor (aunque esté parado) lo referencia: `docker ps -a --filter volume=<VOL>`.
* **Permisos al listar tamaños en `/var/lib/docker/volumes`**: usa `sudo`.
* **Compactación no reduce mucho:** asegúrate de haber hecho `fstrim -av` antes de `wsl --shutdown`, y repite `compact vdisk`. Si sigue igual, verifica que compactaste **el VHDX correcto**.

