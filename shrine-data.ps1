﻿. .\common.ps1
. .\functions.ps1
. .\configuration.ps1
. .\config-i2b2.ps1

function createDatabase($dbname){
    echo "Creating database: $dbname"

    $sql = interpolate_file $__skelDirectory\i2b2\data\$DEFAULT_DB_TYPE\create_database.sql DB_NAME $dbname

    $cmd =  $conn.CreateCommand()
    
    $cmd.CommandText = $sql

    $cmd.ExecuteNonQuery() > $null

    $cmd.Dispose()

    echo "$dbname created"

}

function createUser($dbname, $user, $pass, $schema){
    echo "Creating user: $user"

    $sql = interpolate_file $__skelDirectory\i2b2\data\$DEFAULT_DB_TYPE\create_user.sql DB_NAME $dbname |
        interpolate DB_USER $user |
        interpolate DB_PASS $pass |
        interpolate DB_SCHEMA $schema    

    $cmd =  $conn.CreateCommand()
    
    $cmd.CommandText = $sql

    $cmd.ExecuteNonQuery() > $null

    $cmd.Dispose()

    echo "$user created"
}

function installShrineData{

    echo "Creating Shrine Database..."

    createDatabase $SHRINE_DB_NAME

    echo "Shrine Database created."
    echo "Creating Shrine DB user..."

    createUser $SHRINE_DB_NAME $SHRINE_DB_USER $SHRINE_DB_PASS $SHRINE_DB_SCHEMA

    echo "Shrine DB User created."
    echo "updating i2b2 Ontology and CRC Database Tables..."

    $sql = interpolate_file $__skelDirectory\shrine\$DEFAULT_DB_TYPE\configure_hive_db_lookups.sql DB_NAME $HIVE_DB_NAME |
        interpolate I2B2_DOMAIN_ID $I2B2_DOMAIN |
        interpolate SHRINE $SHRINE_DB_PROJECT |
        interpolate I2B2_DB_SHRINE_ONT_DATABASE.I2B2_DB_SCHEMA $SHRINE_DB_SCHEMA |
        interpolate I2B2_DB_SHRINE_ONT_DATASOURCE_NAME $SHRINE_DB_DATASOURCE |
        interpolate SQLSERVER $DEFAULT_DB_TYPE.ToUpper() |
        interpolate I2B2_DB_CRC_DATABASE.I2B2_DB_SCHEMA $CRC_DB_SCHEMA |
        interpolate I2B2_DB_CRC_DATASOURCE_NAME $CRC_DB_DATASOURCE

    $cmd = $conn.CreateCommand()

    $cmd.CommandText = $sql

    $cmd.ExecuteNonQuery() > $null

    $sql = interpolate_file $__skelDirectory\shrine\sqlserver\configure_pm.sql DB_NAME $PM_DB_NAME |
        interpolate SHRINE_USER $SHRINE_DB_USER |
        interpolate SHRINE_PASSWORD_CRYPTED $SHRINE_DB_PASS |
        interpolate SHRINE $SHRINE_DB_PROJECT |
        interpolate SHRINE_IP $_SHRINE_IP |
        interpolate SHRINE_SSL_PORT $_SHRINE_SSL_PORT
    
    $cmd = $conn.CreateCommand()

    $cmd.CommandText = $sql

    $cmd.ExecuteNonQuery() > $null
    
    $cmd.Dispose()

    updateOntDB

    updateDatasources

    echo "i2b2 Ontology and CRC Database Tables updated."

}

