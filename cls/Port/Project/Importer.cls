Class Port.Project.Importer Extends Port.Project.Base
{

Property IsNewProject As %Boolean [ InitialExpression = 0, Private ];

Property CSPPath As %String [ Private ];

Property Backup As Port.Project.Backup [ Private ];

Property BackupDirectory As %String [ Internal ];

Property SkipBackup As %Boolean [ InitialExpression = 0 ];

Property ImportList As %String [ InitialExpression = 0, MultiDimensional ];

Property ItemsList As %String [ InitialExpression = 0, MultiDimensional, Private ];

Method %OnNew(inputPath As %String, logLevel As %Integer = 2, sourceExtension As %String = "") As %Status
{
  $$$QuitOnError(##super(inputPath, logLevel, sourceExtension))
  
  set installDirectory = $System.Util.InstallDirectory()
  
  set ..CSPPath = ##class(%File).NormalizeFilename(installDirectory_"csp/"_$$$lcase($namespace))  
  set ..BackupDirectory = ##class(%File).NormalizeFilename(..BasePath_"/__backup__/")
  set ..Backup = ##class(Port.Project.Backup).%New(..BackupDirectory)
  set ..Backup.Logger = ..Logger
  
  set i%ImportList = 0
  set i%ItemsList = 0
  
  if '$isobject(..Project) {
    set ..IsNewProject = 1
    set ..Project = ##class(%Studio.Project).%New()
    set ..Project.Name = ..ProjectName
  }
  quit $$$OK
}

Method EnqueueAll() As %Status
{
  do ..ResetLists()
  
  set sc = $$$OK
  for i = ..IncPath, ..IntPath, ..ClassPath, ..MacPath, ..BasPath, ..MviPath, ..MvbPath, ..DfiPath, ..WebPath {
    set sc = ..EnqueueDirectory(i)
    if $$$ISERR(sc) quit
  }
  quit sc
}

Method EnqueueItem(target As %String) As %Status
{
  set isWebPath = target [ ..WebPath  
  
  set sc = ..Describe(target, isWebPath, .described, .isOutdated, .internalFileName, .itemName, .itemType, .group, .alias)
  $$$QuitOnError(sc)
  
  if described && '$data(i%ItemsList(itemName)) {
    if '..Backup.IsRequired && '..SkipBackup && ((itemType = "CSP") || (itemType = "CSR") && isOutdated) {
      set ..Backup.IsRequired = 1
    }
    set i%ItemsList = $increment(i%ItemsList)
    set i%ItemsList(itemName) = ""  
        
    if isOutdated || ..Overwrite {
      set i%ImportList = $increment(i%ImportList)
      set i%ImportList(group, itemType, alias) = $listbuild(target, internalFileName)
    }    
    set enqueued = 1
  } 
  quit enqueued
}

Method EnqueueDirectory(searchPath As %String, fs As %SQL.Statement = {$$$NULLOREF}) As %Status
{
  
  if '..IsBatch && '$isobject(fs) {
    do ..ResetLists()
  }
  
  if ..IsIgnored(searchPath) quit $$$OK
  
  if '$isobject(fs) {
    set fs = ##class(%SQL.Statement).%New()
    $$$QuitOnError(fs.%PrepareClassQuery("%File", "FileSet"))
  }
  
  set sc = $$$OK
  set rows = fs.%Execute(searchPath)  
  
  while rows.%Next(.sc) {
    if $$$ISERR(sc) quit 
    set compilable = 0
    set type = rows.%Get("Type")
    set external = rows.%Get("Name")
    if type = "F" { 
      set sc = ..EnqueueItem(external) 
      if $$$ISERR(sc) quit
    } elseif type = "D" {
      set targetDir = $piece(external, ..Slash, *)
      if '(targetDir?1".".AN) {
        set sc = ..EnqueueDirectory(external, fs)
        if $$$ISERR(sc) quit
      }
    }   
  }
  quit sc
}

Method GetTypePriority(type As %String) As %Integer [ Internal, Private ]
{
  if type = ".INC" quit 1
  if type = ".INT" quit 2
  if type = ".CLS" quit 3
  if type = ".MAC" quit 4
  if type = ".MVI" quit 5
  if type = ".MVB" quit 6
  if type = ".BAS" quit 7
  if type = ".DFI" quit 8
  if type = ".CSR" quit 9
  quit 10
}

