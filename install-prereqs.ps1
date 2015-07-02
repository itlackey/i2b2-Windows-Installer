
require $env:JAVA_HOME "JAVA_HOME must be set"
require $env:ANT_HOME "ANT_HOME must be set"
require $env:JBOSS_HOME "JBOSS_HOME must be set"
require $JBOSS_ADDRESS "JBOSS_ADDRESS must be set"
require $JBOSS_PORT "JBOSS_PORT must be set"
require $JBOSS_ADMIN "JBOSS_ADMIN must be set"
require $JBOSS_PASS "JBOSS_PASS must be set"

#Install chocolatey https://chocolatey.org/
#iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

function installJava{
    if((isJavaInstalled) -eq $false){
        $client = new-object System.Net.WebClient 
        $cookie = "oraclelicense=accept-securebackup-cookie"
        $client.Headers.Add([System.Net.HttpRequestHeader]::Cookie, $cookie) 

        echo "Downloading Java JDK"
    
        $client.downloadFile($__javaDownloadUrl, $__tempFolder + "\jdk.exe")
    		if($Logging -eq $true){
			Add-Content "`n" + "Test"
		}
        echo "Java Downloaded"

        echo "Installing Java to $env:JAVA_HOME"

        $__javaInstallerPath = $__tempFolder + "\jdk.exe"

        exec $__javaInstallerPath '/s INSTALLDIR=c:\opt\java /L C:\opt\java-install.log'    

        addToPath "$env:JAVA_HOME\bin;"
    }
    else{

		echo "Setting JAVA_HOME directory..."

		$javaPath = getJavaFolder
		setEnvironmentVariable JAVA_HOME $javaPath
		addToPath "$env:JAVA_HOME\bin;"

	}
	echo "Java Installed"
}

function installAnt {
    if((isAntInstalled) -eq $false){

        echo "Downloading ant"
  
        wget $__antDownloadUrl -OutFile $__tempFolder"\ant.zip"

        echo "Ant Downloaded"

        echo "Installing Ant"
 
        unzip $__tempFolder"\ant.zip" $env:ANT_HOME"\..\"

        mv $env:ANT_HOME"\..\"$__antFolderName $env:ANT_HOME   

        addToPath "$env:ANT_HOME\bin;"
    }
    echo "Ant Installed"
}

function installJBoss{
    if((test-path $env:JBOSS_HOME) -eq $false){
      
        echo "Downloading $__jbossDownloadUrl"

        wget $__jbossDownloadUrl -OutFile $__tempFolder\jboss.zip
     
        echo "JBOSS downloaded"

        echo "Installing JBOSS"

        unzip $__tempFolder\jboss.zip $env:JBOSS_HOME\..\

        mv $env:JBOSS_HOME\..\$__jbossFolderName $env:JBOSS_HOME

        mv $env:JBOSS_HOME\standalone\configuration\standalone.xml $env:JBOSS_HOME\standalone\configuration\standalone.xml.bak

        interpolate_file skel\jboss\standalone.xml JBOSS_ADDRESS $JBOSS_ADDRESS |
            interpolate JBOSS_PORT $JBOSS_PORT | 
            Out-File -Encoding utf8 $env:JBOSS_HOME\standalone\configuration\standalone.xml
    
        addToPath "$env:JBOSS_HOME\bin;"

    }
    echo "JBOSS Installed"
}

function installJBossService{
    $jbossSvc = Get-Service jboss*
    if($jbossSvc -eq $null){
        echo "Downloading $__jbossServiceDownloadUrl"
    
        wget $__jbossServiceDownloadUrl -OutFile $__tempFolder\jboss-svc.zip
            
        echo "JBOSS Service downloaded"

        echo "Installing JBOSS Service"
        
        unzip $__tempFolder\jboss-svc.zip $env:JBOSS_HOME
        
        cp skel\jboss\service.bat $env:JBOSS_HOME\bin\service.bat -force
    
        &$env:JBOSS_HOME\bin\service.bat install

        Set-Service jboss -StartupType Automatic
       
        echo "Adding management user to JBOSS"

        $hashPass = hash ($JBOSS_ADMIN + ":ManagementRealm:" + $JBOSS_PASS)

        $jbossUser = "$JBOSS_ADMIN=$hashPass" 

        echo $jbossUser

        echo ([Environment]::NewLine)$jbossUser |
            Out-File  $env:JBOSS_HOME\standalone\configuration\mgmt-users.properties -Append -Encoding utf8
    }
    echo "JBOSS service installed"
}

function installAxis{
    if(!(Test-Path "$env:JBOSS_HOME\standalone\deployments\i2b2.war"))
    {
        
        echo "Downloading AXIS"
       
        wget $__axisDownloadUrl -OutFile $__tempFolder\axis2-1.6.2-war.zip
      
        echo "AXIS downloaded"

        echo "Installing AXIS War"

        unzip $__tempFolder\axis2-1.6.2-war.zip $__tempFolder\axis2-1.6.2-war $true
  
        unzip $__tempFolder\axis2-1.6.2-war\axis2.war $__tempFolder\i2b2.war $true

        mv -Force $__tempFolder\i2b2.war\ $env:JBOSS_HOME\standalone\deployments\

        echo "" > $env:JBOSS_HOME\standalone\deployments\i2b2.war.dodeploy
   

    }

    echo "AXIS War Installed"
}

