
#!/usr/bin/env bash

# ============================================================
# SECURITY AUDIT SCRIPT
# Ubuntu / Debian
# Autor: Th3g4ntl3m4n
#
# Funciones:
# - Comprueba e instala herramientas
# - Revisa puertos y servicios
# - Ejecuta RKHunter
# - Ejecuta Lynis
# - Revisa UFW
# - Revisa AppArmor
# - Revisa Auditd
# - Revisa integridad de archivos
# - Guarda logs
#
# IMPORTANTE:
# - No modifica automáticamente las reglas de UFW.
# - No ejecuta rkhunter --propupd.
# - No inicializa automáticamente AIDE.
# ============================================================

set -o pipefail

# ============================================================
# COLORES
# ============================================================

RESET='\033[0m'
BOLD='\033[1m'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'

# ============================================================
# CONFIGURACIÓN DE LOGS
# ============================================================

LOG_DIR="${HOME}/security-audit-logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/audit_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

# Mostrar la salida en terminal y guardar una copia
exec > >(tee -a "$LOG_FILE") 2>&1

# ============================================================
# FUNCIONES DE SALIDA
# ============================================================

info() {
    printf "${BLUE}[INFO]${RESET} %s\n" "$1"
}

success() {
    printf "${GREEN}[ OK ]${RESET} %s\n" "$1"
}

warning() {
    printf "${YELLOW}[WARN]${RESET} %s\n" "$1"
}

error_msg() {
    printf "${RED}[ERROR]${RESET} %s\n" "$1"
}

