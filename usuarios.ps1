# Script para crear usuarios temporales en el sistema
# Lee archivo empleados.csv y crea cuentas locales con privilegios

param(
    [string]$CsvFile = "empleados.csv",
    [string]$LogFile = "usuarios_creados.log"
)

# Función para logging
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    Write-Host $logEntry
    Add-Content -Path $LogFile -Value $logEntry
}

# Función para generar contraseña segura
function Generate-SecurePassword {
    $length = 12
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = ""
    
    # Asegurar al menos un carácter de cada tipo
    $password += Get-Random -InputObject @("a".."z")
    $password += Get-Random -InputObject @("A".."Z") 
    $password += Get-Random -InputObject @(0..9)
    $password += Get-Random -InputObject @("!", "@", "#", "$", "%", "^", "&", "*")
    
    # Completar el resto de la contraseña
    for ($i = 4; $i -lt $length; $i++) {
        $password += $chars[(Get-Random -Maximum $chars.Length)]
    }
    
    # Mezclar caracteres
    $passwordArray = $password.ToCharArray()
    $shuffled = $passwordArray | Sort-Object {Get-Random}
    return -join $shuffled
}

# Función para validar formato de email
function Test-EmailFormat {
    param([string]$Email)
    return $Email -match "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
}

# Función para crear usuario
function New-TemporaryUser {
    param(
        [string]$FullName,
        [string]$Email,
        [string]$Department = "Temporal"
    )
    
    try {
        # Generar nombre de usuario basado en el email
        $username = ($Email -split "@")[0] -replace "[^a-zA-Z0-9]", ""
        $username = $username.Substring(0, [Math]::Min($username.Length, 20))
        
        # Verificar si el usuario ya existe
        if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            Write-Log "ADVERTENCIA: Usuario $username ya existe, agregando sufijo numérico"
            $counter = 1
            $originalUsername = $username
            do {
                $username = "$originalUsername$counter"
                $counter++
            } while (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)
        }
        
        # Generar contraseña segura
        $password = Generate-SecurePassword
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        
        # Crear usuario local
        New-LocalUser -Name $username -Password $securePassword -FullName $FullName -Description "Usuario temporal - $Department" -AccountNeverExpires
        
        # Agregar a grupo de administradores locales
        Add-LocalGroupMember -Group "Administradores" -Member $username -ErrorAction SilentlyContinue
        
        # Si falla con "Administradores", intentar con "Administrators" (inglés)
        if ($?) {
            Write-Log "Usuario $username agregado al grupo Administradores"
        } else {
            Add-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction SilentlyContinue
            if ($?) {
                Write-Log "Usuario $username agregado al grupo Administrators"
            } else {
                Write-Log "ADVERTENCIA: No se pudo agregar $username a grupo de administradores"
            }
        }
        
        # Registrar información del usuario creado
        $userInfo = @{
            Username = $username
            FullName = $FullName
            Email = $Email
            Password = $password
            Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Department = $Department
        }
        
        Write-Log "EXITOSO: Usuario creado - $username ($FullName) - Email: $Email"
        
        # Guardar credenciales en archivo seguro (solo para administrador)
        $credentialsFile = "credenciales_usuarios.txt"
        $credentialEntry = "Usuario: $username | Nombre: $FullName | Email: $Email | Contraseña: $password | Creado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Add-Content -Path $credentialsFile -Value $credentialEntry
        
        return $userInfo
        
    } catch {
        Write-Log "ERROR: No se pudo crear usuario para $FullName - $($_.Exception.Message)"
        return $null
    }
}

# Función principal
function Main {
    Write-Log "=== INICIO DEL PROCESO DE CREACIÓN DE USUARIOS TEMPORALES ==="
    
    # Verificar si se ejecuta como administrador
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Log "ERROR: Este script debe ejecutarse como Administrador"
        exit 1
    }
    
    # Verificar si existe el archivo CSV
    if (-not (Test-Path $CsvFile)) {
        Write-Log "ERROR: No se encuentra el archivo $CsvFile"
        exit 1
    }
    
    Write-Log "Procesando archivo: $CsvFile"
    
    # Leer archivo CSV
    try {
        $empleados = Import-Csv -Path $CsvFile -Encoding UTF8
        Write-Log "Archivo CSV leído correctamente. Empleados encontrados: $($empleados.Count)"
    } catch {
        Write-Log "ERROR: No se pudo leer el archivo CSV - $($_.Exception.Message)"
        exit 1
    }
    
    $usuariosCreados = 0
    $errores = 0
    
    # Procesar cada empleado
    foreach ($empleado in $empleados) {
        Write-Log "Procesando: $($empleado.nombre) - $($empleado.correo)"
        
        # Validar datos requeridos
        if ([string]::IsNullOrWhiteSpace($empleado.nombre) -or [string]::IsNullOrWhiteSpace($empleado.correo)) {
            Write-Log "ERROR: Datos incompletos para empleado - Nombre: '$($empleado.nombre)' Email: '$($empleado.correo)'"
            $errores++
            continue
        }
        
        # Validar formato de email
        if (-not (Test-EmailFormat $empleado.correo)) {
            Write-Log "ERROR: Formato de email inválido: $($empleado.correo)"
            $errores++
            continue
        }
        
        # Crear usuario
        $resultado = New-TemporaryUser -FullName $empleado.nombre -Email $empleado.correo -Department $empleado.departamento
        
        if ($resultado) {
            $usuariosCreados++
        } else {
            $errores++
        }
        
        # Pausa breve entre creaciones
        Start-Sleep -Milliseconds 500
    }
    
    # Resumen final
    Write-Log "=== RESUMEN FINAL ==="
    Write-Log "Usuarios creados exitosamente: $usuariosCreados"
    Write-Log "Errores encontrados: $errores"
    Write-Log "Total procesados: $($usuariosCreados + $errores)"
    
    # Actualizar log diario
    $logDiarioEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - USUARIOS: $usuariosCreados creados, $errores errores"
    Add-Content -Path "log_diario.log" -Value $logDiarioEntry
    
    Write-Log "=== PROCESO COMPLETADO ==="
    
    if ($errores -eq 0) {
        exit 0
    } else {
        exit 1
    }
}

# Ejecutar función principal
Main