Method Describe(origin As %String, isWebPath As %Boolean = 0, described As %Boolean = 0, Output isOutdated As %Boolean = 0, Output itemDestination As %String, Output itemName As %String, Output itemType As %String, Output priority As %String, Output alias As %String) As %Status [ Internal, Private ]
{
  
  set described = 0 
  set extension = ..GetFileExtension(origin, isWebPath)
  set extSize = $length(..GetSourceExtension())
  
  if 'isWebPath $$$QuitOnError(..AssertValidExtension(origin))
  
  if '(extension?1".".AN) quit described
  if extension = "" quit described  
    
  set priority = ..GetTypePriority(extension)
  
  if extension = ".CLS" {
    set itemType = "CLS"
    set itemDestination = ##class(Port.Project.Helper).FileToClass(origin)      
    set itemName = itemDestination_extension
    set alias = itemDestination
    set described = 1
  } elseif $listfind($$$RoutineExtensions, extension) {
    set itemType = $piece(extension, ".", 2)    
    set itemDestination = $extract(##class(%File).GetFilename(origin), 1, *-(4 + extSize))_extension
    set itemName = itemDestination
    set alias = itemName
    set described = 1
  } else {
    if extension = ".CSR" set itemType = "CSR"
    else  set itemType = "CSP"
    $$$QuitOnError(##class(Port.Project.Helper).CSPPhysicalToLogicalPath(origin, .logicalPath))
    $$$QuitOnError(##class(Port.Project.Helper).CSPLogicalToPhysicalPath(logicalPath, .physicalPath))
    set itemName = logicalPath
    set itemDestination = physicalPath    
    set alias = itemName
    set described = 1
  }
  
  if '..Overwrite {
    set isOutdated = ..IsOutdated(itemName, origin, 1)
  } else {
    set isOutdated = 1
  }
  quit $$$OK
}

Method ImportList() As %Status [ Internal, Private ]
{
  set sc = $$$OK  
  
  for i=1:1:10 {
   set sc = ..ImportType(i)
   if $$$ISERR(sc) {
    set typeSC = $$$ERROR($$$GeneralError, "There were errors while importing "_$listget($$$ImportTypeDescriptions, i)_".")
    set typeSC = $$$EMBEDSC(typeSC, sc)
    set sc = typeSC 
   }
  }  
  quit sc
}

Method ImportType(group As %Integer) As %Status [ Internal, Private ]
{
  set sc = $$$OK
  if '$data(i%ImportList(group)) quit sc  
  
  set partialMessage = $listget($$$ImportTypeDescriptions, group)
  do ..WriteExclusive(1, "Importing {P1} ... ", partialMessage)
  set itemName = ""
  for {
    quit:'$data(i%ImportList(group))
    set itemType = $listget($$$ImportTypes, group, "CSP")
    set itemName = $order(i%ImportList(group, itemType, itemName), 1, paths)
    quit:itemName=""
    
    set origin = $listget(paths, 1)
    set destination = $listget(paths, 2)
    set fileType = itemType    
    
    do ..Write("Importing {P1} ", 2, $case(fileType,
      "CLS": "class "_itemName, 
      "MAC": "macro routine "_itemName, 
      "INT": "intermediate routine "_itemName, 
      "INC": "include routine "_itemName,
      "BAS": "Basic routine "_itemName,
      "MVB": "MV Basic routine "_itemName,
      "MVI": "MV Intermediate routine "_itemName,
      "DFI": "DFI XML "_itemName, :
      "file to "_destination)_" ...")
    set sc = $$$ADDSC(sc, ..ImportFromExternalSource(itemName, origin,  fileType, destination))
    if $$$ISERR(sc)  do ..Write("failed![nl]", 2) continue
    else  do ..Write("done.[nl]", 2)
  }
  do ..WriteExclusive(1, "done.[nl]")
  quit sc
}

Method ImportPartial(target As %String, importedList As %String = 0) As %Status
{
  
  #define NormalizePath(%path)  ##class(%File).NormalizeFilename(%path)
  set sc = $$$OK
  
  set resolvedTarget = ##class(%File).NormalizeFilename(target, ..BasePath)
  
  if (resolvedTarget = ..BasePath) {
    quit $$$ERROR($$$GeneralError, "Ambiguous TARGET and BASEPATH if you wish to import the project, use the method Import instead.")
  }
  
  if '(resolvedTarget [ ..ClassPath || (resolvedTarget [ ..IncPath) ||
      (resolvedTarget [ ..IncPath)  || (resolvedTarget [ ..MacPath) ||
      (resolvedTarget [ ..WebPath)) {    
    quit $$$ERROR($$$GeneralError, "Action supressed: attempted to import files outside the project scope.")
  }  
  
  if ##class(%File).DirectoryExists(resolvedTarget) {
    do ..Write("[nl]Enqueuing directory to be imported ...", 1)   
    set sc = ..EnqueueDirectory(resolvedTarget)
  } elseif ##class(%File).Exists(resolvedTarget) {
    do ..Write("[nl]Enqueuing item to be imported ...", 1)
    set sc = ..EnqueueItem(resolvedTarget)
  } else {
    do ..Write("[nl]Nothing to import.", 1)
    quit sc
  }
  
  if sc {
    do ..Write(" done.[nl]")
    set sc = ..Import()
    if $$$ISOK(sc) {
      set importedList = i%ImportList
      merge importedList = i%ImportList
    }
  } else {
    do ..Write(" failed.[nl]")
  }  
  quit sc
}

Method Import() As %Status
{
  set sc = $$$OK
  set onlyPopulateProject = 0
  set ..AffectedCount = 0
      
  tstart
  
  try {
    if ..IsBatch {
      do ..Write("[nl][nl]Importing project {P1} ...[nl]", 1, ..Project.Name)            
      do ..Write("[nl]Enqueuing items to import ... ", 1)
      $$$ThrowOnError(..EnqueueAll())
    }
      
    if i%ImportList > 0 {
      do ..Write("[nl]Found {P1} item{P2} to be imported.[nl]", 1, i%ImportList, $select(i%ImportList > 1 : "s", 1: ""))
      merge list = i%ImportList
      if '..SkipBackup $$$ThrowOnError(..Backup.Create(.list))
      $$$ThrowOnError(..ImportList())
    } else {
      do ..Write("[nl]No pending items were found inside the repository.", 1)
      do ..Write("[nl]Current repository might be empty or up-to-date.[nl]", 1)
    }
         
    if ..IsNewProject {
      do ..Write("[nl]Project doesn't exists. A new project will be created with the name {P1}.[nl]", 1, ..Project.Name)
    }
    
    if i%ImportList {
      do ..Write("[nl]Synchronizing {P1} ...", 1, ..Project.Name)
      $$$ThrowOnError(..SynchronizeProject(.added, .removed))
      do ..Write(" done.[nl]")
      do ..Write("[nl]Project {P1} has been saved with a total of {P2} items.", 1, ..Project.Name, ..Project.Items.Count())
    }
    
    set ..AffectedCount = i%ImportList    
    
    if ..Backup.IsRequired && '..SkipBackup {
      // If anything is ok until here, then delete the backup.
      do ..Write("[nl]Removing backup directory ...")
      set isRemoved = ##class(%File).RemoveDirectoryTree(..BackupDirectory)
      if isRemoved { 
        do ..Write(" done.[nl]")
        set ..Backup.IsRequired = 0
      } else  {
        set backupErrorMessage = "Unable to remove the directory "_..BackupDirectory
        do ..Write(" failed! Unable to clear directory.", 1)
        $$$ThrowOnError($$$ERROR(5001, backupErrorMessage))
      }
    }
    tcommit     
  } catch ex {
    set sc = ex.AsStatus()
    do ..Write("[nl][nl]FATAL: There were errors preventing the project to be imported:[nl]", 1)
    do $System.OBJ.DisplayError(sc)
    do ..Write("[nl][nl]The importer will now rollback all changes.[nl]", 1)
    do ..Write("PLEASE DO NOT INTERRUPT THIS PROCESS OR INTEGRITY WILL BE LOST![nl]", 1)
    do ..Write("Rolling back to the last working snapshot ...", 1)

    // Rolls back the database to recover last working Cach� files.
    trollback
    do ..Write(" done.[nl]")
    
    if ..Backup.IsRequired {
      do ..Write("Reverting {P1} using backup version ...", 1, $System.CSP.GetDefaultApp($namespace))
      set isCopied = ##class(%File).CopyDir(..BackupDirectory, ..CSPPath, 1)
      if isCopied { do ..Write(" done.[nl]") }
      else {
        do ..Write(" failed![nl]")
        do ..Write("Failed to restore the pending backup due to a file system error, backup will not be removed.")
      }     
    
      if 'isCopied {
        set sc = $$$ADDSC(sc, $$$ERROR(5001, "Failed to restore the pending backup due to a file system error."))
      }
    }
  }
  quit sc
}