section() {
    printf "\n${MAGENTA}${BOLD}"
    printf "============================================================\n"
    printf ">>> %s\n" "$1"
    printf "============================================================\n"
    printf "${RESET}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================
# VALIDAR SUDO
# ============================================================

require_sudo() {
    info "Validando privilegios sudo..."

    if sudo -v; then
        success "Acceso sudo validado."
    else
        error_msg "No se pudo validar sudo."
        exit 1
    fi
}

# ============================================================
# INSTALAR PAQUETE SI NO EXISTE
# ============================================================

install_if_missing() {
    local package="$1"
    local command_name="$2"

    if command_exists "$command_name"; then
        success "$package ya está instalado."
        return 0
    fi

    warning "$package no está instalado."
    info "Intentando instalar $package..."

    if sudo apt-get install -y "$package"; then

        if command_exists "$command_name"; then
            success "$package instalado correctamente."
        else
            warning "El paquete se instaló, pero no se encontró: $command_name"
        fi

    else
        error_msg "No se pudo instalar el paquete: $package"
    fi
}

# ============================================================
# BANNER
# ============================================================

show_banner() {
    clear 2>/dev/null || true

    printf "${CYAN}${BOLD}"
    printf "============================================================\n"
    printf "             SECURITY AUDIT SCRIPT\n"
    printf "                 UBUNTU / DEBIAN\n"
    printf "============================================================\n"
    printf "${RESET}"

    printf "${GRAY}Inicio: %s${RESET}\n" "$(date)"
    printf "${GRAY}Log:    %s${RESET}\n" "$LOG_FILE"
}

# ============================================================
# ACTUALIZAR REPOSITORIOS
# ============================================================

update_repositories() {
    section "ACTUALIZACIÓN DE REPOSITORIOS"

    info "Actualizando índices de APT..."

    if sudo apt-get update; then
        success "Repositorios actualizados."
    else
        error_msg "Falló apt-get update."
        warning "Algunas instalaciones podrían no funcionar."
    fi
}

# ============================================================
# COMPROBAR E INSTALAR HERRAMIENTAS
# ============================================================

install_tools() {
    section "COMPROBACIÓN DE HERRAMIENTAS"

    # Formato: paquete:comando
    local tools=(
        "rkhunter:rkhunter"
        "lynis:lynis"
        "ufw:ufw"
        "auditd:auditctl"
        "audispd-plugins:audispd"
        "aide:aide"
        "debsums:debsums"
        "unattended-upgrades:unattended-upgrade"
        "apt-listchanges:apt-listchanges"
        "iproute2:ss"
        "curl:curl"
    )

    local item
    local package
    local command_name

    for item in "${tools[@]}"; do

        package="${item%%:*}"
        command_name="${item##*:}"

        install_if_missing "$package" "$command_name"

    done
}

# ============================================================
# INFORMACIÓN DEL SISTEMA
# ============================================================

system_information() {
    section "INFORMACIÓN DEL SISTEMA"

    info "Sistema operativo:"

    if command_exists lsb_release; then
        lsb_release -a 2>/dev/null || true
    else
        cat /etc/os-release
    fi

    printf "\n"

    info "Kernel:"
    uname -a

    printf "\n"

    info "Usuario:"
    id

    printf "\n"

    info "Tiempo de actividad:"
    uptime
}

# ============================================================
# PUERTOS Y SERVICIOS
# ============================================================

network_audit() {
    section "PUERTOS Y SERVICIOS"

    if command_exists ss; then

        info "Puertos TCP/UDP en escucha:"
        sudo ss -tulpen

    else

        error_msg "El comando ss no está disponible."

    fi

    printf "\n"

    info "Servicios activos:"

    systemctl \
        --type=service \
        --state=running \
        --no-pager 2>/dev/null \
        || warning "No se pudieron consultar los servicios."

    printf "\n"

    info "Servicios habilitados al inicio:"

    systemctl \
        list-unit-files \
        --state=enabled \
        --no-pager 2>/dev/null \
        || warning "No se pudieron consultar los servicios habilitados."
}

# ============================================================
# FIREWALL UFW
# ============================================================

firewall_audit() {
    section "AUDITORÍA DE FIREWALL UFW"

    if command_exists ufw; then

        info "Estado actual de UFW:"
        sudo ufw status verbose

        printf "\n"

        info "Reglas numeradas:"
        sudo ufw status numbered

        warning "No se activan ni modifican reglas de UFW automáticamente."
        warning "Revisa las reglas antes de aplicar políticas restrictivas."

    else

        error_msg "UFW no está disponible."

    fi
}

# ============================================================
# RKHUNTER
# ============================================================

rkhunter_audit() {
    section "RKHUNTER - DETECCIÓN DE ROOTKITS"

    if ! command_exists rkhunter; then
        error_msg "rkhunter no está disponible."
        return
    fi

    info "Actualizando la base de datos de rkhunter..."

    sudo rkhunter --update \
        || warning "No se pudo actualizar rkhunter."

    printf "\n"

    info "Comprobando la versión..."

    sudo rkhunter --versioncheck \
        || warning "No se pudo comprobar la versión."

    printf "\n"

    warning "Las advertencias no significan automáticamente una infección."
    warning "Revisa cada resultado antes de realizar cambios."

    info "Ejecutando análisis de rkhunter..."

    sudo rkhunter \
        --check \
        --skip-keypress \
        --report-warnings-only \
        || warning "rkhunter terminó con advertencias o código no cero."

    printf "\n"

    warning "No se ejecuta rkhunter --propupd automáticamente."
    info "La base de referencia solo debe actualizarse después de verificar los archivos."

}

# ============================================================
# LYNIS
# ============================================================

lynis_audit() {
    section "LYNIS - AUDITORÍA DE SEGURIDAD"

    if ! command_exists lynis; then
        error_msg "Lynis no está disponible."
        return
    fi

    info "Ejecutando auditoría de seguridad..."

    sudo lynis audit system --quick \
        || warning "Lynis terminó con advertencias o código no cero."

    printf "\n"

    if [[ -f /var/log/lynis.log ]]; then

        info "Últimas advertencias de Lynis:"

        sudo grep -i "warning" /var/log/lynis.log \
            | tail -n 30 \
            || info "No se encontraron advertencias."

    else

        warning "No se encontró el archivo /var/log/lynis.log."

    fi
}

# ============================================================
# APPARMOR
# ============================================================

apparmor_audit() {
    section "APPARMOR - ESTADO DE PERFILES"

    if command_exists aa-status; then

        sudo aa-status \
            || warning "No se pudo consultar AppArmor."

    else

        warning "aa-status no está disponible."

    fi

    printf "\n"

    info "Eventos AppArmor denegados durante las últimas 24 horas:"

    sudo journalctl \
        -k \
        -g 'apparmor.*DENIED|apparmor="DENIED"' \
        --since "24 hours ago" \
        --no-pager 2>/dev/null \
        | tail -n 50 \
        || info "No se encontraron eventos o no se pudieron consultar."

}

# ============================================================
# AUDITD
# ============================================================

auditd_audit() {
    section "AUDITD - AUDITORÍA DE EVENTOS"

    if ! command_exists auditctl; then
        error_msg "auditctl no está disponible."
        return
    fi

    info "Estado del servicio auditd:"

    sudo systemctl is-active auditd \
        || warning "auditd no está activo."

    printf "\n"

    info "Reglas de auditoría cargadas:"

    sudo auditctl -l \
        || warning "No se pudieron consultar las reglas."

    printf "\n"

    info "Eventos recientes de auditoría:"

    sudo ausearch -ts recent 2>/dev/null \
        | tail -n 80 \
        || info "No se encontraron eventos recientes."

}

# ============================================================
# INTEGRIDAD DE ARCHIVOS
# ============================================================

file_integrity_audit() {
    section "INTEGRIDAD DE ARCHIVOS"

    if command_exists debsums; then

        info "Comprobando archivos modificados de paquetes..."

        sudo debsums -c 2>/dev/null \
            | head -n 100 \
            || info "No se encontraron diferencias reportadas."

    else

        warning "debsums no está disponible."

    fi

    printf "\n"

    if command_exists aide; then

        success "AIDE está instalado."

        warning "AIDE no se inicializa automáticamente."
        info "Para inicializarlo manualmente, revisa primero su configuración:"
        printf "sudo aideinit\n"

    else

        warning "AIDE no está disponible."

    fi
}

# ============================================================
# ACTUALIZACIONES AUTOMÁTICAS
# ============================================================

automatic_updates_audit() {
    section "ACTUALIZACIONES AUTOMÁTICAS"

    info "Estado de unattended-upgrades:"

    systemctl is-enabled unattended-upgrades 2>/dev/null \
        || warning "unattended-upgrades no está habilitado."

    printf "\n"

    info "Timers relacionados con actualizaciones:"

    systemctl list-timers --all --no-pager 2>/dev/null \
        | grep -iE "unattended|apt" \
        || info "No se encontraron timers relacionados."
}

# ============================================================
# RESUMEN FINAL
# ============================================================

final_summary() {
    section "RESUMEN FINAL"

    success "Auditoría finalizada."

    printf "\n"
    printf "Fecha: %s\n" "$(date)"
    printf "Log:   %s\n" "$LOG_FILE"

    printf "\n"

    warning "Revisa las advertencias antes de aplicar cambios."
    warning "No se modificaron las reglas de UFW."
    warning "No se ejecutó rkhunter --propupd."
    warning "No se inicializó automáticamente AIDE."

    printf "\n"

    info "Para revisar el log completo:"
    printf "less '%s'\n" "$LOG_FILE"
}

# ============================================================
# FUNCIÓN PRINCIPAL
# ============================================================

main() {

    show_banner

    require_sudo

    update_repositories

    install_tools

    system_information

    network_audit

    firewall_audit

    rkhunter_audit

    lynis_audit

    apparmor_audit

    auditd_audit

    file_integrity_audit

    automatic_updates_audit

    final_summary

}

main "$@"
