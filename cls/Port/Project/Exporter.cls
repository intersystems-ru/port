Include portutils

Class Port.Project.Exporter Extends Port.Project.Base
{

Property PathDependencies As array Of %String [ Private ];

Property ExportedPackages As %List [ Private ];

Property Synchronizer As Synchronizer [ Private ];

Method %OnNew(path As %String, logLevel As %Integer = 2, sourceExtension As %String = "") As %Status
{
  $$$QuitOnError(##super(path, logLevel, sourceExtension))  
       
  if '$isobject(..Project) {
    set ..ProjectName = "null"
    throw ##class(%Exception.StatusException).CreateFromStatus($$$PERROR($$$ExportingProjectNotFound, ..ProjectName))
  }
  set ..Synchronizer = ##class(Synchronizer).%New($this)
  return $$$OK
}

Method Export() As %Status
{
  
  set ..IsBatch = 1
  do ..Reset()
  do ..Synchronizer.Reset()
  
  write ..LogLine($$$ExportingProject, 0, ..Project.Name)
  
  $$$QuitOnError(..ExportProjectItems(.exportList))
  
  if ..AffectedCount > 0 {
    write ..LogLine($$$SourceExportedToPath, 0, ..BasePath)
  } else {
    write ..LogLine($$$NoItemsToExport, 0, ..Project.Name)
  }
  
  write ..LogLine($$$SynchronizingProject, 0, ..Project.Name)
  
  $$$QuitOnError(..Synchronizer.Purge())
  
  write ..LogLine($$$AllDone, 0)
  return $$$OK
}

Method ExportProjectItems(ByRef exportList As %List = "") As %Status [ Private ]
{
  set sc = $$$OK
  set s = ##class(%SQL.Statement).%New()
  $$$QuitOnError(s.%PrepareClassQuery("%Studio.Project", "ProjectItemsList"))
  set r = s.%Execute(..ProjectName, 1) 
  while r.%Next(.sc) {
    if $$$ISERR(sc) quit
    set itemName = r.%Get("Name")
    set itemType = r.%Get("Type")
    set sc = $$$ADDSC(sc, ..ExportItem(itemName, itemType, .exportList))
  }
  return sc
}

Method ExportItem(itemName As %String, type As %String = "", ByRef exportList As %List = "") As %Status
{
  if ##class(Port.Util).IsRoutine(itemName) return ..ExportRoutine(itemName)
  
  set itemType = $case(type, "": ##class(Port.Util).ResolveItemExtension(itemName), : type)
  if itemType = "PKG" return ..ExportPackage(itemName, .exportList)
  if itemType = "CLS" return ..ExportClass(itemName, .exportList)
  
  return ..ExportWebFile(itemName, .exportList)
}

Method ExportPackage(packageName As %String, exportList As %String = "") As %Status
{
  set id = ##class(Port.Util).MountIdFromName(packageName_".PKG", ..Project.Name)
  if '##class(%Studio.ProjectItem).%ExistsId(id) return $$$OK
  
  if $listfind(i%ExportedPackages, packageName) return $$$OK  
  
  set classList = $System.OBJ.GetPackageList(.classList, packageName)
  set className = ""
  set sc = $$$OK
  for {
    set className = $order(classList(className))
    quit:className=""
    set err = ..ExportClass(className, .exportList, 1)
    if $$$ISERR(err) {
      if $$$ISOK(sc) set sc = err
      else  set sc = $$$ADDSC(sc, err)
    }
  }
  set $list(exportList, *+1) = "cls/"_packageName
  set $list(i%ExportedPackages, *+1) = packageName
  return sc
}

Method ExportWebFile(itemName As %String, ByRef exportList As %List = "") As %Status
{
  set id = ##class(Port.Util).MountIdFromName(itemName, ..Project.Name)  
  if '##class(%Studio.ProjectItem).%ExistsId(id) return $$$OK
      
  $$$QuitOnError(##class(Port.Util).CSPLogicalToPhysicalPath(itemName, .source))
  set dest = ##class(Port.Util).GetItemSourcePathFromWorkspace(itemName, ..Project.Name)
  set path = ##class(%File).GetDirectory(dest) 
  
  $$$QuitOnError(##class(Port.Util).CreateMissingPath(path))
  $$$QuitOnError(..Synchronizer.AddToWhitelist(source, dest))
  
  if ..Overwrite = 0 && '..IsOutdated(source, dest) return $$$OK
  
  write ..Log($$$ExportingType, 1, $$$FileType, dest)  
  set exported = ##class(%File).CopyFile(source, dest)  
  
  if exported = 0 {
    write ..LogLine($$$Failed)
    return $$$PERROR($$$UnableToCopySource, source, dest)
  }
  
  write ..LogLine($$$Done)
  set ..AffectedCount = ..AffectedCount + 1
  
  set $list(exportList, *+1) = dest  
  return $$$OK
}

Method ExportRoutine(name As %String, exportList As %List = "") As %Status
{
  set id = ##class(Port.Util).MountIdFromName(name, ..Project.Name)
  if '##class(%Studio.ProjectItem).%ExistsId(id) return $$$OK

  set dest = ##class(Port.Util).GetItemSourcePathFromWorkspace(name, ..Project.Name, ..SourceExtension)  
  set path = ##class(%File).GetDirectory(dest)
  
  $$$QuitOnError(..Synchronizer.AddToWhitelist(name, dest))
  
  if '##class(%RoutineMgr).Exists(name) return $$$PERROR($$$UnableToExportInvalidItem, name)
  $$$QuitOnError(##class(Port.Util).CreateMissingPath(path))
      
  if ..Overwrite = 0 && '..IsOutdated(name, dest) return $$$OK
  
  write ..Log($$$ExportingType, 1, $$$RoutineType, name)
  
  set file = ##class(%FileCharacterStream).%New()
  set file.Filename = dest
  
  set routine = ##class(%RoutineMgr).%OpenId(name)  
  set sc = file.CopyFrom(routine.Code)
  
  if $$$ISERR(sc) write ..LogLine($$$Failed) return sc 
  
  write ..LogLine($$$Done)
    
  set $list(exportList, *+1) = dest
  
  $$$QuitOnError(file.%Save())
  
  set ..AffectedCount = ..AffectedCount + 1
  return $$$OK
}

Method ExportClass(className As %String, ByRef exportList As %String = "", fromPackage As %Boolean = 0) As %Status
{
  
  // Checks if this entry is coming from %SourceControl and fixes it removing the CLS type.
  if ##class(Port.Util).ResolveItemExtension(className) = "CLS" {
    set className = $piece(className, ".", 1, *-1)
  } 
  
  set itemName = className_".CLS"
  
  // Cannot export classes that don't belong to the project.
  set id = ##class(Port.Util).MountIdFromName(itemName, ..Project.Name)
  // Cannot check for the class item id if the call was delegated by ExportPackage.
  if 'fromPackage && '##class(%Studio.ProjectItem).%ExistsId(id) return $$$OK    
  
  set package = $piece(itemName, ".", 1, *-1)
  set dest = ##class(Port.Util).GetItemSourcePathFromWorkspace(itemName, ..Project.Name, ..SourceExtension)
  set path = ##class(%File).GetDirectory(dest)  
  
  $$$QuitOnError(..Synchronizer.AddToWhitelist(itemName, dest))
  if $listfind(..ExportedPackages, package) return $$$OK  
  
  $$$QuitOnError(##class(Port.Util).CreateMissingPath(path))
  
  if ..Overwrite = 0 && '..IsOutdated(itemName, dest) return $$$OK
  
  write ..Log($$$ExportingType, 1, $$$ClassType, className)
  
  if '##class(%ClassDefinition).%ExistsId(className) {
    write ..LogLine($$$Failed)
    return $$$ERROR($$$UnableToExportInvalidItem, className)
  }
  
  $$$QuitOnError(##class(%Compiler.UDL.TextServices).GetTextAsFile($namespace, itemName, dest))
  write ..LogLine($$$Done)
  
  set ..AffectedCount = ..AffectedCount + 1
  set $list(exportList, *+1) = dest
  
  return $$$OK
}

Method Reset() As %Status
{
  set i%ExportedPackages = ""
  do ..PathDependencies.Clear()
}

}