ClassMethod ImportFromExternalSource(itemName As %String, origin As %String, fileType As %String, destination As %String = "") As %Status [ Final, Internal, Private ]
{
  set sc = $$$OK 
  
  if (fileType = "CLS") {      
    $$$QuitOnError(##class(%Compiler.UDL.TextServices).SetTextFromFile($namespace, itemName, origin))
  } elseif ##class(Port.Project.Helper).IsRoutine(itemName) {
    set routine = ""
    set fs = ##class(%FileCharacterStream).%New()
    set fs.Filename = origin
    
    if ##class(%RoutineMgr).Exists(itemName) {      
      set routine = ##class(%RoutineMgr).%OpenId(itemName)           
    } else {
      set routine = ##class(%RoutineMgr).%New(itemName)
    }
        
    set code = routine.Code
    do code.Clear()
    
    $$$QuitOnError(code.CopyFrom(fs))
    set sc = code.Save()
  } else {
    set destinationPath = ##class(%File).GetDirectory(destination)
    $$$QuitOnError(##class(Port.Project.Helper).ImplyDirectoryCreation(destinationPath))    
    set isCopied = ##class(%File).CopyFile(origin, destination, 1)
    if isCopied = 0 {
      set sc = $$$ERROR($$$GeneralError, "Unable to copy "_origin_" to destination.")
    }
  }
  quit sc
}

