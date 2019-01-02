# -------------------------------------------------------------------------
# Package
#    ECDefectTracking::Bugzilla::Driver
#
# Dependencies
#    ECDefectTracking
#
# Purpose
#    Use Bugzilla tool features on Electric Commander
#
# Template Version
#    1.0.4
#
# Date
#    04/26/2011
#
# Engineer
#    Andres Arias S.
#
# Copyright (c) 2011 Electric Cloud, Inc.
# All rights reserved
# -------------------------------------------------------------------------
package ECDefectTracking::Bugzilla::Driver;
@ISA = (ECDefectTracking::Base::Driver);

# -------------------------------------------------------------------------
# Includes
# -------------------------------------------------------------------------
use ElectricCommander;
use Time::Local;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use File::stat;
use File::Temp;
use FindBin;
use Sys::Hostname;
use lib $ENV {'DEFECT_TRACKING_PERL_LIB'};
use BZ::Client;
use BZ::Client::Bug;

if ( !defined ECDefectTracking::Base::Driver )
{
    require ECDefectTracking::Base::Driver;
}
if ( !defined ECDefectTracking::Bugzilla::Cfg )
{
    require ECDefectTracking::Bugzilla::Cfg;
}
$| = 1;

# -------------------------------------------------------------------------
# Main functions
# -------------------------------------------------------------------------
####################################################################
# new: Object constructor for ECDefectTracking::Bugzilla::Driver
#
# Side Effects:
#
# Arguments:
#   cmdr -            previously initialized ElectricCommander handle
#   name -            name of this configuration
#
####################################################################
sub new
{
    my $this  = shift;
    my $class = ref($this) || $this;
    my $cmdr  = shift;
    my $name  = shift;
    my $cfg   = new ECDefectTracking::Bugzilla::Cfg( $cmdr, "$name" );
    if ( "$name" ne '' )
    {
        my $sys = $cfg->getDefectTrackingPluginName();
        if ( "$sys" ne 'EC-DefectTracking-Bugzilla' )
        {
            die "DefectTracking config $name is not type ECDefectTracking-Bugzilla";
        }
    }
    my ($self) = new ECDefectTracking::Base::Driver( $cmdr, $cfg );
    bless( $self, $class );
    return $self;
}
####################################################################
# isImplemented
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   method -            method name
#
####################################################################
sub isImplemented
{
    my ( $self, $method ) = @_;
    if (    $method eq 'linkDefects'
         || $method eq 'updateDefects'
         || $method eq 'fileDefect'
         || $method eq 'createDefects' )
    {
        return 1;
    } else
    {
        return 0;
    }
}
####################################################################
# linkDefects
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub linkDefects
{
    my ( $self, $opts ) = @_;
    my $defectIDs_ref =
      $self->extractDefectIDsFromProperty( $opts->{propertyToParse}, 'Bug' );
    if ( !keys %{$defectIDs_ref} )
    {
        print "No defect IDs found, returning\n";
        return;
    }
    $self->populatePropertySheetWithDefectIDs($defectIDs_ref);
    my $defectLinks_ref  = {};
    my $bugzillaInstance = $self->getBugzillaInstance();
    if ( !$bugzillaInstance )
    {
        exit 1;
    }
    eval {
        $bugzillaInstance->login();
        my $bugs;
        my $numb;
        @$numb = keys %$defectIDs_ref;
        s/Bug// foreach @$numb;
        foreach my $id (@$numb)
        {
            eval { $bugs = BZ::Client::Bug->get( $bugzillaInstance, $id ); };
            if ($@)
            {
                my $errorm = $@->{message};
                $message = "Error: failed trying to get Bugzilla issue=Bug$id, with error: $errorm\n";
                my $actualErrorMsg = $@->{message};
                print "$message";
                $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                        'setProperty', "outcome", "error" );
            } else
            {
                my $bug     = @$bugs[0];
                my $status  = $bug->status();
                my $summary = $bug->summary();
                my $name = 'Bug ' . $bug->id() . ": $summary, STATUS=$status";
                my $url =
                    $self->getCfg()->get('url')
                  . '/show_bug.cgi?id='
                  . $bug->id();
                  
                print "Name: $name\n";
                if ( $name && $name ne '' && $url && $url ne '' )
                {
                    $defectLinks_ref->{$name} = $url;
                }
            }
        }
    };
    if ($@)
    {
        my $errorm = $@->{message};
        $message = "Error: failed trying to connect with server: $errorm\n";
        my $actualErrorMsg = $@->{message};
        print "$message";
        $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                'setProperty', "outcome", "error" );
    }
    if ( keys %{$defectLinks_ref} )
    {
        $self->populatePropertySheetWithDefectLinks($defectLinks_ref);
        $self->createLinkToDefectReport('Bugzilla Report');
    }
}
####################################################################
# updateDefects
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub updateDefects
{
    my ( $self, $opts ) = @_;
    my $property = $opts->{property};
    if ( !$property || $property eq '' )
    {
        print "Error: Property does not exist or is empty\n";
        exit 1;
    }
    my ( $success, $xpath, $msg ) =
      $self->InvokeCommander( { SupressLog => 1, IgnoreError => 1 },
                              'getProperty', "$property" );
    if ($success)
    {
        my $value = $xpath->findvalue('//value')->string_value;
        $property = $value;
    } else
    {
        print "Error querying for $property as a property\n";
        exit 1;
    }
    print "Property : $property\n";
    my @pairs = split( ',', $property );
    my $errors;
    my $updateddefectLinks_ref = {};
    my $bugzillaInstance       = $self->getBugzillaInstance();
    if ( !$bugzillaInstance )
    {
        exit 1;
    }
    foreach my $val (@pairs)
    {
        print "Current Pair: $val\n";
        my @iDAndValue  = split( '=', $val );
        my $idDefect    = $iDAndValue[0];
        my $valueDefect = $iDAndValue[1];
        s/Bug// for $idDefect;
        print "Current idDefect: Bug$idDefect\n";
        print "Current valueDefect: $valueDefect\n";
        if (   !$idDefect
             || $idDefect eq ''
             || !$valueDefect
             || $valueDefect eq '' )
        {
            print "Error: Property format error\n";
        } else
        {
            my $message           = '';
            my $resolutionMessage = '.';
            $valueDefect =~ m/(RESOLVED|CLOSED|VERIFIED)\s*([\w]*)\s*([\d]*)/;
            eval {
                my $ids    = [$idDefect];
                my $params = {};
                if ( $1 eq 'RESOLVED' || $1 eq 'CLOSED' || $1 eq 'VERIFIED' )
                {
                    if ( $2 eq 'DUPLICATE' )
                    {
                        $params = {
                                    'ids'        => $ids,
                                    'status'     => $1,
                                    'resolution' => $2,
                                    'dupe_of'    => $3
                        };
                    } elsif ( $2 eq '' )
                    {
                        $params = {
                                    'ids'        => $ids,
                                    'status'     => $1,
                                    'resolution' => 'FIXED'
                        };
                    } else
                    {
                        $params =
                          { 'ids' => $ids, 'status' => $1, 'resolution' => $2 };
                    }
                } else
                {
                    $params = { 'ids' => $ids, 'status' => $valueDefect };
                }
                BZ::Client::Bug->update( $bugzillaInstance, $params );
                my ( $success, $xpath, $msg ) =
                  $self->InvokeCommander( { SupressLog => 1, IgnoreError => 1 },
                                          'getProperty', '/myJob/jobId' );
                if ($success)
                {
                    my $id = $xpath->findvalue('//value')->string_value;
                    $params = {
                                'id'      => $idDefect,
                                'comment' => "ElectricCommander Job ID: $id"
                    };
                    BZ::Client::Bug->add_comment( $bugzillaInstance, $params );
                }
                $message = "Bug$idDefect was successfully updated to $valueDefect status.\n";
                print "$message";
            };
            if ($@)
            {
                my $errorm = $@->{message};
                $message = "Error: failed trying to udpate Bug$idDefect to $valueDefect status, with error: $errorm\n";
                $errors = 1;
                print "$message";
                $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                        'setProperty', "outcome", "error" );
            } else
            {
                my $bugs;
                eval {
                    $bugs =
                      BZ::Client::Bug->get( $bugzillaInstance, $idDefect );
                };
                if ($@)
                {
                    my $errorm = $@->{message};
                    print "Error trying to get Bugzilla issue=Bug$idDefect, with error: $errorm\n";
                    $self->InvokeCommander(
                        { SuppressLog => 1, IgnoreError => 1 },
                        'setProperty', "outcome", "error" );
                } else
                {
                    my $bug        = @$bugs[0];
                    my $status     = $bug->status();
                    my $resolution = $bug->resolution();
                    my $summary    = $bug->summary();
                    my $name       = 'Bug '
                      . $bug->id()
                      . ": $summary, STATUS=$status $resolution, RESULT=$message";
                    my $url =
                        $self->getCfg()->get('url')
                      . '/show_bug.cgi?id='
                      . $bug->id();
                    if ( $name && $name ne '' && $url && $url ne '' )
                    {
                        $updateddefectLinks_ref->{$name} = $url;
                    }
                }
            }
        }
    }
    if ( keys %{$updateddefectLinks_ref} )
    {
        $propertyName_ref = 'updatedDefectLinks';
        $self->populatePropertySheetWithDefectLinks( $updateddefectLinks_ref,
                                                     $propertyName_ref );
        $self->createLinkToDefectReport('Bugzilla Report');
    }
    if ( $errors && $errors ne '' )
    {
        print "Defects update completed with some Errors\n";
    }
}
####################################################################
# createDefects
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub createDefects
{
    my ( $self, $opts ) = @_;
    my $projectName = $opts->{bugzillaProjectName};
    if ( !$projectName || $projectName eq '' )
    {
        print "Error: bugzillaProjectName does not exist or is empty\n";
        exit 1;
    }
    my ( $success, $xpath, $msg ) =
      $self->InvokeCommander(
                              { SuppressLog => 1, IgnoreError => 1 },
                              'setProperty',
                              '/myJob/bugzillaProjectName',
                              "$projectName"
      );
    my ( $success, $xpath, $msg ) =
      $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                              'setProperty', '/myJob/config',
                              "$opts->{config}" );
    my $mode = $opts->{mode};
    if ( !$mode || $mode eq '' )
    {
        print "Error: mode does not exist or is empty\n";
        exit 1;
    }
    ( $success, $xpath, $msg ) =
      $self->InvokeCommander(
                              { SupressLog => 1, IgnoreError => 1 },
                              'getProperties',
                              {
                                 recurse => '0',
                                 path    => '/myJob/ecTestFailures'
                              }
      );
    if ( !$success )
    {
        print "No Errors, so no Defects to create\n";
        return 0;
    }
    my $results = $xpath->find('//property');
    if ( !$results->isa('XML::XPath::NodeSet') )
    {
        print "Didn't get a NodeSet when querying for property: ecTestFailures \n";
        return 0;
    }
    my $bugzillaInstance = $self->getBugzillaInstance();
    if ( !$bugzillaInstance )
    {
        exit 1;
    }
    my @propsNames = ();
    foreach my $context ( $results->get_nodelist )
    {
        my $propertyName = $xpath->find( './propertyName', $context );
        push( @propsNames, $propertyName );
    }
    my $createdDefectLinks_ref = {};
    my $errors;
    my $severity = $self->getCfg()->get('severity');
    my $priority = $self->getCfg()->get('priority');
    my $pversion = $self->getCfg()->get('version');
    if ( !$severity || $severity eq '' )
    {
        $severity = 'normal';
    }
    if ( !$priority || $priority eq '' )
    {
        $priority = 'P4';
    }
    if ( !$pversion || $pversion eq '' )
    {
        $pversion = 'unspecified';
    }
    foreach my $prop (@propsNames)
    {
        print "Trying to get Property /myJob/ecTestFailures/$prop \n";
        my ( $jSuccess, $jXpath, $jMsg ) =
          $self->InvokeCommander(
                                  { SupressLog => 1, IgnoreError => 1 },
                                  'getProperties',
                                  {
                                     recurse => '0',
                                     path    => "/myJob/ecTestFailures/$prop"
                                  }
          );
        my %testFailureProps = {};
        my $stepID           = 'N/A';
        my $testSuiteName    = 'N/A';
        my $testCaseResult   = 'N/A';
        my $testCaseName     = 'N/A';
        my $logs             = 'N/A';
        my $stepName         = 'N/A';
        my $jResults         = $jXpath->find('//property');

        foreach my $jContext ( $jResults->get_nodelist )
        {
            my $subPropertyName =
              $jXpath->find( './propertyName', $jContext )->string_value;
            my $value = $jXpath->find( './value', $jContext )->string_value;
            if ( $subPropertyName eq 'stepId' ) { $stepID = $value; }
            if ( $subPropertyName eq 'testSuiteName' )
            {
                $testSuiteName = $value;
            }
            if ( $subPropertyName eq 'testCaseResult' )
            {
                $testCaseResult = $value;
            }
            if ( $subPropertyName eq 'testCaseName' )
            {
                $testCaseName = $value;
            }
            if ( $subPropertyName eq 'logs' )     { $logs     = $value; }
            if ( $subPropertyName eq 'stepName' ) { $stepName = $value; }
        }
        my $message = '';
        my $comment =
            "Step ID: $stepID "
          . "Step Name: $stepName "
          . "Test Case Name: $testCaseName ";
        if ( $mode eq 'automatic' )
        {
            eval {
                my $params = {
                               product     => $self->getCfg()->get('product'),
                               component   => $self->getCfg()->get('component'),
                               summary     => "Bug: $prop",
                               version     => $pversion,
                               description => $comment,
                               op_sys      => 'All',
                               platform    => 'All',
                               priority    => $priority,
                               severity    => $severity
                };
                my $newissue =
                  BZ::Client::Bug->create( $bugzillaInstance, $params );
                $message = "Issue Created with ID: $newissue\n";
                print "$message";
                my $defectUrl =
                  $self->getCfg()->get('url') . "/show_bug.cgi?id=$newissue";
                $createdDefectLinks_ref->{"$comment"} =
                  "$message?url=$defectUrl";
            };
            if ($@)
            {
                my $errorm = $@->{message};
                $message = "Error: failed trying to create issue, with error: $errorm \n";
                print "$message";
                $errors = 1;
                $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                        'setProperty', "outcome", "error" );
                $createdDefectLinks_ref->{"$comment"} = "$message?prop=$prop";
            }
        } else
        {
            $createdDefectLinks_ref->{"$comment"} = "Needs to File Defect?prop=$prop";
        }
    }
    if ( keys %{$createdDefectLinks_ref} )
    {
        $propertyName_ref = 'createdDefectLinks';
        $self->populatePropertySheetWithDefectLinks( $createdDefectLinks_ref,
                                                     $propertyName_ref );
        $self->createLinkToDefectReport('Bugzilla Report');
    }
    if ( $errors && $errors ne '' )
    {
        print "Created Defects completed with some Errors\n";
    }
}
####################################################################
# fileDefect
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   Nothing
#
####################################################################
sub fileDefect
{
    my ( $self, $opts ) = @_;
    my $prop = $opts->{prop};
    if ( !$prop || $prop eq '' )
    {
        print "Error: prop does not exist or is empty\n";
        exit 1;
    }
    my $jobIdParam = $opts->{jobIdParam};
    if ( !$jobIdParam || $jobIdParam eq '' )
    {
        print "Error: jobIdParam does not exist or is empty\n";
        exit 1;
    }
    my $projectNameParam;
    my ( $success, $xpath, $msg ) =
      $self->InvokeCommander(
                              { SupressLog => 1, IgnoreError => 1 },
                              'getProperty',
                              'bugzillaProjectName',
                              { jobId => "$jobIdParam" }
      );
    if ($success)
    {
        $projectNameParam = $xpath->findvalue('//value')->string_value;
    } else
    {
        print "Error: projectNameParam does not exist or is empty\n";
        exit 1;
    }
    my $bugzillaInstance = $self->getBugzillaInstance();
    if ( !$bugzillaInstance )
    {
        exit 1;
    }
    my $severity = $self->getCfg()->get('severity');
    my $priority = $self->getCfg()->get('priority');
    my $pversion = $self->getCfg()->get('version');
    if ( !$severity || $severity eq '' )
    {
        $severity = 'normal';
    }
    if ( !$priority || $priority eq '' )
    {
        $priority = 'P4';
    }
    if ( !$pversion || $pversion eq '' )
    {
        $pversion = 'unspecified';
    }
    print "Trying to get Property /$jobIdParam/ecTestFailures/$prop \n";
    my ( $jSuccess, $jXpath, $jMsg ) =
      $self->InvokeCommander(
                              { SupressLog => 1, IgnoreError => 1 },
                              'getProperties',
                              {
                                 recurse => '0',
                                 jobId   => "$jobIdParam",
                                 path    => "/myJob/ecTestFailures/$prop"
                              }
      );
    my $stepID         = 'N/A';
    my $testSuiteName  = 'N/A';
    my $testCaseResult = 'N/A';
    my $testCaseName   = 'N/A';
    my $logs           = 'N/A';
    my $stepName       = 'N/A';
    my $jResults       = $jXpath->find('//property');

    foreach my $jContext ( $jResults->get_nodelist )
    {
        my $subPropertyName =
          $jXpath->find( './propertyName', $jContext )->string_value;
        my $value = $jXpath->find( './value', $jContext )->string_value;
        if ( $subPropertyName eq 'stepId' )        { $stepID        = $value; }
        if ( $subPropertyName eq 'testSuiteName' ) { $testSuiteName = $value; }
        if ( $subPropertyName eq 'testCaseResult' )
        {
            $testCaseResult = $value;
        }
        if ( $subPropertyName eq 'testCaseName' ) { $testCaseName = $value; }
        if ( $subPropertyName eq 'logs' )         { $logs         = $value; }
        if ( $subPropertyName eq 'stepName' )     { $stepName     = $value; }
    }
    my $message = '';
    my $comment =
        "Step ID: $stepID "
      . "Step Name: $stepName "
      . "Test Case Name: $testCaseName ";
    eval {
        my $params = {
                       product     => $self->getCfg()->get('product'),
                       component   => $self->getCfg()->get('component'),
                       summary     => "Bug: $prop",
                       version     => $pversion,
                       description => $comment,
                       op_sys      => 'All',
                       platform    => 'All',
                       priority    => $priority,
                       severity    => $severity
        };
        my $newissue = BZ::Client::Bug->create( $bugzillaInstance, $params );
        $message = "Issue Created with ID: $newissue\n";
        print "$message";
        my ( $success, $xpath, $msg ) =
          $self->InvokeCommander(
                                  { SuppressLog => 1, IgnoreError => 1 },
                                  'setProperty',
                                  "/myJob/ecTestFailures/$prop/defectId",
                                  "$message?url=$newissue",
                                  { jobId => "$jobIdParam" }
          );
        my $defectUrl =
          $self->getCfg()->get('url') . "/show_bug.cgi?id=$newissue";
        my ( $success, $xpath, $msg ) =
          $self->InvokeCommander(
                                  { SuppressLog => 1, IgnoreError => 1 },
                                  'setProperty',
                                  "/myJob/createdDefectLinks/$comment",
                                  "$message?url=$defectUrl",
                                  { jobId => "$jobIdParam" }
          );
    };
    if ($@)
    {
        print "Project Name: $projectNameParam\n";
        my $errorm = $@->{message};
        $message = "Error: failed trying to create issue, with error: $errorm \n";
        print "$message \n";
        $self->InvokeCommander( { SuppressLog => 1, IgnoreError => 1 },
                                'setProperty', "outcome", "error" );
        print "setProperty name: /$jobIdParam/createdDefectLinks/$comment value:$message?prop=$prop \n";
        my ( $success, $xpath, $msg ) =
          $self->InvokeCommander(
                                  { SuppressLog => 1, IgnoreError => 1 },
                                  'setProperty',
                                  "/myJob/createdDefectLinks/$comment",
                                  "$message?prop=$prop",
                                  { jobId => "$jobIdParam" }
          );
    }
}
####################################################################
# getBugzillaInstance
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#
# Returns:
#   A Bugzilla instance used to do operations on a Bugzilla server.
####################################################################
sub getBugzillaInstance
{
    my ($self)         = @_;
    my $cfg            = $self->getCfg();
    my $url            = $cfg->get('url');
    my $credentialName = $cfg->getCredential();
    my $credentialLocation =
      q{/projects/$[/plugins/EC-DefectTracking/project]/credentials/}
      . $credentialName;
    my ( $success, $xPath, $msg ) =
      $self->InvokeCommander( { SupressLog => 1, IgnoreError => 1 },
                              'getFullCredential', $credentialLocation );
    if ( !$success )
    {
        print "\nError getting credential\n";
        return;
    }
    my $bugzillauser = $xPath->findvalue('//userName')->value();
    my $passwd       = $xPath->findvalue('//password')->value();
    if ( !$bugzillauser || !$passwd )
    {
        print "User name and or password in credential $credentialLocation is not set\n";
        return;
    }
    my $instance;
    eval {
        $instance = BZ::Client->new(
                                     'url'      => $url,
                                     'user'     => $bugzillauser,
                                     'password' => $passwd
        );
    };
    if ($@)
    {
        my $actualErrorMsg = $@->{message};
        my $msg =
          getReadableErrorMsg( $actualErrorMsg, $url, $bugzillauser, '' );
        print "Error trying to get Bugzilla connection for url=$url, user=$bugzillauser: ";
        if ( $msg ne '' )
        {
            print "$msg\n";
        } else
        {
            print "$actualErrorMsg\n";
        }
        return;
    }
    return $instance;
}
####################################################################
# translateFieldIdsToNames
#
# Side Effects:
#
# Arguments:
#   id -           The id for which we need a name
#   fields -       An array or hash that map ids to names.
#
# Returns:
#   The field name.
####################################################################
sub translateFieldIdsToNames($$)
{
    my ( $id, $fields ) = @_;
    if ( ref($fields) eq 'HASH' )
    {
        foreach my $outerhashkey ( keys %$fields )
        {
            my $inner_hash_ref = $fields->{$outerhashkey};
            if ( $id eq $inner_hash_ref->{'id'} )
            {
                return $inner_hash_ref->{'name'};
            }
        }
    } elsif ( ref($fields) eq 'ARRAY' )
    {
        foreach my $a (@$fields)
        {
            if ( $id eq $a->{'id'} )
            {
                return $a->{'name'};
            }
        }
    }
    return $id;
}
####################################################################
# validateConfig
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#   userName -          the userName to validate
#   password -          the password to validate
#
# Returns:
#   On error, returns the error message.  Otherwise returns ''.
####################################################################
sub validateConfig
{
    my ( $self, $opts, $userName, $password ) = @_;
    my $url = $opts->{'url'};
    if ( $url !~ m/^http/ )
    {
        return 'Please specify a valid url, starting with http:// or https://';
    }
    my $instance;
    eval { $instance = BZ::Client->new( $url, $userName, $password ); };
    if ($@)
    {
        my $actualErrorMsg = $@->{message};
        my $moreDetailedErrorMsg = "Error validating Bugzilla configuration for url=$url, user=$userName: $actualErrorMsg";
        my $msg = getReadableErrorMsg( $actualErrorMsg, $url, $userName, '' );
        print "$moreDetailedErrorMsg\n";
        if ( $msg eq '' )
        {
            return $moreDetailedErrorMsg;
        } else
        {
            return $msg;
        }
    }
    return '';
}
####################################################################
# getReadableErrorMsg
#
# Side Effects:
#
# Arguments:
#   actualErrorStr -
#   url -
#   userName -
#   issue -
#
# Returns:
#   If the error matches one we know about, return a more readable
#   error messsage.  Otherwise return ''.
####################################################################
sub getReadableErrorMsg
{
    my ( $actualErrorStr, $url, $username, $issue ) = @_;
    if ( $actualErrorStr =~ m/(500 read failed|500 Can't connect)/ )
    {
        return "Unable to connect to $url.  Please make sure both the hostname and port are valid.";
    }
    if ( $actualErrorStr =~ m/com.atlassian.bugzilla.rpc.exception.RemoteAuthenticationException/ )
    {
        return "Invalid user name or password.";
    }
    if ( $actualErrorStr =~ m/com.atlassian.bugzilla.rpc.exception.RemotePermissionException/ )
    {
        return "Issue $issue does not exist or you do not have permission to view it.";
    }

    # this is something else
    return '';
}
####################################################################
# addConfigItems
#
# Side Effects:
#
# Arguments:
#   self -              the object reference
#   opts -              hash of options
#
# Returns:
#   nothing
####################################################################
sub addConfigItems
{
    my ( $self, $opts ) = @_;
    $opts->{'linkDefects_label'} = 'Bugzilla Report';
    $opts->{'linkDefects_description'} = 'Generates a report of Bugzilla IDs found in the build.';
}
1;
