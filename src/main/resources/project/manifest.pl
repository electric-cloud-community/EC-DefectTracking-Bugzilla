@files = (
    ['//property[propertyName="ECDefectTracking::Bugzilla::Cfg"]/value', 'BugzillaCfg.pm'],
    ['//property[propertyName="ECDefectTracking::Bugzilla::Driver"]/value', 'BugzillaDriver.pm'],
    ['//property[propertyName="createConfig"]/value', 'bugzillaCreateConfigForm.xml'],
    ['//property[propertyName="editConfig"]/value', 'bugzillaEditConfigForm.xml'],
    ['//property[propertyName="ec_setup"]/value', 'ec_setup.pl'],
	['//procedure[procedureName="LinkDefects"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'ec_parameterForm-LinkDefects.xml'],	
	['//procedure[procedureName="UpdateDefects"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'ec_parameterForm-UpdateDefects.xml'],	
	['//procedure[procedureName="CreateDefects"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'ec_parameterForm-CreateDefects.xml'],	
);