Method GetFileExtension(path As %String, isWebPath As %Boolean) As %String [ Internal, Private ]
{
  if $piece(path, ..Slash, *)?1"."3A quit ""
  if isWebPath || (..GetSourceExtension() = "") {
    set sliceSize = 0
  } else {
    set sliceSize = 1
  }
  // -1 to ignore last piece (.txt) when not inside web path or when source extension is not provided.
  quit "."_$zconvert($piece(path, ".", *-sliceSize), "U")
}

Method SynchronizeProject(Output addedCount As %String = 0, Output removedCount As %String = 0) As %Status
{
  set (sc, scc) = $$$OK
  set itemName = ""
    
  #dim item As %Studio.Project
  
  // We must check and remove all invalid items if the user desires to import everything
  // from the repository.
  if ..IsBatch $$$QuitOnError(..Project.Check())
  
  // Now that the project is clear, we add the new items.
  for {
    set itemName = $order(i%ItemsList(itemName), 1, type)    
    quit:itemName=""    
    
    set sc = $$$ADDSC(sc, ..Project.AddItem(itemName))    
  }
  set ssc = ..Project.%Save()
  set scc = $$$EMBEDSC(scc, sc)
  quit scc
}

Method ResetLists()
{
  
  kill i%ImportList, i%ItemsList
  set (i%ImportList, i%ItemsList) = 0
}

Method AssertValidExtension(origin As %String) As %Status [ Final, Internal, Private ]
{
  set sourceFileExtension = "."_$$$ucase($piece(origin, ".", *))
  
  if $listfind($$$RoutineExtensions, sourceFileExtension) || (sourceFileExtension = ".CLS") {
    set sourceFileExtension = ""
  }  
  
  if (sourceFileExtension '= $$$ucase(..GetSourceExtension())) {
    write !, sourceFileExtension, " - ", $$$ucase(..GetSourceExtension())
    set fileName = ##class(%File).GetFilename(origin)
    set expectedSourceExtension = $select(..SourceExtension = "" : "keep the Cach� format", 1: "terminate with "_..SourceExtension)
    quit $$$ERROR($$$GeneralError, "Unable to describe the file "_fileName_ " as it violates the current source extension. "_$c(10, 10)_"It must "_expectedSourceExtension_".")
  }
  quit $$$OK
}

}

