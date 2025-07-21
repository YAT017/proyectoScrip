#!/bin/bash

# Script de instalación de dependencias para el sistema de facturación
# Compatible con Kali Linux y distribuciones basadas en Debian

set -e

echo "=== INSTALADOR DE DEPENDENCIAS - SISTEMA DE FACTURACIÓN ==="
echo "Compatible con Kali Linux y distribuciones Debian/Ubuntu"
echo ""

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para logging
log_install() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Actualizar repositorios
log_install "Actualizando repositorios del sistema..."
sudo apt update

# Instalar Python 3 y pip si no están instalados
if ! command_exists python3; then
    log_install "Instalando Python 3..."
    sudo apt install -y python3 python3-pip
else
    log_install "Python 3 ya está instalado: $(python3 --version)"
fi

# Instalar pip si no está disponible
if ! command_exists pip3; then
    log_install "Instalando pip3..."
    sudo apt install -y python3-pip
fi

# Instalar librerías de Python necesarias
log_install "Instalando librerías de Python..."
pip3 install --user faker

# Verificar si se necesita instalar más dependencias de Python para email
python3 -c "import smtplib, email" 2>/dev/null || {
    log_install "Instalando dependencias adicionales de Python para email..."
    sudo apt install -y python3-email-validator
}

# Instalar LaTeX (TeX Live)
if ! command_exists pdflatex; then
    log_install "Instalando TeX Live (LaTeX)..."
    sudo apt install -y texlive-latex-base texlive-latex-extra texlive-fonts-recommended texlive-lang-spanish
else
    log_install "LaTeX ya está instalado: $(pdflatex --version | head -1)"
fi

# Instalar PowerShell para Linux
if ! command_exists pwsh; then
    log_install "Instalando PowerShell para Linux..."
    
    # Descargar e instalar PowerShell
    wget -q https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt update
    sudo apt install -y powershell
    rm -f packages-microsoft-prod.deb
else
    log_install "PowerShell ya está instalado: $(pwsh --version)"
fi

# Instalar herramientas adicionales del sistema
log_install "Instalando herramientas del sistema..."
sudo apt install -y cron mailutils

# Verificar que sed y awk estén disponibles (deberían estar por defecto)
if ! command_exists sed; then
    sudo apt install -y sed
fi

if ! command_exists awk; then
    sudo apt install -y gawk
fi

# Crear directorios necesarios
log_install "Creando estructura de directorios..."
mkdir -p facturas
mkdir -p logs
mkdir -p scripts

# Configurar permisos de ejecución para los scripts
log_install "Configurando permisos de ejecución..."
chmod +x generador_facturas.sh
chmod +x cron_job.sh
chmod +x install_dependencies.sh

# Verificar instalaciones
log_install "Verificando instalaciones..."

echo ""
echo "=== VERIFICACIÓN DE DEPENDENCIAS ==="

# Python y librerías
if python3 -c "import faker; print('✓ Faker instalado correctamente')" 2>/dev/null; then
    echo "✓ Python 3 y Faker: OK"
else
    echo "✗ Error con Python 3 o Faker"
fi

# LaTeX
if pdflatex --version >/dev/null 2>&1; then
    echo "✓ LaTeX (pdflatex): OK"
else
    echo "✗ Error con LaTeX"
fi

# PowerShell
if pwsh -c "Write-Host '✓ PowerShell funcionando correctamente'" 2>/dev/null; then
    echo "✓ PowerShell: OK"
else
    echo "✗ Error con PowerShell"
fi

# Herramientas del sistema
if command_exists sed && command_exists awk; then
    echo "✓ sed y awk: OK"
else
    echo "✗ Error con sed o awk"
fi

# Cron
if systemctl is-active --quiet cron; then
    echo "✓ Servicio cron: OK"
else
    echo "⚠ Servicio cron no está activo, iniciando..."
    sudo systemctl start cron
    sudo systemctl enable cron
fi

echo ""
echo "=== CONFIGURACIÓN ADICIONAL ==="

# Configurar cron jobs
log_install "Configurando tareas de cron..."

# Crear archivo de cron temporal
cat > temp_crontab << EOF
# Sistema de Facturación Automatizada
# Generar facturas a las 01:00
0 1 * * * cd $(pwd) && ./cron_job.sh facturas >> cron_automation.log 2>&1

# Enviar correos a las 02:00  
0 2 * * * cd $(pwd) && ./cron_job.sh envios >> cron_automation.log 2>&1

# Crear usuarios a las 03:00 (si hay archivo)
0 3 * * * cd $(pwd) && ./cron_job.sh usuarios >> cron_automation.log 2>&1

# Generar reporte diario a las 23:00
0 23 * * * cd $(pwd) && ./cron_job.sh reporte >> cron_automation.log 2>&1

# Generar nuevas compras cada 6 horas (opcional)
0 */6 * * * cd $(pwd) && ./cron_job.sh compras >> cron_automation.log 2>&1
EOF

# Instalar crontab
crontab temp_crontab
rm temp_crontab

echo "✓ Tareas de cron configuradas"

# Crear archivo de configuración de ejemplo
cat > config_email.txt << EOF
CONFIGURACIÓN DE EMAIL REQUERIDA:

Para que el sistema funcione completamente, debe configurar las credenciales de email en el archivo enviador.py:

1. Abrir enviador.py
2. Modificar las siguientes variables:
   - EMAIL_USER = "su_email@gmail.com"
   - EMAIL_PASS = "su_contraseña_de_aplicación"
   - SMTP_SERVER = "smtp.gmail.com" (o su proveedor)
   - SMTP_PORT = 587

Para Gmail:
1. Habilitar autenticación de 2 factores
2. Generar contraseña de aplicación
3. Usar la contraseña de aplicación en EMAIL_PASS

NOTA: El sistema funcionará sin email, pero no enviará facturas.
EOF

echo "⚠ IMPORTANTE: Revisar config_email.txt para configurar el envío de correos"

echo ""
echo "=== INSTALACIÓN COMPLETADA ==="
echo ""
echo "Próximos pasos:"
echo "1. Configurar credenciales de email (ver config_email.txt)"
echo "2. Ejecutar: python3 generador_compras.py"
echo "3. Ejecutar: ./generador_facturas.sh"
echo "4. Ejecutar: python3 enviador.py"
echo "5. O usar: ./cron_job.sh completo (para flujo completo)"
echo ""
echo "Los procesos automáticos ya están configurados en cron."
echo "Consultar README.md para instrucciones detalladas."

log_install "Instalación completada exitosamente"
