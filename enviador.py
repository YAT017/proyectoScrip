#!/usr/bin/env python3
"""
Script para envío automático de facturas por correo electrónico
Lee el archivo pendientes_envio.csv y envía las facturas correspondientes
"""

import csv
import smtplib
import os
import re
import sys
import logging
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('enviador.log'),
        logging.StreamHandler()
    ]
)

# Configuración de correo (ajustar según el proveedor)
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
EMAIL_USER = "sistema.facturacion@empresa.com"  # Cambiar por email real
EMAIL_PASS = "password_aplicacion"  # Cambiar por contraseña de aplicación

def validar_email(email):
    """Valida formato de email usando expresiones regulares"""
    patron = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(patron, email) is not None

def crear_mensaje_email(destinatario, archivo_pdf):
    """Crea el mensaje de email con la factura adjunta"""
    
    # Extraer ID de transacción del nombre del archivo
    id_transaccion = archivo_pdf.replace('factura_', '').replace('.pdf', '')
    
    msg = MIMEMultipart()
    msg['From'] = EMAIL_USER
    msg['To'] = destinatario
    msg['Subject'] = f"Factura Electrónica #{id_transaccion} - Mercado IRSI"
    
    # Cuerpo del mensaje
    cuerpo = f"""
Estimado/a cliente,

Adjunto encontrará su factura electrónica correspondiente a la transacción #{id_transaccion}.

Detalles de la factura:
- Número de transacción: {id_transaccion}
- Fecha de emisión: {datetime.now().strftime('%Y-%m-%d')}
- Empresa: Mercado IRSI

Si tiene alguna consulta sobre esta factura, no dude en contactarnos.

Gracias por su compra.

Atentamente,
Sistema Automatizado de Facturación
Mercado IRSI
www.mercadoirsi.com

---
Este es un mensaje automático, por favor no responda a este correo.
"""
    
    msg.attach(MIMEText(cuerpo, 'plain', 'utf-8'))
    
    # Adjuntar PDF
    try:
        with open(f"facturas/{archivo_pdf}", "rb") as attachment:
            part = MIMEBase('application', 'octet-stream')
            part.set_payload(attachment.read())
            encoders.encode_base64(part)
            part.add_header(
                'Content-Disposition',
                f'attachment; filename= {archivo_pdf}'
            )
            msg.attach(part)
        return msg
    except FileNotFoundError:
        logging.error(f"No se encontró el archivo: facturas/{archivo_pdf}")
        return None

def enviar_email(destinatario, archivo_pdf):
    """Envía un email con la factura adjunta"""
    
    try:
        # Validar email
        if not validar_email(destinatario):
            logging.error(f"Email inválido: {destinatario}")
            return False
        
        # Crear mensaje
        mensaje = crear_mensaje_email(destinatario, archivo_pdf)
        if mensaje is None:
            return False
        
        # Conectar al servidor SMTP
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()  # Habilitar encriptación
        server.login(EMAIL_USER, EMAIL_PASS)
        
        # Enviar mensaje
        texto = mensaje.as_string()
        server.sendmail(EMAIL_USER, destinatario, texto)
        server.quit()
        
        logging.info(f"Email enviado exitosamente a {destinatario}")
        return True
        
    except smtplib.SMTPAuthenticationError:
        logging.error("Error de autenticación SMTP. Verificar credenciales.")
        return False
    except smtplib.SMTPRecipientsRefused:
        logging.error(f"Destinatario rechazado: {destinatario}")
        return False
    except smtplib.SMTPServerDisconnected:
        logging.error("Servidor SMTP desconectado")
        return False
    except Exception as e:
        logging.error(f"Error enviando email a {destinatario}: {str(e)}")
        return False

