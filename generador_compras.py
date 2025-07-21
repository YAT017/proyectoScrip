#!/usr/bin/env python3
"""
Generador de compras simuladas para el sistema de facturación
Utiliza Faker para generar datos realistas de transacciones
"""

import csv
import random
import sys
from datetime import datetime, timedelta
from faker import Faker
import uuid
import logging

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('generador_compras.log'),
        logging.StreamHandler()
    ]
)

fake = Faker('es_ES')  # Configurar para español

def generar_compra():
    """Genera una compra simulada con datos realistas"""
    
    # Simular errores aleatorios (5% de probabilidad)
    if random.random() < 0.05:
        raise Exception("Error simulado en la generación de compra")
    
    # Generar datos del cliente
    nombre = fake.name()
    correo = fake.email()
    telefono = fake.phone_number()
    direccion = fake.address().replace('\n', ', ')
    ciudad = fake.city()
    
    # Generar datos de la compra
    cantidad = random.randint(1, 10)
    monto = round(random.uniform(5000, 500000), 2)  # Montos en colones
    pago = random.choice(['completo', 'fraccionado'])
    estado_pago = random.choice(['exitoso', 'fallido']) if random.random() > 0.1 else 'fallido'
    ip = fake.ipv4()
    timestamp = fake.date_time_between(start_date='-1d', end_date='now')
    id_transaccion = str(uuid.uuid4())[:8].upper()
    
    return {
        'id_transaccion': id_transaccion,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'direccion': direccion,
        'ciudad': ciudad,
        'cantidad': cantidad,
        'monto': monto,
        'pago': pago,
        'estado_pago': estado_pago,
        'ip': ip,
        'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S'),
        'fecha_emision': datetime.now().strftime('%Y-%m-%d')
    }

def generar_lote_compras(num_compras=50):
    """Genera un lote de compras y las guarda en CSV"""
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'compras_{timestamp}.csv'
    
    compras_exitosas = []
    errores = 0
    
    logging.info(f"Generando {num_compras} compras simuladas...")
    
    for i in range(num_compras):
        try:
            compra = generar_compra()
            compras_exitosas.append(compra)
            logging.info(f"Compra {i+1}/{num_compras} generada: {compra['id_transaccion']}")
        except Exception as e:
            errores += 1
            logging.error(f"Error generando compra {i+1}: {str(e)}")
    
    # Guardar en CSV
    if compras_exitosas:
        fieldnames = compras_exitosas[0].keys()
        
        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(compras_exitosas)
        
        logging.info(f"Archivo generado: {filename}")
        logging.info(f"Compras exitosas: {len(compras_exitosas)}")
        logging.info(f"Errores simulados: {errores}")
        
        # Crear resumen para el log diario
        with open('log_diario.log', 'a', encoding='utf-8') as log_file:
            log_file.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - GENERACION: {len(compras_exitosas)} compras generadas, {errores} errores\n")
        
        return filename
    else:
        logging.error("No se pudieron generar compras exitosas")
        return None

def main():
    """Función principal"""
    try:
        num_compras = int(sys.argv[1]) if len(sys.argv) > 1 else 50
        archivo_generado = generar_lote_compras(num_compras)
        
        if archivo_generado:
            print(f"Lote de compras generado exitosamente: {archivo_generado}")
            return 0
        else:
            print("Error: No se pudo generar el lote de compras")
            return 1
            
    except KeyboardInterrupt:
        logging.info("Proceso interrumpido por el usuario")
        return 1
    except Exception as e:
        logging.error(f"Error inesperado: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
