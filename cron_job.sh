#!/bin/bash

# Script de automatización para el sistema de facturación
# Configura y ejecuta los procesos según horario establecido

set -e

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/cron_automation.log"

# Función de logging
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - CRON: $1" | tee -a "$LOG_FILE"
}

# Función para ejecutar generación de facturas
ejecutar_facturas() {
    log_message "Iniciando generación de facturas..."
    
    cd "$SCRIPT_DIR"
    
    if bash generador_facturas.sh; then
        log_message "Generación de facturas completada exitosamente"
        return 0
    else
        log_message "ERROR: Falló la generación de facturas"
        return 1
    fi
}

# Función para ejecutar envío de correos
ejecutar_envios() {
    log_message "Iniciando envío de correos..."
    
    cd "$SCRIPT_DIR"
    
    if python3 enviador.py; then
        log_message "Envío de correos completado exitosamente"
        return 0
    else
        log_message "ERROR: Falló el envío de correos"
        return 1
    fi
}

# Función para ejecutar creación de usuarios (si hay archivo)
ejecutar_usuarios() {
    cd "$SCRIPT_DIR"
    
    if [ -f "empleados.csv" ]; then
        log_message "Archivo empleados.csv encontrado, creando usuarios..."
        
        if pwsh -File usuarios.ps1; then
            log_message "Creación de usuarios completada exitosamente"
            # Mover archivo procesado
            mv empleados.csv "empleados_procesado_$(date +%Y%m%d_%H%M%S).csv"
            return 0
        else
            log_message "ERROR: Falló la creación de usuarios"
            return 1
        fi
    else
        log_message "No se encontró archivo empleados.csv, omitiendo creación de usuarios"
        return 0
    fi
}

# Función para generar compras (opcional)
generar_compras() {
    log_message "Generando nuevas compras simuladas..."
    
    cd "$SCRIPT_DIR"
    
    if python3 generador_compras.py 30; then
        log_message "Generación de compras completada"
        return 0
    else
        log_message "ERROR: Falló la generación de compras"
        return 1
    fi
}

# Función para enviar reporte diario al administrador
enviar_reporte_admin() {
    log_message "Enviando reporte diario al administrador..."
    
    # Crear reporte consolidado
    local reporte_file="reporte_admin_$(date +%Y%m%d).txt"
    
    cat > "$reporte_file" << EOF
REPORTE DIARIO DEL SISTEMA DE FACTURACIÓN
Fecha: $(date '+%Y-%m-%d %H:%M:%S')

=== RESUMEN DE ACTIVIDADES ===
$(tail -20 log_diario.log)

=== ESTADO DE ARCHIVOS ===
Facturas generadas: $(ls facturas/*.pdf 2>/dev/null | wc -l)
Pendientes de envío: $(tail -n +2 pendientes_envio.csv 2>/dev/null | wc -l)
Logs de envío: $(tail -n +2 log_envios.csv 2>/dev/null | wc -l)

=== ESPACIO EN DISCO ===
$(df -h .)

=== PROCESOS AUTOMATIZADOS ===
Última ejecución de cron: $(date)
Estado: COMPLETADO

Reporte generado automáticamente por el sistema.
EOF
    
    # Simular envío (en producción usar mail o similar)
    log_message "Reporte generado: $reporte_file"
    
    # Aquí se podría agregar envío real por correo
    # mail -s "Reporte Diario Sistema Facturación" admin@empresa.com < "$reporte_file"
}

# Función principal según el argumento
main() {
    local accion="$1"
    
    log_message "=== INICIO DE AUTOMATIZACIÓN: $accion ==="
    
    case "$accion" in
        "facturas")
            ejecutar_facturas
            ;;
        "envios")
            ejecutar_envios
            ;;
        "usuarios")
            ejecutar_usuarios
            ;;
        "compras")
            generar_compras
            ;;
        "reporte")
            enviar_reporte_admin
            ;;
        "completo")
            # Ejecutar flujo completo
            generar_compras
            sleep 5
            ejecutar_facturas
            sleep 5
            ejecutar_envios
            sleep 5
            ejecutar_usuarios
            sleep 5
            enviar_reporte_admin
            ;;
        *)
            echo "Uso: $0 {facturas|envios|usuarios|compras|reporte|completo}"
            echo ""
            echo "Acciones disponibles:"
            echo "  facturas  - Generar facturas PDF desde CSV"
            echo "  envios    - Enviar facturas por correo"
            echo "  usuarios  - Crear usuarios temporales"
            echo "  compras   - Generar nuevas compras simuladas"
            echo "  reporte   - Enviar reporte diario"
            echo "  completo  - Ejecutar flujo completo"
            exit 1
            ;;
    esac
    
    local exit_code=$?
    log_message "=== FIN DE AUTOMATIZACIÓN: $accion (código: $exit_code) ==="
    
    exit $exit_code
}

# Ejecutar función principal
main "$@"