function installIIS {
    $iis =  Get-WindowsOptionalFeature -FeatureName IIS-WebServerRole -Online

    if($iis.State -ne "Enabled"){
        echo "Installing IIS"
    
        Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -NoRestart
    }
    echo "IIS Installed"
}

function installPHP{

    if((Test-Path $__phpInstallFolder) -eq $false){

        echo "Downloading PHP"      
        #Reference: http://php.net/manual/en/install.windows.manual.php
        wget $__phpDownloadUrl -OutFile $__tempFolder/php.zip
        echo "PHP Downloaded"

        echo "Installing PHP"

        unzip $__tempFolder/php.zip $__phpInstallFolder
        cp $__skelDirectory\php\php.ini $__phpInstallFolder\php.ini
     
        echo "Downloading Visual C++ Redistributable for Visual Studio 2012 Update 4"
        wget $__vcRedistDownloadUrl -OutFile $__tempFolder/vcredist_x86.exe    
        #cp .\_downloads\vcredist_x86.exe $__tempFolder\vcredist_x86.exe
        echo "Visual C++ Redistributable for Visual Studio 2012 Update 4 downloaded"

        echo "Installing Visual C++ Redistributable for Visual Studio 2012 Update 4"
        exec $__tempFolder\vcredist_x86.exe '/install /quiet'
        echo "Visual C++ Redistributable for Visual Studio 2012 Update 4 installed"

        echo "Configuring IIS"
        #Reference: http://php.net/manual/en/install.windows.iis7.php
        $cgi =  Get-WindowsOptionalFeature -FeatureName IIS-CGI -Online

        if($cgi.State -ne "Enabled"){
            Enable-WindowsOptionalFeature -FeatureName IIS-CGI -Online -NoRestart
        }

        #Creating IIS FastCGI process pool
        & $env:WinDir\system32\inetsrv\appcmd.exe set config -section:system.webServer/fastCgi /+"[fullPath='c:\php\php-cgi.exe']" /commit:apphost
       
        #Creating handler mapping for PHP requests      
        & $env:WinDir\system32\inetsrv\appcmd.exe set config  -section:system.webServer/handlers /+"[name='PHP-FastCGI',path='*.php',verb='GET,HEAD,POST',modules='FastCgiModule',scriptProcessor='c:\php\php-cgi.exe',resourceType='Either']"

        echo "IIS Configured"

        addToPath c:\php
    }
    echo "PHP Installed"
}

#Takes the boolean value $service for option to install tomcat service
#$service is true by default
function installTomcat($service=$true){


    #Create temp downloads folder
    echo "creating directories..."
    if(!(Test-Path $__tempFolder\shrine )){
        echo "creating temporary download location..."
        mkdir $__tempFolder\shrine
    }

    echo "creating tomcat directory..."
    if(Test-Path $_SHRINE_HOME\tomcat ){
        Remove-Item $_SHRINE_HOME\tomcat -Recurse
    }
    mkdir $_SHRINE_HOME\tomcat
    echo "tomcat directory created."

    echo "downloading tomcat archive..."
    
    #Download tomcat archive, unzip to temp directory, copy contents to shrine\tomcat folder
    #and remove the downloads and temp folders
    if(Test-Path $__tempFolder\shrine\$__tomcatName.zip){
        Remove-Item $__tempFolder\shrine\$__tomcatName.zip
    }
    Invoke-WebRequest $__tomcatDownloadUrl -OutFile $__tempFolder\shrine\$__tomcatName.zip

    echo "download complete."
    echo "unzipping archive..."
    
    unzip $__tempFolder\shrine\$__tomcatName.zip $__tempFolder\shrine

    echo "moving to tomcat directory"

    Copy-Item $__tempFolder\shrine\apache-tomcat-$__tomcatVersion\* -Destination $_SHRINE_HOME\tomcat -Container -Recurse

    #This environment variable is required for Tomcat to run and to install as a service
    setEnvironmentVariable "CATALINA_HOME" $_SHRINE_HOME\tomcat

    if($service){
    #This will set the service to Automatic startup, rename it to Apache Tomcat 8.0 and start it.

    echo "installing Tomcat service..."
    & "$Env:CATALINA_HOME\bin\service.bat" install
    
	$tomcatExe = $__tomcatName.ToLower()

    & $Env:CATALINA_HOME\bin\$tomcatExe //US//$__tomcatName --DisplayName="Apache Tomcat $__tomcatVersion"

    echo "setting Tomcat service to Automatic and starting..."
    Set-Service $__tomcatName -StartupType Automatic
    Start-Service $__tomcatName   

    echo "Tomcat service set to Automatic and running!"
    }

    echo "Tomcat is installed."
}

installJava
installAnt

if($InstallCells -eq $true){
    installJBoss
    installJBossService
    installAxis
}

if(($InstallWebClient -eq $true) -or ($InstallAdminTool -eq $true)){
    installIIS
    installPHP
}

if($InstallShrine -eq $true){
    installTomcat
}