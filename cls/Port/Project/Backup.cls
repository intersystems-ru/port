Class Port.Project.Backup Extends %RegisteredObject
{

Property BackupDirectory As %String [ Internal, Private ];

Property Logger As Port.Project.Importer;

Property IsRequired As %Boolean [ InitialExpression = 0 ];

Property ImportList As %String [ MultiDimensional ];

Method %OnNew(backupDir As %String) As %Status
{
  set ..BackupDirectory = backupDir
  quit $$$OK
}

Method Create(ByRef list As %String = 0) As %Status
{
   
  set sc = $$$OK
  set itemName = ""
  set backupCount = 0
  set appPath = $System.CSP.GetDefaultApp($namespace)
  set appPath = $extract(appPath, 2, *)
  set backupFolderIsCreated = 0
  
  if '..IsRequired quit $$$OK
  
  do ..Logger.Log("Starting backup ... [nl]DO NOT INTERRUPT THIS PROCESS![nl]", 1)
  do ..Logger.Log("Mirroring structure to temporary directory ... ", 1)
  
  do Scan(9,  "CSR", .created)
  do Scan(10, "CSP", .created)
  
  if $$$ISOK(sc) do ..Logger.Log(" done.", 1)
  else  do ..Logger.Log(" done with errors!", 1)
  do ..Logger.Log("[nl][nl]", 1)
  quit sc  


Scan(group, type, created)
  set itemName = ""
  set created  = 0   
  for {
    set itemName = $order(list(group, type, itemName), 1, paths)
    quit:itemName=""
    
    set backupOrigin = $listget(paths, 2)
    set newVersion = $listget(paths, 1)
    // TODO: Add extra check to avoid backing up files that are not really outdated.
    // Don't backup or remove anything if target file is not present in the project
    // or doesn't exists in the app.
    if '(##class(%File).Exists(backupOrigin) && ##class(%File).Exists(newVersion)) {
      continue
    }
    set backupDestination = ##class(%File).NormalizeFilename(..BackupDirectory_"/"_$replace(itemName, appPath, ""))
    set parentBackupDirectory = ##class(%File).GetDirectory(backupDestination)
    set sc = ##class(Port.Project.Helper).ImplyDirectoryCreation(parentBackupDirectory)
    if $$$ISERR(sc) quit
    
    set created = 1    
    set isCopied = ##class(%File).CopyFile(backupOrigin, backupDestination, 1)
    set isDeleted = ##class(%File).Delete(backupOrigin)
    if isCopied = 0 || (isDeleted = 0) {
      set sc = $$$ADDSC(sc, $$$ERROR($$$GeneralError, "Unable to copy "_itemName_" to backup destination. Aborting."))
    }   
  }
  if 'created {
    set ..IsRequired = 0
  }
}

}

