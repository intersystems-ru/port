Class UnitTest.Port.Project.Synchronizer Extends (Port.UnitTest.TestCase, UnitTest.Port.Helper)
{

Property Exporter As Port.Project.Exporter;

Method OnBeforeOneTest() As %Status
{
  
  $$$QuitOnError(..CreateDummyProjectFromFixture(..GetTestDirectory("../fixtures"), "dummy-project"))
  set ..Exporter = ##class(Port.Project.Exporter).%New(..GetTestDirectory("../fixtures/_/dummy-project"), 1)
  set ..Exporter.Logger.Silent = 1
  
  // This is a hack to force the workspace to be resetted back to where it started.
  // We have to do that because simply by opening a %Studio.Project instance already changes it's value.  
  
  return $$$OK
}

Method OnAfterOneTest() As %Status
{
  return ..DeleteDummyProject(..GetTestDirectory("../fixtures"), "dummy-project")
}

Method TestPurge() As %Status
{
  
  set synchronizer = ##class(Port.Project.Synchronizer).%New(..Exporter)    
  
  do synchronizer.AddToWhitelist("Dummy.Package.Class.CLS")
  do synchronizer.AddToWhitelist("dummy.MAC")
  do synchronizer.AddToWhitelist("dummy.INC")
  do synchronizer.AddToWhitelist("dummy.MVB")
  do synchronizer.AddToWhitelist($System.CSP.GetDefaultApp($namespace)_"/index.html")
  do synchronizer.AddToWhitelist("MVB.4.MVI")
  do synchronizer.AddToWhitelist("dummy.DFI")
  
  set sc = synchronizer.Purge()
  
  set items = ..GetDummyProjectSourceLocation("dummy-project", ..GetTestDirectory("../fixtures/_/dummy-project"))
  set itemName = ""
  set templateAssertion = "%1 -> %2"
  for i=1:1:items.Count() {
    set itemName = items.Next(itemName)
    set itemLocation = items.GetAt(itemName)
    set flag = $lf($lb("dummy.MAC", "dummy.INC", "dummy.MVB", "dummy.DFI", $e($System.CSP.GetDefaultApp($namespace)_"/index.html", 2, *), "MVB.4.MVI", "Dummy.Package.Class.CLS"), itemName) > 0
    set assertion = $$$FormatText(templateAssertion, itemLocation, $case(flag, 1: "KEPT", : "PURGED"))
    do $$$AssertEquals(##class(%File).Exists(itemLocation), flag, assertion)
  }
}

}
