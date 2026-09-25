# Security Audit Script

Auditoría básica de seguridad local para sistemas **Ubuntu/Debian**.

El script `security_audit.sh` recopila información del sistema, revisa servicios y puertos, valida controles de seguridad y ejecuta herramientas de auditoría defensiva. Los resultados se guardan en un archivo de log para facilitar su revisión posterior.

> **Aviso:** Este proyecto es una herramienta de revisión defensiva y hardening. No reemplaza un pentest profesional, una evaluación de compromiso, un EDR ni un análisis forense.

---

## Características

El script realiza las siguientes tareas:

- Validación de privilegios `sudo`.
- Actualización de los índices de paquetes APT.
- Instalación condicional de herramientas de auditoría.
- Identificación del sistema operativo y kernel.
- Recopilación de información del usuario y tiempo de actividad.
- Enumeración de puertos TCP/UDP en escucha.
- Revisión de servicios mediante `systemctl`.
- Consulta del estado del firewall UFW.
- Ejecución de Rootkit Hunter (`rkhunter`).
- Ejecución de Lynis.
- Revisión de AppArmor.
- Revisión de `auditd` y eventos recientes.
- Comprobación de integridad de paquetes mediante `debsums`.
- Verificación del estado de AIDE.
- Revisión de actualizaciones automáticas.
- Generación de logs con marca de tiempo.

---

## Requisitos

- Ubuntu o Debian.
- Acceso a una cuenta con privilegios `sudo`.
- Conexión a Internet para instalar paquetes y actualizar repositorios.
- Bash.
- Paquetes base como:
  - `apt`
  - `systemctl`
  - `ss`
  - `iproute2`
  - `curl`

El script puede instalar automáticamente algunas herramientas que no estén presentes.

---

## Herramientas utilizadas

Dependiendo del estado del sistema, el script puede instalar o comprobar:

- `rkhunter`
- `lynis`
- `ufw`
- `auditd`
- `audispd-plugins`
- `aide`
- `debsums`
- `unattended-upgrades`
- `apt-listchanges`
- `iproute2`
- `curl`

### Consideración sobre dependencias

Algunas herramientas pueden instalar dependencias adicionales, como Ruby, `bsd-mailx` u otros paquetes auxiliares. Por ejemplo, `rkhunter` puede instalar componentes relacionados con correo para generar notificaciones, aunque el script no pretende configurar un servidor de correo.

**Postfix no es necesario para ejecutar una auditoría local básica.** Si aparece una pantalla de configuración de correo, revisa qué paquete la está solicitando antes de continuar.

---

## Instalación

Clona o copia el script en tu equipo y entra en el directorio correspondiente:

```bash
cd ~/Escritorio/scriptsPersonales
```

Concede permisos de ejecución:

```bash
chmod +x security_audit.sh
```

---

## Ejecución

Ejecuta el script desde la terminal:

```bash
./security_audit.sh
```

El script solicitará la contraseña de `sudo` cuando sea necesario.

También puedes ejecutarlo usando Bash:

```bash
bash security_audit.sh
```

---

## Ubicación de los logs

Los resultados se almacenan en:

```text
~/security-audit-logs/
```

Ejemplo:

```text
~/security-audit-logs/audit_20260925_014806.log
```

Para listar los informes:

```bash
ls -lh ~/security-audit-logs/
```

Para leer un log:

```bash
less -f ~/security-audit-logs/audit_*.log
```

Si el log contiene códigos de color ANSI, puedes limpiarlos visualmente con:

```bash
sed -E 's/\x1B\[[0-9;]*[mK]//g' \
~/security-audit-logs/audit_20260925_014806.log | less
```

Para revisar errores y advertencias:

```bash
grep -aEi 'warning|failed|error|critical|vulnerab|suggestion' \
~/security-audit-logs/audit_20260925_014806.log
```

Para consultar las últimas líneas:

```bash
tail -n 80 ~/security-audit-logs/audit_20260925_014806.log
```

---

## Interpretación de resultados

Los resultados deben analizarse considerando el contexto del equipo.

### `rkhunter`

Puede reportar advertencias por:

- Cambios legítimos en archivos.
- Herramientas de administración.
- Características del sistema.
- Firmas o comprobaciones que requieren validación manual.

No se debe ejecutar automáticamente:

```bash
sudo rkhunter --propupd
```