def procesar_pendientes():
    """Procesa el archivo de pendientes y envía los correos"""
    
    pendientes_file = "pendientes_envio.csv"
    log_envios_file = "log_envios.csv"
    
    if not os.path.exists(pendientes_file):
        logging.error(f"No se encuentra el archivo {pendientes_file}")
        return False
    
    # Crear archivo de log de envíos si no existe
    if not os.path.exists(log_envios_file):
        with open(log_envios_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(['archivo_pdf', 'correo_cliente', 'estado'])
    
    # Leer pendientes
    pendientes = []
    try:
        with open(pendientes_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            pendientes = list(reader)
    except Exception as e:
        logging.error(f"Error leyendo {pendientes_file}: {str(e)}")
        return False
    
    if not pendientes:
        logging.info("No hay facturas pendientes de envío")
        return True
    
    logging.info(f"Procesando {len(pendientes)} facturas pendientes...")
    
    exitosos = []
    fallidos = []
    
    # Procesar cada pendiente
    for item in pendientes:
        archivo_pdf = item['archivo_pdf']
        correo_cliente = item['correo_cliente']
        
        logging.info(f"Enviando {archivo_pdf} a {correo_cliente}")
        
        if enviar_email(correo_cliente, archivo_pdf):
            exitosos.append(item)
            estado = "exitoso"
        else:
            fallidos.append(item)
            estado = "fallido"
        
        # Registrar en log de envíos
        with open(log_envios_file, 'a', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow([archivo_pdf, correo_cliente, estado])
    
    # Actualizar archivo de pendientes (remover exitosos)
    if exitosos:
        with open(pendientes_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=['archivo_pdf', 'correo_cliente'])
            writer.writeheader()
            writer.writerows(fallidos)  # Solo escribir los fallidos
    
    # Resumen
    logging.info(f"Envíos completados: {len(exitosos)} exitosos, {len(fallidos)} fallidos")
    
    # Actualizar log diario
    with open('log_diario.log', 'a', encoding='utf-8') as f:
        f.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - ENVIOS: {len(exitosos)} exitosos, {len(fallidos)} fallidos\n")
    
    return True

def generar_reporte_diario():
    """Genera reporte diario basado en los logs"""
    
    try:
        # Leer log de envíos
        total_procesados = 0
        total_exitosos = 0
        total_fallidos = 0
        total_vendido = 0.0
        pagos_completos = 0
        
        if os.path.exists('log_envios.csv'):
            with open('log_envios.csv', 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    total_procesados += 1
                    if row['estado'] == 'exitoso':
                        total_exitosos += 1
                    else:
                        total_fallidos += 1
        
        # Leer datos de compras para calcular totales
        import glob
        csv_files = glob.glob('compras_*.csv')
        if csv_files:
            latest_csv = max(csv_files, key=os.path.getctime)
            with open(latest_csv, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row['estado_pago'] == 'exitoso':
                        total_vendido += float(row['monto'])
                        if row['pago'] == 'completo':
                            pagos_completos += 1
        
        # Crear reporte
        reporte = f"""
REPORTE DIARIO - SISTEMA DE FACTURACIÓN
Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

RESUMEN DE ENVÍOS:
- Total de correos procesados: {total_procesados}
- Envíos exitosos: {total_exitosos}
- Envíos fallidos: {total_fallidos}

RESUMEN DE VENTAS:
- Total vendido: ₡{total_vendido:,.2f}
- Pedidos pagados completamente: {pagos_completos}

ESTADO DEL SISTEMA: {'OPERATIVO' if total_fallidos < total_exitosos else 'CON PROBLEMAS'}
"""
        
        # Guardar reporte
        with open(f"reporte_diario_{datetime.now().strftime('%Y%m%d')}.txt", 'w', encoding='utf-8') as f:
            f.write(reporte)
        
        logging.info("Reporte diario generado exitosamente")
        print(reporte)
        
        return True
        
    except Exception as e:
        logging.error(f"Error generando reporte diario: {str(e)}")
        return False

def main():
    """Función principal"""
    
    logging.info("Iniciando proceso de envío de facturas...")
    
    try:
        # Procesar envíos pendientes
        if procesar_pendientes():
            logging.info("Proceso de envíos completado exitosamente")
            
            # Generar reporte diario
            generar_reporte_diario()
            
            return 0
        else:
            logging.error("Error en el proceso de envíos")
            return 1
            
    except KeyboardInterrupt:
        logging.info("Proceso interrumpido por el usuario")
        return 1
    except Exception as e:
        logging.error(f"Error inesperado: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
