Class Port.UnitTest.Util [ Abstract ]
{

ClassMethod ResolveTestLocation(absoluteBasePath As %String, className As %String) As %Status [ Final, Internal ]
{
  quit $listbuild(className_".CLS", ##class(Port.Util).ClassToFile(absoluteBasePath, className, "xml"))
}

ClassMethod IsUnitTestClass(className As %String) As %Boolean
{
  
  set isUnitTest = 0
  set descriptor = ##class(%Dictionary.CompiledClass).%OpenId(className)
  if '$isobject(descriptor) || ($isobject(descriptor) && (descriptor.Super = "")) quit 0
  
  if descriptor.Super [ "Port.UnitTest.TestCase" quit 1  
  
  // If the target class have some super class defined, we must consider that it could be
  // extending from multiple super classes. So we need to check each of them.
  for i=1:1:$length(descriptor.Super, ",") {
    set extension = $piece(descriptor.Super, ",", i)
    if ..IsUnitTestClass(extension) {
      set isUnitTest = 1
      quit
    }   
  }
  quit isUnitTest
}

ClassMethod AssertTestableClass(className, Output testableClass As %String = "") As %Boolean
{
  if $piece(className, ".", *) = "CLS" set className = $piece(className, ".", 1, *-1)
  set prefix = ##class(Port.Configuration).GetTestClassPrefix()  
  set rootPackage = $piece(className, ".")  
  
  if rootPackage = prefix {
    if '..IsUnitTestClass(className) quit 0
    set testableClass = className
  } elseif ##class(%Dictionary.ClassDefinition).%ExistsId(prefix_"."_className) {
    set maybeTestableClass = prefix_"."_className
    if ..IsUnitTestClass(maybeTestableClass) {
      set testableClass = prefix_"."_className 
    }
  }
  quit (testableClass '= "")
}

ClassMethod GetTestPathForClass(testableClass As %String, baseTestPath As %String = {##class(Port.Configuration).GetTestPath()})
{
  if $extract(baseTestPath, *) = "/" set baseTestPath = $extract(baseTestPath, 1, *-1)
  quit baseTestPath_"/"_$piece($replace(testableClass, ".", "/"), "/", 1, *-1)_":"_testableClass
}

}