antes de revisar las advertencias. Ese comando actualiza la base de referencia y podría ocultar cambios que deberían investigarse.

### `lynis`

Lynis genera advertencias y sugerencias de hardening. No todas las recomendaciones son obligatorias ni aplican a todos los equipos.

Antes de aplicar una recomendación, evalúa:

- Impacto en el sistema.
- Compatibilidad con VMware y herramientas de laboratorio.
- Necesidades de desarrollo y pentesting.
- Posibles efectos sobre red, autenticación o rendimiento.

### `auditd`

`auditd` registra eventos del sistema de acuerdo con las reglas configuradas. La ausencia de eventos no demuestra que no haya actividad maliciosa.

### `debsums`

Comprueba la integridad de archivos administrados por paquetes Debian. No detecta todos los tipos de compromiso, especialmente cambios fuera del alcance de los paquetes o amenazas que no modifican archivos verificados.

### `AIDE`

AIDE requiere una base de referencia confiable para comparar cambios. La instalación del paquete no equivale necesariamente a una inicialización y validación completa de la base de datos.

---

## Alcance y limitaciones

Este script:

- Realiza comprobaciones locales.
- Recopila información del sistema.
- Ejecuta herramientas defensivas.
- Guarda evidencia en archivos de log.

Este script no:

- Realiza explotación de vulnerabilidades.
- Ejecuta pruebas de escalamiento de privilegios.
- Realiza ataques contra Active Directory.
- Analiza automáticamente aplicaciones web.
- Ejecuta escaneos ofensivos sobre otros equipos.
- Valida la seguridad de AWS, Azure o Google Cloud.
- Sustituye un EDR, SIEM o plataforma de threat hunting.
- Garantiza que el sistema esté libre de malware.
- Aplica automáticamente todas las recomendaciones de hardening.

---

## Buenas prácticas

1. Ejecutar el script desde una cuenta de administración controlada.
2. Revisar los logs después de cada ejecución.
3. Guardar los informes en una ubicación protegida.
4. No compartir logs públicamente sin eliminar:
   - Direcciones IP.
   - Nombres de usuario.
   - Rutas internas.
   - Nombres de equipos.
   - Información de red.
5. Validar manualmente cada advertencia.
6. Crear una línea base inicial en un sistema confiable.
7. Comparar los resultados de ejecuciones posteriores.
8. No ejecutar comandos correctivos de forma automática sin comprender su impacto.
9. Revisar los servicios instalados y eliminar los que no sean necesarios.
10. Mantener Ubuntu y las herramientas actualizadas.

---

## Revisión rápida posterior a la auditoría

Comprobar el estado de APT:

```bash
sudo apt-get check
```

Comprobar servicios en escucha:

```bash
sudo ss -tulpen
```

Consultar el estado de UFW:

```bash
sudo ufw status verbose
```

Consultar AppArmor:

```bash
sudo aa-status
```

Consultar servicios activos:

```bash
systemctl --type=service --state=running
```

Consultar el estado de `auditd`:

```bash
sudo systemctl status auditd --no-pager
```

---

## Recomendaciones futuras

Como mejoras futuras, el script podría incorporar:

- Modo solo lectura, sin instalación automática de paquetes.
- Opción `--no-install`.
- Opción `--output <directorio>`.
- Salida JSON para integración con SIEM.
- Validación de configuraciones SSH.
- Revisión de usuarios con privilegios sudo.
- Revisión de permisos SUID/SGID.
- Detección de secretos en rutas seleccionadas.
- Inventario de paquetes instalados.
- Revisión de tareas cron y timers.
- Verificación de configuración de Docker y contenedores.
- Revisión de configuración de VMware y módulos del kernel.
- Generación de un resumen ejecutivo.
- Clasificación de hallazgos por severidad.
- Exclusión configurable de servicios legítimos.
- Registro sin códigos ANSI para facilitar el procesamiento automatizado.

---

## Uso responsable

Utiliza este script únicamente en equipos propios o en sistemas para los que tengas autorización explícita.

El resultado de una herramienta de auditoría debe interpretarse con criterio técnico. Una advertencia no confirma por sí sola una vulnerabilidad o compromiso, y la ausencia de advertencias no garantiza que el sistema sea seguro.

---

## Autor

**Jefferson Hernández Correa**  
Especialista en Red Team / Offensive Security

Proyecto orientado a la revisión defensiva, hardening y monitoreo básico de estaciones de trabajo Linux.
