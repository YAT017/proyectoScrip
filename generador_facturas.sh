#!/bin/bash

# Script para generar facturas PDF a partir de archivos CSV
# Utiliza sed para sustituir placeholders en plantilla LaTeX

set -e  # Salir en caso de error

# Configuración
TEMPLATE_FILE="plantilla_factura.tex"
LOG_DIARIO="log_diario.log"
PENDIENTES_FILE="pendientes_envio.csv"
FACTURAS_DIR="facturas"

# Función para logging
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - FACTURAS: $1" | tee -a "$LOG_DIARIO"
}

# Función para limpiar archivos temporales
cleanup() {
    rm -f temp_*.tex temp_*.log temp_*.aux
}

# Trap para limpiar en caso de interrupción
trap cleanup EXIT

# Verificar dependencias
check_dependencies() {
    log_message "Verificando dependencias..."
    
    if ! command -v pdflatex &> /dev/null; then
        log_message "ERROR: pdflatex no está instalado"
        exit 1
    fi
    
    if [ ! -f "$TEMPLATE_FILE" ]; then
        log_message "ERROR: No se encuentra la plantilla $TEMPLATE_FILE"
        exit 1
    fi
    
    log_message "Dependencias verificadas correctamente"
}

# Función para sustituir placeholders en el template
sustituir_placeholders() {
    local input_file="$1"
    local output_file="$2"
    local id_transaccion="$3"
    local fecha_emision="$4"
    local nombre="$5"
    local correo="$6"
    local telefono="$7"
    local direccion="$8"
    local ciudad="$9"
    local cantidad="${10}"
    local monto="${11}"
    local pago="${12}"
    local estado_pago="${13}"
    local ip="${14}"
    local timestamp="${15}"
    
    # Escapar caracteres especiales para sed
    nombre_escaped=$(echo "$nombre" | sed 's/[[\.*^$()+?{|]/\\&/g')
    correo_escaped=$(echo "$correo" | sed 's/[[\.*^$()+?{|]/\\&/g')
    direccion_escaped=$(echo "$direccion" | sed 's/[[\.*^$()+?{|]/\\&/g')
    ciudad_escaped=$(echo "$ciudad" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    # Generar observaciones basadas en el estado del pago
    local observaciones=""
    if [ "$estado_pago" = "exitoso" ]; then
        observaciones="Pago procesado exitosamente. Gracias por su compra."
    else
        observaciones="ATENCIÓN: Pago pendiente o fallido. Contactar al cliente."
    fi
    
    # Realizar sustituciones campo por campo
    sed -e "s/{id_transaccion}/$id_transaccion/g" \
        -e "s/{fecha_emision}/$fecha_emision/g" \
        -e "s/{nombre}/$nombre_escaped/g" \
        -e "s/{correo}/$correo_escaped/g" \
        -e "s/{telefono}/$telefono/g" \
        -e "s/{direccion}/$direccion_escaped/g" \
        -e "s/{ciudad}/$ciudad_escaped/g" \
        -e "s/{cantidad}/$cantidad/g" \
        -e "s/{monto}/$monto/g" \
        -e "s/{pago}/$pago/g" \
        -e "s/{estado_pago}/$estado_pago/g" \
        -e "s/{ip}/$ip/g" \
        -e "s/{timestamp}/$timestamp/g" \
        -e "s/{observaciones}/$observaciones/g" \
        "$input_file" > "$output_file"
}

# Función para compilar LaTeX a PDF
compilar_pdf() {
    local tex_file="$1"
    local pdf_name="$2"
    
    log_message "Compilando $tex_file a PDF..."
    
    # Compilar con pdflatex (silencioso)
    if pdflatex -interaction=nonstopmode -output-directory="$FACTURAS_DIR" "$tex_file" > /dev/null 2>&1; then
        # Verificar si se generó el PDF
        if [ -f "$FACTURAS_DIR/${tex_file%.tex}.pdf" ]; then
            # Renombrar el PDF
            mv "$FACTURAS_DIR/${tex_file%.tex}.pdf" "$FACTURAS_DIR/$pdf_name"
            log_message "PDF generado exitosamente: $pdf_name"
            return 0
        else
            log_message "ERROR: No se generó el archivo PDF para $tex_file"
            return 1
        fi
    else
        # Revisar el log de LaTeX en busca de errores
        local log_file="$FACTURAS_DIR/${tex_file%.tex}.log"
        if [ -f "$log_file" ]; then
            local errores=$(grep "^!" "$log_file" | head -5)
            if [ -n "$errores" ]; then
                log_message "ERRORES LaTeX en $tex_file:"
                echo "$errores" | while read -r error; do
                    log_message "  $error"
                done
            fi
        fi
        log_message "ERROR: Falló la compilación de $tex_file"
        return 1
    fi
}

# Función principal para procesar CSV
procesar_csv() {
    local csv_file="$1"
    
    if [ ! -f "$csv_file" ]; then
        log_message "ERROR: No se encuentra el archivo CSV: $csv_file"
        return 1
    fi
    
    log_message "Procesando archivo CSV: $csv_file"
    
    # Crear directorio de facturas si no existe
    mkdir -p "$FACTURAS_DIR"
    
    # Limpiar archivo de pendientes
    echo "archivo_pdf,correo_cliente" > "$PENDIENTES_FILE"
    
    local total_procesadas=0
    local total_exitosas=0
    local total_fallidas=0
    
    # Leer CSV línea por línea (saltando el header)
    tail -n +2 "$csv_file" | while IFS=',' read -r id_transaccion nombre correo telefono direccion ciudad cantidad monto pago estado_pago ip timestamp fecha_emision; do
        
        total_procesadas=$((total_procesadas + 1))
        
        log_message "Procesando factura $total_procesadas: $id_transaccion"
        
        # Crear archivo temporal para esta factura
        local temp_tex="temp_${id_transaccion}.tex"
        local pdf_name="factura_${id_transaccion}.pdf"
        
        # Sustituir placeholders
        sustituir_placeholders "$TEMPLATE_FILE" "$temp_tex" \
            "$id_transaccion" "$fecha_emision" "$nombre" "$correo" "$telefono" \
            "$direccion" "$ciudad" "$cantidad" "$monto" "$pago" \
            "$estado_pago" "$ip" "$timestamp"
        
        # Compilar a PDF
        if compilar_pdf "$temp_tex" "$pdf_name"; then
            total_exitosas=$((total_exitosas + 1))
            
            # Agregar a pendientes de envío
            echo "$pdf_name,$correo" >> "$PENDIENTES_FILE"
            
            log_message "Factura $id_transaccion procesada exitosamente"
        else
            total_fallidas=$((total_fallidas + 1))
            log_message "ERROR: Falló el procesamiento de factura $id_transaccion"
        fi
        
        # Limpiar archivo temporal
        rm -f "$temp_tex"
    done
    
    # Resumen final
    log_message "RESUMEN: $total_procesadas procesadas, $total_exitosas exitosas, $total_fallidas fallidas"
    
    # Enviar log diario al administrador (simulado)
    log_message "Preparando envío de log diario al administrador..."
    
    return 0
}

# Función principal
main() {
    log_message "Iniciando generación de facturas..."
    
    check_dependencies
    
    # Buscar el archivo CSV más reciente
    local csv_file=$(ls -t compras_*.csv 2>/dev/null | head -1)
    
    if [ -z "$csv_file" ]; then
        log_message "ERROR: No se encontraron archivos CSV de compras"
        exit 1
    fi
    
    log_message "Archivo CSV encontrado: $csv_file"
    
    if procesar_csv "$csv_file"; then
        log_message "Proceso de generación de facturas completado exitosamente"
        exit 0
    else
        log_message "ERROR: Falló el proceso de generación de facturas"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
