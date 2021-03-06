Class Port.Project.Helper [ Abstract ]
{

ClassMethod ImplyDirectoryCreation(path As %String) As %Status
{
  set isCreated = 1
  if '##class(%File).DirectoryExists(path)  {
    set isCreated = ##class(%File).CreateDirectoryChain(path)
    if isCreated = 0 {      
      quit $$$ERROR(5001, "Unable to create path: "_##class(%File).NormalizeFilename(path))
    }
  }
  quit $$$OK
}

ClassMethod IsRoutine(itemName As %String, onlyCompilables As %Boolean = 0) As %Boolean
{
  set extension = ..GetItemExtension(itemName)
  
  if extension = "MAC"  || (extension = "INT") ||
    (extension = "MVB") || (extension = "MVI") || 
    (extension = "BAS") || (extension = "INC") ||
    (extension = "DFI") {
    quit 1
  }  
  quit 0
}

ClassMethod GetItemExtension(itemName As %String) As %String
{
  set ext = $piece(itemName, ".", *)
  quit $$$ucase(ext)
}

ClassMethod CSPLogicalToPhysicalPath(cspItem As %String, Output absolutePath As %String = "", namespace As %String = {$namespace}) As %Status
{
  set installDirectory = $System.Util.InstallDirectory()
  set cspAppDirectory = $System.CSP.GetDefaultApp(namespace)
  if cspAppDirectory = "" quit $$$ERROR($$$GeneralError, "Unable to retrieve the physical path for the namespace '"_$namespace_"': web application or namespace doesn't exists.")
  set cspAppDirectory = $extract(cspAppDirectory, 2, *)
  set absolutePath = ##class(%File).NormalizeFilename($replace(cspItem, cspAppDirectory, installDirectory_"csp/"_$$$lcase($namespace)))
  quit $$$OK
}

ClassMethod FileToClass(path As %String, extension As %String = {##class(Port.SourceControl.Config).GetSourceExtension()}) As %String
{
  set slash = $select($$$isWINDOWS : "\", 1: "/")
  set normalizedPath = ##class(%File).NormalizeFilename(path)
  set fileName = ##class(%File).GetFilename(normalizedPath)
  set extSize = $length($select(extension = "" : $piece(fileName, ".", *), 1: ".cls"_extension)) 
  set contextPath = $extract(normalizedPath, $find(normalizedPath, slash_"cls") + 1, ($length(normalizedPath) - 1) - extSize)  
  quit $replace(contextPath, slash, ".")
}

ClassMethod ClassToFile(basePath As %String, className As %String, extension As %String = {##class(Port.SourceControl.Config).GetSourceExtension()})
{
 
  set divider = $select($$$isWINDOWS : "\", 1: "/")
  if extension '= "" set extension = "."_extension
  quit ##class(%File).NormalizeFilename(basePath_"/"_$replace(className, ".", divider)_".cls"_extension)
}

ClassMethod Describe(name As %String, Output extension As %String, Output itemType As %String, Output itemName As %String)
{
   
  set nameOnly = $piece(name, ".", 1, *-1)  
  set routines = $listbuild("MAC", "INT", "INC", "MVB", "MVI", "BAS", "DFI")
  set extension = ..GetItemExtension(name)

  if ..IsRoutine(name) {
    set itemType = extension
    if extension = "INC" || 
      (extension = "BAS") || 
      (extension = "MVI") || 
      (extension = "INT") {
      set itemType = "MAC"
    }
    set itemName = nameOnly_"."_extension  
  } elseif extension = "CLS" {
    set itemName = nameOnly  
    set itemType = extension
  } else {
    set itemName = name
    set itemType = "CSP"
  }
}

ClassMethod CSPPhysicalToLogicalPath(physicalPath As %String, Output logicalPath As %String, namespace As %String = {$namespace}) As %Status
{
  set slash = $select($$$isWINDOWS : "\", 1: "/")  
  set installDir = $System.Util.InstallDirectory()
  set webFilePath = $extract(physicalPath, $find(physicalPath, slash_"web"_slash), *)
  if '$find(##class(%File).NormalizeFilename(physicalPath), slash_"web"_slash) {
    quit $$$ERROR($$$GeneralError, "Invalid physical path: parameter doesn't correspond to the /web/ path.")
  }
  set cspAppPath = $System.CSP.GetDefaultApp(namespace)  
  if cspAppPath = "" quit $$$ERROR($$$GeneralError, "Unable to retrieve to logical path for the namespace '"_$namespace_"': web application or namespace doesn't exists.")
  if $extract(cspAppPath, *) '[ "/" set cspAppPath = cspAppPath_"/"
  set logicalPath = $extract(cspAppPath, 2, *)_$replace(webFilePath, "\", "/")
  quit $$$OK
}

}