function updateDatasources{

    mkdir $__skelDirectory\shrine\sqlserver\backup
    #Copy-Item $env:JBOSS_HOME\standalone\deployments\ont-ds.xml $__skelDirectory\shrine\sqlserver\backup\ont-ds.xml
    Copy-Item C:\BOB\ont-ds.xml $__skelDirectory\shrine\sqlserver\backup\ont-ds.xml

    interpolate_file $__skelDirectory\shrine\sqlserver\ont-ds.xml I2B2_DB_HIVE_DATASOURCE_NAME "OntologyBootstrapDS" |
        interpolate I2B2_DB_HIVE_JDBC_URL $HIVE_DB_URL |
        interpolate I2B2_DB_HIVE_USER $HIVE_DB_USER |
        interpolate I2B2_DB_HIVE_PASSWORD $HIVE_DB_PASS |
        interpolate I2B2_DB_ONT_DATASOURCE_NAME $ONT_DB_DATASOURCE |
        interpolate I2B2_DB_ONT_JDBC_URL $ONT_DB_URL |
        interpolate I2B2_DB_ONT_USER $ONT_DB_USER |
        interpolate I2B2_DB_ONT_PASSWORD $ONT_DB_PASS |
        interpolate I2B2_DB_SHRINE_ONT_DATASOURCE_NAME $SHRINE_DB_DATASOURCE |
        interpolate I2B2_DB_SHRINE_ONT_JDBC_URL $SHRINE_DB_URL |
        interpolate I2B2_DB_SHRINE_ONT_USER $SHRINE_DB_USER |
        interpolate I2B2_DB_SHRINE_ONT_PASSWORD $SHRINE_DB_PASS | sc $env:JBOSS_HOME\standalone\deployments\ont-ds.xml -Force

}

function updateOntDB{
    
    $SHRINE_SQL_FILE_URL_SUFFIX = "SHRINE_Demo_Downloads/ShrineDemo.sql"
    $SHRINE_SQL_FILE_URL = "$_SHRINE_SVN_URL_BASE/ontology/$SHRINE_SQL_FILE_URL_SUFFIX"

    $ontConn = New-Object System.Data.SqlClient.SqlConnection

    $ontConn.ConnectionString = "Server=$DEFAULT_DB_SERVER;Database=$ONT_DB_NAME;Uid=$ONT_DB_USER;Pwd=$ONT_DB_PASS;"
   
    try{    
        $ontConn.Open() > $null    
        echo "Connected to $DEFAULT_DB_SERVER"
    }
    catch {
        echo "Could not connect to database server: $DEFAULT_DB_SERVER"
        exit -1
    }

    $sql = interpolate_file $__skelDirectory\shrine\sqlserver\ontology_create_tables.sql DB_NAME $ONT_DB_NAME |
        interpolate I2B2_DB_SCHEMA $DEFAULT_DB_SCHEMA

    $ontCmd = $ontConn.CreateCommand()

    $ontCmd.CommandText = $sql

    $ontCmd.ExecuteNonQuery() > $null

    $sql = interpolate_file $__skelDirectory\shrine\sqlserver\ontology_table_access.sql DB_NAME $ONT_DB_NAME |
        interpolate I2B2_DB_SCHEMA $DEFAULT_DB_SCHEMA

    $ontCmd = $ontConn.CreateCommand()

    $ontCmd.CommandText = $sql

    $ontCmd.ExecuteNonQuery() > $null

    Invoke-WebRequest $SHRINE_SQL_FILE_URL -OutFile $__skelDirectory\shrine\sqlserver\shrine.sql

    echo "sending first package"
    
    $sql = Get-Content "$__skelDirectory\shrine\sqlserver\shrine.sql"

    $ontCmd = $ontConn.CreateCommand()

    $ontCmd.CommandText = $sql

    $ontCmd.CommandTimeout = 0
   
    $ontCmd.ExecuteNonQuery() > $null
    
    echo "package finished"
    
    $ontCmd.Dispose()

    Remove-Item $__skelDirectory\shrine\sqlserver\shrine.sql

    $ontConn.Close()
    $ontConn.Dispose()

}


echo "Starting Shrine Data Installation"
echo "Verifying connection to database server"

$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = "Server=$DEFAULT_DB_SERVER;Database=master;Uid=$DEFAULT_DB_ADMIN_USER;Pwd=$DEFAULT_DB_ADMIN_PASS;"
 
try{    
    $conn.Open() > $null    
    echo "Connected to $DEFAULT_DB_SERVER"
}
catch {
    echo "Could not connect to database server: $DEFAULT_DB_SERVER"
    exit -1
}

installShrineData

$conn.Close()
$conn.Dispose()

echo "Shrine Data Installation Completed"
