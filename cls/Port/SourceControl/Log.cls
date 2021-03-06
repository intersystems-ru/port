Include portutils

Class Port.SourceControl.Log [ Abstract ]
{

ClassMethod LogChange(projectName = {^||%Studio.Project}, itemName As %String = "") As %Status
{
  do ..ExtractItemDescription(itemName, .name, .type)
  set ^Port.SourceControl.Projects(projectName, type, name) = $zdatetime($horolog, 3,,,,,,,,,0) 
  quit $$$OK
}

ClassMethod ExtractItemDescription(itemName, Output name = "", Output type = "") As %String [ Private ]
{
  
  set type = $$$ucase($piece(itemName, ".", *))
  set name = $piece(itemName, ".", 1, *-1)
  if '$listfind($$$ImportTypes, type) && (type '= "PRJ") {
    set name = itemName
    set type = "CSP"
  }
}

ClassMethod GetLastChange(projectName As %String, itemName As %String) As %String
{
  do ..ExtractItemDescription(itemName, .name, .type)
  quit $get(^Port.SourceControl.Projects(projectName, type, name), 0)
}

ClassMethod Synchronize() As %Status
{
  #define ProjectExists(%id) ##class(%Studio.Project).%ExistsId(%id)
  #define ItemExists(%id) ##class(%Studio.ProjectItem).%ExistsId(%id)
  
  set sc = $$$OK
  if '$data(^Port.SourceControl.Projects) quit sc
  
  set global = "^Port.SourceControl.Projects"
  set q = $query(@global@(""))
  for {
    quit:q=""
    
    set projectName = $qsubscript(q, 1)
    set type = $qsubscript(q, 2)
    set itemName = $qsubscript(q, 3)
    
    if type '= "CLS" && (type '= "PRJ") set itemName = itemName_"."_type
    if type = "CSP" set itemName = $extract(itemName, 2, $length(itemName))
    set itemId = projectName_"||"_itemName_"||"_type
    if '$$$ProjectExists(projectName) || '$$$ItemExists(itemId) {
      kill @q
    }
    set q = $query(@q, 1)
  }
  quit $$$OK
}

}

