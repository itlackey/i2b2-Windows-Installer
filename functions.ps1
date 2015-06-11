﻿Add-Type -AssemblyName System.IO.Compression.FileSystem

report "Importing functions"

function exec{
    Param(
        [parameter(Mandatory=$true)]
	    [string]$path,
        [parameter(Mandatory=$false)]
	    [string]$args = ""
    )

    report "Running " $path $args

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $path
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $args
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()


    
    if($p.ExitCode -ne 0) {
        report "stdout: $stdout"
        report "stderr: $stderr"
        report "exit code: " + $p.ExitCode
    	Throw "ERROR"
    }

     report $path " completed"


}

function report($message) {
	if($Logging -eq $true){
		Add-Content "`n" + $message
	}
        echo "$message"
}

function removeFromPath($path) {

    $cleanPath = $env:Path.Replace($path, "")
    $cleanPath = $cleanPath.TrimEnd(';') 
    $env:Path = $cleanPath
    [Environment]::SetEnvironmentVariable("PATH", $cleanPath, "Machine")
}

function setEnvironmentVariable($name, $value){
    [System.Environment]::SetEnvironmentVariable($name, $value, 'machine')
    [System.Environment]::SetEnvironmentVariable($name, $value, 'process')
}

function export ([string]$variableAndValue){
<#
    .SYNOPSIS give support for bash style syntax: export VARNAME=VALUE
#>

    $arr = $variableAndValue.Split("=");
    
    $varName = $arr[0]
    $value = $arr[1]

    setEnvironmentVariable $varName $value
   
}

function require($value, [string]$message = "value cannot be null"){
    
    if($value -eq $null){
        Throw $message
    }

}

function addToPath($pathToAppend){



    if(![System.Environment]::GetEnvironmentVariable("PATH").Contains($pathToAppend)){

        report "Adding $($pathToAppend) to PATH"
        

        #verify that the current path ends with ; or append it to the start of the pathToAppend

        if($env:PATH.EndsWith(";") -eq $false){
            $pathToAppend = ";" + $pathToAppend
        }
     
        $newPath = ($env:PATH + $pathToAppend)

        report "New path: $newPath"

        setEnvironmentVariable "PATH" $newPath
    }

}

function isAntInstalled {    
    <#    
    .SYNOPSIS Check it see if ant is installed
    #>    
    try{
        
        $out = &"ant" -version 2>&1
        $antver = $out[0].tostring();

        return  ($antver -gt "")

    }catch {
        return $false
    }
}

function isJavaInstalled {    
    <#    
    .SYNOPSIS Check it see if Java is installed
    #>    
  
    try{

        $java = Get-WmiObject -Class win32_product | where { $_.Name -like "*Java SE Development Kit 7*"}

        return ($java.Count -gt 0)

    } catch {
        return $false
    }
}


function getJavaFolder {
	    <#    
    .SYNOPSIS Locate correct Java 7 Folder
    #> 

	$javaLoc = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\javaws.exe" -name "path").Path
	$prepend = (Get-Item -Path $javaLoc).Parent.Parent.FullName
	$append = Get-ChildItem -Path $prepend -Filter apt.exe -Recurse -Name
	$javaFolder = "$prepend\$append"

	$javaFolder = (Get-Item -Path $java.TrimEnd("apt.exe")).Parent.FullName

	return $javaFolder
}

function removeTempFolder{  

    if(Test-Path $__tempFolder){
	    Remove-Item $__tempFolder -recurse -force
    }   
}

function createTempFolder{

    New-Item $__tempFolder -Type directory -Force > $null

    write-host "Created " $__tempFolder
}

function unzip($zipFile, $folderPath, $removeFolder = $false) {

    try {

        if($removeFolder -eq $true){

            if(Test-Path $folderPath){
	            Remove-Item $folderPath -recurse -force > $null
            }
    
            New-Item $folderPath -Type directory -Force > $null
        }
    }
    catch {
     report ("Could not remove folder " + $folderPath)
    }

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $folderPath)

}

function interpolate($Pattern, $Replacement){

    begin {}
    process {report $_.Replace($Pattern, $Replacement) }
    end {}

}

function interpolate_file($InputFile, $Pattern, $Replacement){
   
    $replaced = ""

    Get-Content $InputFile | Foreach-Object {$_.Replace($Pattern,  $Replacement)} | Set-Variable  -Name "replaced"

    report $replaced

}

