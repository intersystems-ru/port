Class Port.UnitTest.TestCase Extends %UnitTest.TestCase
{

Method GetTestDirectory(filePath As %String = "") As %String
{
  
  set testPath = ##class(Port.SourceControl.Config).GetTestPath()
  quit ##class(%File).NormalizeFilename(..Manager.Root()_"/"_testPath_"/"_filePath)
}

}

