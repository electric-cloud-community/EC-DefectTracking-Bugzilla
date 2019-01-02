#
# Makefile responsible for building the EC-DefectTracking-Bugzilla plugin
#
# Copyright (c) 2005-2012 Electric Cloud, Inc.
# All rights reserved

SRCTOP=..
include $(SRCTOP)/build/vars.mak

STAGINGLIB = $(OUTDIR)/staging/lib
STAGINGBugzilla = $(STAGINGLIB)/BZ
STAGINGClient = $(STAGINGBugzilla)/Client
STAGINGXMLRPC = $(STAGINGClient)/XMLRPC
STAGINGXML = $(STAGINGLIB)/XML


build: copyAgentFiles buildJavaPlugin

copyAgentFiles: $(STAGINGBugzilla) $(STAGINGBugzilla)/Client.pm
copyAgentFiles: $(STAGINGClient) $(STAGINGClient)/API.pm
copyAgentFiles: $(STAGINGClient) $(STAGINGClient)/Bug.pm
copyAgentFiles: $(STAGINGClient) $(STAGINGClient)/Bugzilla.pm
copyAgentFiles: $(STAGINGClient) $(STAGINGClient)/Exception.pm
copyAgentFiles: $(STAGINGClient) $(STAGINGClient)/Product.pm
copyAgentFiles: $(STAGINGClient) $(STAGINGClient)/Test.pm
copyAgentFiles: $(STAGINGClient) $(STAGINGClient)/XMLRPC.pm
copyAgentFiles: $(STAGINGXMLRPC) $(STAGINGXMLRPC)/Array.pm
copyAgentFiles: $(STAGINGXMLRPC) $(STAGINGXMLRPC)/Handler.pm
copyAgentFiles: $(STAGINGXMLRPC) $(STAGINGXMLRPC)/Parser.pm
copyAgentFiles: $(STAGINGXMLRPC) $(STAGINGXMLRPC)/Response.pm
copyAgentFiles: $(STAGINGXMLRPC) $(STAGINGXMLRPC)/Struct.pm
copyAgentFiles: $(STAGINGXMLRPC) $(STAGINGXMLRPC)/Value.pm
copyAgentFiles: $(STAGINGXML) $(STAGINGXML)/Writer.pm

$(STAGINGBugzilla)/Client.pm: lib/BZ/Client.pm
	cp '$<' '$@'
$(STAGINGClient)/API.pm: lib/BZ/Client/API.pm
	cp '$<' '$@'
$(STAGINGClient)/Bug.pm: lib/BZ/Client/Bug.pm
	cp '$<' '$@'
$(STAGINGClient)/Bugzilla.pm: lib/BZ/Client/Bugzilla.pm
	cp '$<' '$@'
$(STAGINGClient)/Exception.pm: lib/BZ/Client/Exception.pm
	cp '$<' '$@'
$(STAGINGClient)/Product.pm: lib/BZ/Client/Product.pm
	cp '$<' '$@'
$(STAGINGClient)/Test.pm: lib/BZ/Client/Test.pm
	cp '$<' '$@'
$(STAGINGClient)/XMLRPC.pm: lib/BZ/Client/XMLRPC.pm
	cp '$<' '$@'
$(STAGINGXMLRPC)/Array.pm: lib/BZ/Client/XMLRPC/Array.pm
	cp '$<' '$@'
$(STAGINGXMLRPC)/Handler.pm: lib/BZ/Client/XMLRPC/Handler.pm
	cp '$<' '$@'
$(STAGINGXMLRPC)/Parser.pm: lib/BZ/Client/XMLRPC/Parser.pm
	cp '$<' '$@'
$(STAGINGXMLRPC)/Response.pm: lib/BZ/Client/XMLRPC/Response.pm
	cp '$<' '$@'
$(STAGINGXMLRPC)/Struct.pm: lib/BZ/Client/XMLRPC/Struct.pm
	cp '$<' '$@'
$(STAGINGXMLRPC)/Value.pm: lib/BZ/Client/XMLRPC/Value.pm
	cp '$<' '$@'
$(STAGINGXML)/Writer.pm: lib/BZ/Client/XML/Writer.pm
	cp '$<' '$@'
$(STAGINGBugzilla):
	mkdir -p '$@'
$(STAGINGClient):
	mkdir -p '$@'
$(STAGINGXMLRPC):
	mkdir -p '$@'
$(STAGINGXML):
	mkdir -p '$@'

unittest:

systemtest: start-selenium test-setup test-run stop-selenium

NTESTFILES  ?= systemtest/ec_setup.ntest

test-setup:
	$(INSTALL_PLUGINS) EC-DefectTracking EC-DefectTracking-Bugzilla

test-run: systemtest-run


include $(SRCTOP)/build/rules.mak

test: build install promote

install:
	ectool installPlugin ../../../out/common/nimbus/EC-DefectTracking-Bugzilla/EC-DefectTracking-Bugzilla.jar
 
promote:
	ectool promotePlugin EC-DefectTracking-Bugzilla