function escape([string] $value){
    report $value.Replace('\', '\\')
}

function hash([string] $value){    
    $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = new-object -TypeName System.Text.UTF8Encoding
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($value))).ToLower().Replace('-', '')
    report $hash
}

function formatElapsedTime($ts) {
    $elapsedTime = ""

    if ( $ts.Minutes -gt 0 )
    {
        $elapsedTime = [string]::Format( "{0:00} min. {1:00}.{2:00} sec.", $ts.Minutes, $ts.Seconds, $ts.Milliseconds / 10 );
    }
    else
    {
        $elapsedTime = [string]::Format( "{0:00}.{1:00} sec.", $ts.Seconds, $ts.Milliseconds / 10 );
    }

    if ($ts.Hours -eq 0 -and $ts.Minutes -eq 0 -and $ts.Seconds -eq 0)
    {
        $elapsedTime = [string]::Format("{0:00} ms.", $ts.Milliseconds);
    }

    if ($ts.Milliseconds -eq 0)
    {
        $elapsedTime = [string]::Format("{0} ms", $ts.TotalMilliseconds);
    }

    return $elapsedTime
}


function execSqlCmd([String]$server, [String] $dbType, [string]$database, [String]$user, [String]$pass, [String] $sql){
 <#


 https://technet.microsoft.com/en-us/magazine/hh855069.aspx
 
 http://www.postgresql.org/ftp/odbc/versions/

 #>
    $provider = ""
    switch ($dbType.ToLower()) {
        "sqlserver" {
            $provider ="SQLOLEDB"
        }
        "oracle" {
            $provider ="msdaora"
        }
        "mysql" {
            $provider ="MySQLProv"
        }
        "postgresql" {
            $provider = "MSDASQL"
        }
    }
    
	$conn = New-Object System.Data.OleDb.OleDbConnection

	$connString = "Provider=$provider;Server=$server;Database=$database;Uid=$user;Pwd=$pass;"
		
    $conn.ConnectionString = $connString

    try{    
        $conn.Open() > $null    
        report "Connected to $server"
    }
    catch {
        report "Could not connect to database server: $server"
        exit -1
    }
   
    
    $cmd =  $conn.CreateCommand()
    
    $cmd.CommandText = $sql

    $cmd.CommandTimeout = 0

    $cmd.ExecuteNonQuery() > $null

    $cmd.Dispose()

    $conn.Close()
    
    $conn.Dispose()

}


function createDatabase($dbname){
    report "Creating database: $dbname"

    $sql = interpolate_file $__skelDirectory\database\$DEFAULT_DB_TYPE\create_database.sql DB_NAME $dbname

	execSqlCmd $DEFAULT_DB_SERVER $DEFAULT_DB_TYPE "master" $DEFAULT_DB_ADMIN_USER $DEFAULT_DB_ADMIN_PASS $sql

    report "$dbname created"
}


function createUser($dbname, $user, $pass, $schema){
    report "Creating user: $user"

    $sql = interpolate_file $__skelDirectory\database\$DEFAULT_DB_TYPE\create_user.sql DB_NAME $dbname |
        interpolate DB_USER $user |
        interpolate DB_PASS $pass |
        interpolate DB_SCHEMA $schema    
	
	execSqlCmd $DEFAULT_DB_SERVER $DEFAULT_DB_TYPE $dbname $DEFAULT_DB_ADMIN_USER $DEFAULT_DB_ADMIN_PASS $sql

    report "$user created"
}


function removeDatabase($dbname){
    report "Removing database: $dbname"

    $sql = interpolate_file $__skelDirectory\database\$DEFAULT_DB_TYPE\remove_database.sql DB_NAME $dbname

    execSqlCmd $DEFAULT_DB_SERVER $DEFAULT_DB_TYPE "master" $DEFAULT_DB_ADMIN_USER $DEFAULT_DB_ADMIN_PASS $sql

    report "Database $dbname removed"

}

function removeUser($dbname, $user, $pass, $schema){
    report "Removing user: $user"

    $sql = interpolate_file $__skelDirectory\database\$DEFAULT_DB_TYPE\remove_user.sql DB_NAME $dbname |
        interpolate DB_USER $user |
        interpolate DB_PASS $pass |
        interpolate DB_SCHEMA $schema    

    execSqlCmd $DEFAULT_DB_SERVER $DEFAULT_DB_TYPE "master" $DEFAULT_DB_ADMIN_USER $DEFAULT_DB_ADMIN_PASS $sql

    report "User $user removed"
}