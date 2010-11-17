#!/usr/bin/perl -I ..


# TODO 
# Skipunknown looks strange in results - check it works as expected.


#########################################################################################
# Copyright (C) 2009 Leon Ward
# Snoge
#
# Contact: leon.ward@sourcefire.com
#
# Some of the unified handling code in here came from Jason Brvenik's samples.
# Thanks also goes to him for creating the SnortUnified perl module.
#
# Configuration sits in a config file you specify with a -c command line arg.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#########################################################################################

use strict;
use warnings;
use Sys::Hostname;
use Data::Dumper;
use Socket;
use Geo::IP::PurePerl;
use Module::Load;
use Getopt::Long;
	
#my $configFile=0;
my $UF_Data = {};
my $record = {};

# ---------- Config file Defaults ----------
my $snogeversion=1.8.1;
my $endtime=1586439068; 	# Looks like SnoGE will break in April 2020 :-P . This is a dirty hack, but works for the time being.
my $starttime=0;
no warnings 'once';	

my (%config,$defaultlongitude,$defaultlatitude,$outputFile,$classfile,$verbose,$oneFile,$refresh,$pause,$dcurl,$skipunknown,$parent,$configFile,$lastwindow,$debug);
my $lastupdatetime=0;

GetOptions (    'c|config=s' => \$configFile,
                'o|onefile=s' => \$oneFile,
                'p|parent=s' => \$parent, 
                's|skipunknown=s' => \$skipunknown,
                'w|write=s' => \$outputFile,
                'z|pause' => \$pause,
		'v|verbose' => \$verbose,
		'd|debug' => \$debug,
		'l|last=s'	=> \$lastwindow,
		'j|starttime=s' => \$starttime,
		'k|endtime=s'  => \$endtime,
                );



unless ($configFile) {
	print "ERROR: I need a config file. Take a look at usage\n";
	&usage();
	exit 1;
}

if ($debug) {
	# If debug is on, lets add verbose o/p
	$verbose=1;
}

# Default values for configuration. These are all set in the config file. Don't change them here.

$config{'sid-msg'}="sid-msg.map";
$config{'mode'}="csv";
$config{'gen-msg'}="./gen-msg.map";
$config{'basefilename'}="./unified1.alert";
$config{'ignoresource'}=0;
$config{'ignoredestination'}=0;
$config{'dc'}="192.168.222.20";
$config{'port'}="8302";
$config{'certfile'}="./certfile.txt";
$config{'ignoresids'}=0;
$config{'eventupdateinterval'}="0";
$config{'timeupdateinterval'}="0";
$config{'maxplacemarks'}="100";
$config{'maxstats'}="200";
$config{'defaultlocation'}="80.68.89.43"; 	# Set to rm-rf.co.uk
$config{'kmlfile'}="./output.kml";
$config{'refreshsecs'}="30";
$config{'waldo'}="/dev/null";
$config{'eventicon'}="warning.png";
$config{'sensoricon'}="snorty.gif";
$config{'banner'}="snort-ge-banner.png";
$config{'updateurl'}="http://localhost/snoge/snoge.kml";
$config{'sensors'}="rm-rf.co.uk sourcefire.com";
$config{'classification'}="./clasification.config";

open my $config, '<', $configFile or die "Unable to open config file $configFile $!";
    while(<$config>) {
        chomp; 

	# Quick hack to remove confusion regarding " chars in old config files
	$_ =~ s/"//g;

	if ( $_ =~ m/^[a-zA-Z]/) {
       		(my $key, my @value) = split /=/, $_;
       		$config{$key} = join '=', @value;
	}
    }
close $config;
#print Dumper %config;

if ($debug) { 
	print "CONFIG: Input mode is        : $config{'mode'}\n";
	print "CONFIG: sid-msg file is      : $config{'sid-msg'}\n";
	print "CONFIG: gen-msg file is      : $config{'gen-msg'}\n";
	print "CONFIG: Base filename is     : $config{'basefilename'}\n";
	print "CONFIG: Ignoring Source      : $config{'ignoresource'}\n";
	print "CONFIG: Ignoring Destination : $config{'ignoredestination'}\n";
	print "CONFIG: Ignoring SIDs        : $config{'ignoresids'}\n";
	print "CONFIG: Event updateinterval : $config{'eventupdateinterval'} events \n";
	print "CONFIG: Time updateinterval  : $config{'timeupdateinterval'} seconds \n";
	print "CONFIG: Maxplacemarks        : $config{'maxplacemarks'} \n";
	print "CONFIG: Maximum Statistics   : $config{'maxstats'} \n";
	print "CONFIG: Default location     : $config{'defaultlocation'} \n";
	print "CONFIG: KMLOutputfile        : $config{'kmlfile'} \n";
	print "CONFIG: Server Refresh       : $config{'refreshsecs'} \n";
	print "CONFIG: waldo                : $config{'waldo'} \n";
	print "CONFIG: Event Icon           : $config{'eventicon'} \n";
	print "CONFIG: Sensor Icon          : $config{'sensoricon'} \n";
	print "CONFIG: Banner               : $config{'banner'} \n";
	print "CONFIG: UpdateURL            : $config{'updateurl'} \n";
	print "CONFIG: Defense Center       : $config{'dc'} \n";
	print "CONFIG: Estreamer Port       : $config{'port'}\n";
	print "CONFIG: Certfile             : $config{'certfile'}\n";
	print "CONFIG: Sensors              : $config{'sensors'}\n";
	print "CONFIG: Image URL            : $config{'imageurl'}\n";
	print "CONFIG: classification file  : $config{'classification'}\n";

}

lookupDefaults("$config{'defaultlocation'}");
unless ($outputFile) {
	$outputFile=$config{'kmlfile'};	
}
my @sensors=split(/ /, $config{'sensors'});
my @ignoresids=split(/ /, $config{'ignoresids'});
my @ignoresource=split(/ /, $config{'ignoresource'});

# ------ These variables are not for human consumption ------
my $startup=localtime();
my $stop=0;
my $sids = 0;
my $class = 0;
my $uf_file = undef;
my $old_uf_file = undef;
my @fields;
my $currentfile=0;
my $lastrec=0;
my @sensorPlacemarks=();
my @placemarks=();
my %cities = ();
my %cityLongitude = ();
my %cityLatitude = ();
my @citiestracked =();
my $recnum=0;
my $updatecount=0;
my $numOfUpdates=0;
my %rule_map=();
my $socket=0;

# To make this easier to install, we only inlude the required PMs for the input mode.
# NOTE TO SELF:
# use is evaluated at compile time, so we cant "use" it in this context.
# require foo; foo->import(qw(:Stuff);
# should work for us instead

if ("$config{'mode'}" eq "unified" ) {
	print "- Unified mode * Importing functions:\n";
	require SnortUnified ; 
	SnortUnified->import(qw(:ALL));
	require SnortUnified::MetaData;
	SnortUnified::MetaData->import(qw(:ALL));
	require SnortUnified::TextOutput;
	SnortUnified::TextOutput->import(qw(:ALL));

	unless ( -f $config{'sid-msg'} ) {
		die ( "Unable to open $config{'sid-msg'} for sid-msg map" ); 
	}

	unless ( -f $config{'gen-msg'} ) {
		die ( "Unable to open $config{'gen-msg'} for generator map" ); 
	}

	unless ( -f $config{'classification'} ) {
		die ( "Unable to open $config{'classification'} for a classification map" ); 
	}

	$sids = get_snort_sids("$config{'sid-msg'}","$config{'gen-msg'}");
	$class = get_snort_classifications("$config{'classification'}");
} elsif ("$config{'mode'}" eq "estreamer") {
	print "Estreamer Mode - Importing functions\n";
	require IO::Socket::SSL; IO::Socket::SSL->import();
	require SFStreamer ; 
	SFStreamer->import(qw(:DEFAULT));
	require SFStreamer ; SFStreamer->import(qw(:DEFAULT));
	require SFSGlobals ; SFSGlobals->import(qw(:DEFAULT)); 
	print "Connecting to DC $config{'dc'}\n";
	#print $FLAG_METADATA::SFStreamer;
	unless (-f $config{'certfile'}) {
		die "Unable to find SSL cert $config{'certfile'}";
	}
	if ( $socket= new IO::Socket::SSL(PeerAddr => "$config{'dc'}",
                                PeerPort => "$config{'port'}",
                                Proto => 'tcp', 
                                SSL_use_cert => 1,
                                SSL_cert_file => "$config{'certfile'}",
                                SSL_key_file => "$config{'certfile'}") ) {
		print "Connected to DC $config{'dc'} on $config{'port'}\n"
	} else {
		die("Unable to connect to $config{'dc'} on $config{'port'}");
	}

} elsif ( $config{'mode'} eq "csv") {
	unless ($oneFile) {
		die "CSV mode requires a filename, use --onefile to set filename";
	}
	print "CSV File mode (processing $oneFile)\n";
	open (CSVFILE,"$oneFile") or die "Unable to open CSV file $oneFile";
} else {
	die "Unknown mode.";
}


# ------------- Functions ----------------

sub usage()
{
	print "
************************************************************** 
Security Events -> KML $snogeversion - leon.ward\@sourcefire.com

No warranties are provided or are inferred to the accuracy or reliability of this code.  Use at your own risk.

  -c or --config <filename>		Specify config file
  -v or --verbose			Enable verbose mode
  -d or --debug				Enable Verbose + debug output
  -p or --parent <filename>		Create a \"parent\" KML file for automated updates
  -o or --onefile <filename>		One time run with a single unified|csv file.
  -s or --skip-unknown			Skip events that we cant locate

--- Time Window Settings (optional)
  -l or --last				Show last X minutes of data
  -k or --start				Start timestamp (use with --end)
  -l or --end				End timestamp (use with --start)
  -z or --pause				Pause for keypress after each event (for debugging)

";
}

sub update_time_window() {

        my $now=time();
        $starttime=($now - $lastwindow);

        if ($debug){
                print "* Timewindow update - Size $lastwindow seconds \n - Start : " . localtime($starttime) ." \n - End   : " . localtime($now) . " \n";
        }
}

sub lookupSensors{
	my $sensor=shift;
        my $gi = Geo::IP::PurePerl->new("/usr/local/share/GeoIP/GeoLiteCity.dat",GEOIP_STANDARD);

        # Find Destination 
        if ((my $country_code,
                my $country_code3,
                my $country_name,
                my $region,
                my $city,
                my $postal_code,
                my $latitude,
                my $longitude,
                my $dma_code,
                my $area_code) = $gi->get_city_record($sensor)) {

                if ($debug) {
                        print "- Adding sensor $sensor in $city, $country_name \n";
                }

                push(@sensorPlacemarks, ["$latitude","$longitude","$sensor"]);

        } else {
                print "- Cant find location of $sensor!\n";
        }
}

sub lookupDefaults{
	my $defaultlocation=shift;
        my $gi = Geo::IP::PurePerl->new("/usr/local/share/GeoIP/GeoLiteCity.dat",GEOIP_STANDARD);

        # Find Destination 
        if ((my $country_code,
                my $country_code3,
                my $country_name,
                my $region,
                my $city,
                my $postal_code,
                $defaultlatitude,
                $defaultlongitude,
                my $dma_code,
                my $area_code) = $gi->get_city_record($defaultlocation)) {

                if ($verbose) {
                        print "- Default Latitude set to $defaultlatitude \n";
                        print "- Default Longitude set to $defaultlongitude \n";
			print "- Defailt City - > $city $country_name\n";
                }

        } else {
                print "- Cant find default location for $defaultlocation!\n";
        }
}


sub parentKML{
	print "Creating a parent KML to serve event updates 
	- Filename: $parent
	- Update interval: $config{'refreshsecs'}
	- UpdateURL: $config{'updateurl'}
	- ImageURL: $config{'imageurl'}
	- Banner: $config{'banner'} \n";
	
	open SERVERKML, ">", "$parent" or die "Unable to open $parent for writing";
	print SERVERKML "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<kml xmlns=\"http://earth.google.com/kml/2.0\">
	<Folder>
        	<open>1</open>
        	<name>Snort IPS Events</name>
        	<ScreenOverlay>
                	<name>Banner</name>
                	<Icon>
                        	<href>$config{'imageurl'}/$config{'banner'}</href>
                	</Icon>
                	<overlayXY x=\"0\" y=\"1\" xunits=\"fraction\" yunits=\"fraction\"/>
                	<screenXY x=\"0\" y=\"1\" xunits=\"fraction\" yunits=\"fraction\"/>
                	<rotationXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>
                	<size x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>
        	</ScreenOverlay>
        	<NetworkLink>
                	 <name>Snort Events</name>
                	<visibility>1</visibility>
                	<!--<flyToView>1</flyToView>-->
                	<Url>
                        	<href>$config{'updateurl'}</href>
			";
	if ($config{'refreshsecs'}) {
		print SERVERKML " <refreshMode>onInterval</refreshMode>
				  <refreshInterval>$config{'refreshsecs'}</refreshInterval> \n"
	}
	print SERVERKML "
                	</Url>
                	<refreshVisibility>1</refreshVisibility>
        	</NetworkLink>
		</Folder>
	</kml>
	"
}


sub updateDist{
        my $city=shift;
        my $longitude=shift;
        my $latitude=shift;

        if ($debug){
                print "- Updating Dist for $city\n";
        }

        if (exists $cities{$city}) {
                my $visits = $cities{$city};
                $visits++;
                $cities{$city} = $visits;
                if ($debug){
                        print "- $visits events are now in cache for $city\n";
                }
        } else {
                if ($debug) {
                        print " - First event from $city\n";
                }
                $cities{$city} = "1";
                $cityLongitude{$city} = $longitude;
                $cityLatitude{$city} = $latitude;
        }

        push(@citiestracked,$city);

        # Only keep track of the last maxstats events
        if ( @citiestracked >= $config{'maxstats'} ){
                my $rmcity=shift @citiestracked;
                if ($debug) {
                        print " * Hit max event count of $config{'maxstats'}\n";
                        print " - Oldest stat is from $rmcity - $cities{$rmcity} visits\n";
                        print " - rmcity is  $rmcity - $cities{$rmcity} visits\n";
                        print " - city is  $city - $cities{$city} visits\n";
                }
                my $visits=$cities{$rmcity};
                $visits--;
                $cities{$rmcity} = $visits;
                if ($debug) {
                        print "$rmcity, now has $cities{$rmcity} visits\n";
                }
        }

        # Prune cities with "0" visits
        foreach( keys %cities ){
                if ( "$cities{$_}" eq "0" ) {
                        delete $cities{$_};
                } else {
                        if ($verbose){
                        #       print " - Nope that's not 0. Keeping $_ at $cities{$_}\n";
                        }
                }
        }

}

sub dumpKML{
        my $numofpoints = @placemarks;
        my $eventcount=0;
	my %summary=();
	my $summaryText=0;

        if ($verbose) {
                print "- Creating a KML file : $outputFile\n";
        }

        # Dump the attack distribution data into a GE KML
        my $numberoflocations=keys( %cities );
        my $totalheight=100000*$numberoflocations;
        my %heightOfCity=();
        my %cityPct=();

        if ($debug) {
                print "- Calculating Ingress Bars \n";
        }

        for my $eventsfromlocation (keys %cities) {
                $eventcount = $eventcount+$cities{$eventsfromlocation};
        }

        if ($verbose) {
                print "- $eventcount events in collection\n";
                print "- $numberoflocations locations\n";
                print "- Total height is $totalheight\n";
                print "- Tracking : ";
                foreach(@citiestracked) {
                        print "$_ ";
                }
                print "\n";
        }

        for my $location ( keys %cities ){
                my $pct = $cities{$location} / $eventcount * 100;
                $cityPct{$location} = $pct;
                $heightOfCity{$location}=$totalheight/100*$pct;
                if ($verbose) {
                        print "- City: $location - $cityLongitude{$location} , $cityLatitude{$location}";
                        print " : " .  $cities{$location} . " Events ";
                        print " $cityPct{$location} percent ";
                        print " Height = " . $totalheight/100 * $pct ." \n"
                }
        }

        open( my $KML_FILE,">","$outputFile") or die "Unable to create output file $outputFile . This is configured in $configFile to be $outputFile";

        print $KML_FILE "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <kml xmlns=\"http://www.opengis.net/kml/2.2\"> 
        <Document>
        <Style id=\"snort\">
                <IconStyle>
                        <Icon>
                                <href>$config{'imageurl'}/$config{'sensoricon'}</href>
                        </Icon>
                </IconStyle>
        </Style>
        <Style id=\"3D\">
                <IconStyle>
                        <scale>2</scale>
                        <Icon>
                                <href>$config{'imageurl'}/3DSensor_logo.png</href>
                        </Icon>
                </IconStyle>
        </Style>
        <Style id=\"warning\">
                <IconStyle>
                        <scale>0.2</scale>
                        <Icon>
                                <href>$config{'imageurl'}/warning.png</href>
                        </Icon>
                </IconStyle>
        </Style>

        <Style id=\"Last\">
                <IconStyle>
                        <Icon>
                                <href>$config{'imageurl'}/$config{'eventicon'}</href>
                        </Icon>
                </IconStyle>
                <LineStyle>
                        <color>77ff0000</color>
                        <width>4</width>
                </LineStyle>
        </Style>
        
        <Style id=\"Attack\">
                <IconStyle>
                        <scale>0.5</scale>
                        <Icon>
                                <href>$config{'imageurl'}//$config{'eventicon'}</href>
                        </Icon>
                </IconStyle>
                <LineStyle>
                        <color>ff0000cc</color>
                        <width>0.5</width>
                </LineStyle>
        </Style>

        <Style id=\"Red\">
                <IconStyle>
                        <scale>0.5</scale>
                        <Icon>
                                <href>$config{'imageurl'}//red.gif</href>
                        </Icon>
                </IconStyle>
                <LineStyle>
                        <color>ff0000cc</color>
                        <width>0.5</width>
                </LineStyle>
        </Style>

        <Style id=\"Orange\">
                <IconStyle>
                        <scale>0.5</scale>
                        <Icon>
                                <href>$config{'imageurl'}//orange.gif</href>
                        </Icon>
                </IconStyle>
                <LineStyle>
                        <color>ff0000cc</color>
                        <width>0.5</width>
                </LineStyle>
        </Style>

        <Style id=\"Yellow\">
                <IconStyle>
                        <scale>0.5</scale>
                        <Icon>
                                <href>$config{'imageurl'}//yellow.gif</href>
                        </Icon>
                </IconStyle>
                <LineStyle>
                        <color>ff0000cc</color>
                        <width>0.5</width>
                </LineStyle>
        </Style>

        <Style id=\"Blue\">
                <IconStyle>
                        <scale>0.5</scale>
                        <Icon>
                                <href>$config{'imageurl'}//blue.gif</href>
                        </Icon>
                </IconStyle>
                <LineStyle>
                        <color>ff0000cc</color>
                        <width>0.5</width>
                </LineStyle>
        </Style>


        <Style id=\"Grey\">
                <IconStyle>
                        <scale>0.5</scale>
                        <Icon>
                                <href>$config{'imageurl'}//grey.gif</href>
                        </Icon>
                </IconStyle>
                <LineStyle>
                        <color>ff0000cc</color>
                        <width>0.5</width>
                </LineStyle>
        </Style>

        <Style id=\"transGreenPoly\">
                <LineStyle>
                        <color>88009900</color>
                        <width>1.0</width>
                </LineStyle>
                <PolyStyle>
                        <!-- <color>66009900</color> This is a little light-->
                        <color>88009900</color>
                </PolyStyle>
        </Style>

        <Style id=\"transBluePoly\">
                <LineStyle>
                        <color>77ff0000</color>
                        <width>1.0</width>
                </LineStyle>
                <PolyStyle>
                        <color>77ff0000</color>
                </PolyStyle>
        </Style>

        <Style id=\"citylabel\">
                <IconStyle>
                <scale>0.1</scale>
                </IconStyle>
        </Style>\n ";


        foreach ( keys %cities) {
                if ($debug) {
                        print "B - Plotting $_ with hight of $heightOfCity{$_} \n";
                }

                my $style="transBluePoly";

                if ( $_ =~ m/Unknown/ ) {
                        if ($debug) {
                                print "B - This is unknownVille - Using alt style\n";
                        }
                        $style="transGreenPoly";
                }

                my $heading=int( rand(300)) + 25;
                my $shortpct = sprintf("%.3s", "$cityPct{$_}");

                print $KML_FILE "
                <Placemark>
                        <name>$_</name>
                        <description>$shortpct% of current security events are inbound from $_</description>
                        <LookAt>
                                <longitude>$cityLongitude{$_}</longitude>
                                <latitude>$cityLatitude{$_}</latitude>
                                <altitude>20</altitude>
                                <tilt>40</tilt>
                                <range>2000000</range>
                                <heading>$heading</heading>
                        </LookAt>
                        <visibility>1</visibility>
                        <styleUrl>#$style</styleUrl>
                        <Polygon>
                                <extrude>1</extrude>
                                <tessellate>1</tessellate>
                                <altitudeMode>absolute</altitudeMode>
                                <outerBoundaryIs>
                                        <LinearRing>
                                        <coordinates>
                                                " . ($cityLongitude{$_}-0.25) . "," . ($cityLatitude{$_}+0.175) . "," . ($heightOfCity{$_}) .
 "
                                                " . ($cityLongitude{$_}+0.25) . "," . ($cityLatitude{$_}+0.175) . "," . ($heightOfCity{$_}) .
 "
                                                " . ($cityLongitude{$_}+0.25) . "," . ($cityLatitude{$_}-0.25) . "," . ($heightOfCity{$_}) .
"
                                                " . ($cityLongitude{$_}-0.25) . "," . ($cityLatitude{$_}-0.25) . "," . ($heightOfCity{$_}) .
"
                                                " . ($cityLongitude{$_}-0.25) . "," . ($cityLatitude{$_}+0.175) . "," . ($heightOfCity{$_}) .
 "
                                        </coordinates>
                                        </LinearRing>
                                </outerBoundaryIs>
                        </Polygon>
                </Placemark> \n";
                print $KML_FILE "
                <Placemark>
                        <styleUrl>#citylabel</styleUrl> 
                        <name>$_</name>
                        <visibility>1</visibility>
                        <Point>
                                <extrude>1</extrude>
                                <altitudeMode>clampToGround</altitudeMode>
                                <coordinates>$cityLongitude{$_},$cityLatitude{$_}</coordinates>
                        </Point>
                        <description>$cities{$_} security events have been detected from $_</description>
                </Placemark>\n";
        }

	if ($verbose) {
		print "- Total placemarks is $numofpoints \n";
	}
	my $plotnum=0;

        foreach(@placemarks){
		$plotnum++;
		my $last=0;
                my $srclongitude = $_->[0];
                my $srclatitude = $_->[1];
                my $name = $_->[2];
                my $description = $_->[3];
                my $style = $_->[4];
                my $dstlongitude = $_->[5];
                my $dstlatitude = $_->[6];
                my $url = $_->[8];
		my $msg = $_->[9];
		my $timestamp = $_->[10];

		# Generate summary data

		unless ( $summary{$msg} ) {
			$summary{$msg} = 1; 
		} else {
			$summary{$msg}++;
		}

		$summaryText="-------- Summary --------<br>";
		foreach (keys %summary) {
			$summaryText=$summaryText . "$_ = $summary{$_} <br>";
			#print "$_ = $summary{$_} \n";
		}
		
		if ($plotnum == $numofpoints) {
		
			if ($debug) {
				print "------Last Event----\n";
			}
			$last=1;
			$style="Last";
		}


                print $KML_FILE "
                <Placemark>
                        <name>$name</name>
                        <visibility>1</visibility>
                        <styleUrl>#$style</styleUrl>
                <LookAt>
                        <longitude>$srclongitude</longitude>
                        <latitude>$srclatitude</latitude>
                        <altitude>10000</altitude>
                        <tilt>30</tilt>
                </LookAt>

                        <Point>
                                <extrude>1</extrude>
                                <altitudeMode>clampToGround</altitudeMode>
                                <coordinates>$srclongitude,$srclatitude</coordinates>
                        </Point>
                        <description>
                        <![CDATA[ 
                        <table width=\"400\"/></table> 
                        $description</br>
                        <a href=\"$url\"> Click Here </a> for event details</p> 
                        ]]> 
                        </description>
                </Placemark>\n";

                print $KML_FILE "
                <Placemark>
                        <name>$name</name>
                         <visibility>1</visibility>
                        <styleUrl>#$style</styleUrl>
                        <Point>
                                <extrude>1</extrude>
                                <altitudeMode>clampToGround</altitudeMode>
                                <coordinates>$srclongitude,$srclatitude</coordinates>
                         </Point>
                         <!--<description>$description</description> -->
                        <LineString>
                                <tessellate>1</tessellate>
                                <coordinates> $srclongitude,$srclatitude $dstlongitude,$dstlatitude</coordinates>
                         </LineString>
                </Placemark>\n"
        }



        foreach(@sensorPlacemarks){

                my $sensorlongitude = $_->[0];
                my $sensorlatitude = $_->[1];
                my $name = $_->[2];

                if ($debug) {
                        print "- Plotting Snort Sensor in $name \n";
                }

                print $KML_FILE "
                <Placemark>
                        <name>Snort Instance $name</name>
                        <visibility>1</visibility>
                        <styleUrl>#snort</styleUrl>
                <!-- <LookAt>
                        <longitude>$sensorlongitude</longitude>
                        <latitude>$sensorlatitude</latitude>
                        <altitude>10000</altitude>
                        <tilt>30</tilt>
                </LookAt> -->

                        <Point>
                                <extrude>1</extrude>
                                <altitudeMode>clampToGround</altitudeMode>
                                <coordinates>$sensorlatitude,$sensorlongitude</coordinates>
                        </Point>
                        <description>
                        <![CDATA[ 
                        <table width=\"400\"/></table> 
                        Snort instance - $name</br>
			$summaryText<br>
                        ]]> 
                        </description>
                </Placemark>\n";
        }

        print $KML_FILE "</Document>\n";
        print $KML_FILE "</kml>\n";
        close($KML_FILE);
	$lastupdatetime=time();
}

sub get_latest_file($) {
  my $filemask = shift;
  my @ls = <$filemask*>;
  my $len = @ls;
  my $uf_file = "";

  if ($len) {
    # Get the most recent file
    my @tmparray = sort{$b cmp $a}(@ls);
    $uf_file = shift(@tmparray);
  } else {
    $uf_file = undef;
  }
  return $uf_file;
}

sub wlog(){
	# This is designed to be run as a daemon, so lets send any output somewhere
	my $logmsg=shift;
	if ($debug){
		print "Logging: $logmsg\n";
	}
	system("logger -t SnortGoogleEarth \"$logmsg\"");	
}

sub processevent {
	# Makes a placemark entry with the following properties
	# processevent ($src_addr, $dst_addr, $style, $snortmsg, $longmsg)
	$updatecount++;
	my $src_addr=shift;
	my $dst_addr=shift;
	my $style=shift;
	my $shortmsg=shift;
	my $longmsg=shift;
	my $timestamp=shift;
 	my $dstcountry_code3=0;
	my $dstcountry_name=0;
	my $dstlatitude=0;
	my $dstlongitude=0;
	my $dstcity=0;
       	my $srccountry_code3=0;
	my $srccountry_name=0;
	my $srclatitude=0;
	my $srclongitude=0;
	my $srccity=0;

	if ($lastwindow) {
		update_time_window;	# Update our "start time" for a sliding window on each event
	}
	
	if ($debug) {
		print "  ProcessEvent: 
		src_addr= $src_addr
		dst_addr= $dst_addr
		style= $style
		shortmsg= $shortmsg	
		longmsg= $longmsg
		timestamp=$timestamp \n";
	}
		#  Don't process older records than the "start time"
		if ( $timestamp lt $starttime ) {
			if ($verbose) {
				print "Skipping record - Timestamp $timestamp (" . localtime($timestamp) . ") is less than the start time of $starttime (" . localtime($starttime) . ")\n";
			}
			print "Processing Record [$recnum] S\r";
			return;
		}

		# and quit if we get an older record than "End time"
		if ( $timestamp ge $endtime ) {
			if ($debug) {
				print "\nEnd. Timestamp $timestamp " . localtime($timestamp) . " is ge than end time $endtime (" . localtime($endtime) . "). End \n";
			}
			die "End time hit";
		}		

	print "Processing Record [$recnum] P\r";
	# Find Destination 
	my $gi = Geo::IP::PurePerl->new("/usr/local/share/GeoIP/GeoLiteCity.dat",GEOIP_STANDARD);
        if ((my $country_code,
                $dstcountry_code3,
	        $dstcountry_name,
		my $region,
		$dstcity,
		my $postal_code,
		$dstlatitude,
		$dstlongitude,
		my $dma_code,
		my $area_code) = $gi->get_city_record($dst_addr)) {

		if ($debug) {
                	print "- DestIP $dst_addr location found in $dstcity, $dstcountry_name\n";
               	}
	} else {
        	if ($debug) {
			print "- DestIP $dst_addr location unknown. Defaulting to $defaultlongitude, $defaultlatitude\n";
                 }
                 $dstlongitude=$defaultlongitude;
                 $dstlatitude=$defaultlatitude;
		 $dstcity="UnknownCity";
		 $dstcountry_name="UnknownCountry";
	}

	# Find source
	if ((my $srccountry_code,
            	$srccountry_code3,
              	$srccountry_name,
              	my $srcregion,
               	$srccity,
               	my $srcpostal_code,
               	$srclatitude,
               	$srclongitude,
              	my $srcdma_code,
               	my $srcarea_code) = $gi->get_city_record($src_addr)) {

      		if ($debug) {
                      	print "- SrcIP $src_addr location found in $srccity, $srccountry_name\n";
               	}
       	} else {
               	if ($debug) {
                      	print "- SrcIP $src_addr location unknown, defaulting to  $defaultlongitude, $defaultlatitude\n";
              	}
               	$srclongitude=$defaultlongitude;
              	$srclatitude=$defaultlatitude;
		$srccity="UnknownCity";
		$srccountry_name="UnknownCountry";
        }

	if ($skipunknown) {
		if ($verbose) {
			print "- Skipping Event! -> Unknown location, no idea where to plot this RFC 1918?\n";
		}
		if (("$srccountry_name" eq "UnknownCountry") and ("$dstcountry_name" eq "UnknownCountry")) {
			return;
		}
	}

	# This is already handeled by design. I forgot that for a while :P
	#if (( "$srccountry_name" eq "UnknownCountry" ) and ( "$dstcountry_name" ne "UnknownCountry")) {
	#	print "Swapping direction for better plot of $shortmsg $srccountry_name -> $dstcountry_name\n";
	#}

       	push(@placemarks, ["$srclongitude",
                           "$srclatitude",
                           "$shortmsg - $srccity, $srccountry_name",
			   "$longmsg",
                           "$style",
                           "$dstlongitude",
                           "$dstlatitude",
                           "$srccity",
                           "url",
			   "$shortmsg",
			   "$timestamp"]);

	# Update event distribution for the city of $src_addr   
        if ($srccity) {
        	if ($debug){
			print "- Got city  \n";
                }
         } else {
                if ($debug){
			print "- Dont know city, so creating a generic entry\n";
		}
		$srccity="Unknown$srccountry_code3";
	}

	if ($debug) {
		print "- City is $srccity\n";
	}

	&updateDist("$srccity","$srclongitude","$srclatitude");

        # Limit the number of placemarks we display to a number
        my $numofpoints = @placemarks;
        if ($numofpoints >= $config{'maxplacemarks'}+1) {
                my $deleted = shift @placemarks;
		$numofpoints--;
                if ($verbose) {
                        print "- Max number of placemarks ($config{'maxplacemarks'}) hit. Removing oldest.\n";
                }
        }

	# Remove events from the array that have a timestamp older than the start of our "last window"
	#
	foreach (@placemarks) {
		my $placemarkTimestamp=$_->[10];
		if ( $placemarkTimestamp le $starttime ) {
			if ($verbose) {
				print "Removing a time-stale event with timestamp of " . localtime($placemarkTimestamp) . 
				" - Window starts at " . localtime($starttime) . "\n";
			}
			shift @placemarks;	
		}
	}

	my $now = time();
	if ( ($updatecount >= $config{'eventupdateinterval'}) and
	     ( ($now - $config{'timeupdateinterval'}) >= $lastupdatetime ) ) {	
		if ($verbose) {
			if ( ($now - $config{'timeupdateinterval'}) >= $lastupdatetime ) {
				print "* Hit update TIME -> Time is " . localtime($now) . 
					" Last update was " . localtime($lastupdatetime) . 
 					" Greater than timeupdateinterval of $config{'timeupdateinterval'} \n" ;
			}
			if ( $updatecount >= $config{'eventupdateinterval'} ) {
				print "* Hit update EVENT COUNT -> Count is $updatecount\n";
			}
		}
	       	&dumpKML;
		$numOfUpdates++;
		$updatecount=0;
	} else {
		if ($debug) {
			print "- Not updating KML: \n    " .
			"Event threshold :  Records = $updatecount / $config{'eventupdateinterval'}\n    " .
			"Time threshold $config{'timeupdateinterval'}: Lastupdate " . localtime($lastupdatetime) . " Current time is " . localtime($now) . " \n";
		
		}
	}
}


sub unified_read() {
  while ( $record = readSnortUnifiedRecord() ) {
    if (( $UF_Data->{'TYPE'} eq 'ALERT' ) || (( $UF_Data->{'TYPE'} eq 'UNIFIED2' ) && $record->{'TYPE'} eq 7 )) {
	$recnum++;

	if ($lastrec >= $recnum) {
		if ($verbose) {
			print "- Skipping record $recnum, it's less than the waldo value of $lastrec\n";
		}
	} else {
		if ($verbose){
			print "----------------------------------------------------\n";
			print "* Read File: $uf_file File Type: $UF_Data->{'TYPE'} Record Number: $recnum \n";
			if  ( $UF_Data->{'TYPE'} eq 'UNIFIED2' ) {
				print "* Unified2 record type $record->{'TYPE'} \n"; 
			}
		}

		#if  ( $UF_Data->{'TYPE'} eq 'UNIFIED2' ) {
		#	unless ( $record->{'TYPE'} eq 7 )  {
		#		return 1;
		#	}
		#}

		my $src_addr = inet_ntoa(pack('N', $record->{'sip'}));
		my $dst_addr = inet_ntoa(pack('N', $record->{'dip'}));
		my $src_port = $record->{'sp'};
		my $dst_port = $record->{'dp'};
		my $proto = $record->{'protocol'};
		my $sid = $record->{'sig_id'};
		my $msg = get_msg($sids,$record->{'sig_gen'},$record->{'sig_id'},$record->{'sig_rev'});
		my $shortmsg = sprintf("%.25s", $msg);
		my $classtype = get_class($class,$record->{'class'});
		my $gid = $record->{'sig_gen'};
		my $timestamp = $record->{'tv_sec'};
	

		#$timestamp = localtime("$timestamp");
		my $longmsg = localtime("$timestamp") . " <h3>SID: $sid </br> $msg </h3>$src_addr:$src_port $dst_addr:$dst_port";

		if ($stop) {
                	print "Stop by request. Process and get another?";
                        my $foo=<>;
                }

		unless ( (grep {$_ eq $src_addr} @ignoresource) or 
			 (grep {$_ eq $sid} @ignoresids)) {

			processevent("$src_addr", "$dst_addr", "Attack", "$shortmsg", "$longmsg","$timestamp");

		} else {
			if ($verbose) { 
				print "- Ignoring record sid $sid with source IP of $src_addr as requested in config\n"; 
			}
		}

		unless ($oneFile) {
			# No point creating a waldo for a single run through a file
			open WALDO, ">", "$config{'waldo'}" or die "Unable to open $config{'waldo'} waldo for writing";
			print WALDO "FILE=$uf_file\n";
			print WALDO "RECORD=$recnum\n";
			close(WALDO);
		}
	if ($pause) {
		print "Hit enter for next event\n";
		my $fubar=<STDIN>;
	}
	
	}
     } else {
	if ($debug) {
		print "Unsuported record type $UF_Data->{'TYPE'}\n";
	}
     }
  }
  return 0;
}

# ------------------- MAIN --------------------
if ($parent) {
	# parent is set, creating a parentKML file, and then quit
	parentKML;
	exit 0;
}
foreach(@sensors) {
	lookupSensors($_);	
}

# Calculate initial time offset if --last is used
if ($lastwindow) { 
	update_time_window;
}

if ("$config{'mode'}" eq "unified") {
	print "- Now processing unified file(s).....\n";
	unless ($oneFile) {
		$uf_file = &get_latest_file($config{'basefilename'}) || die "no files to get";
		die unless $UF_Data = openSnortUnified($uf_file);
	
		if ($verbose) {
			print "Working on unified file $uf_file\n";
		}
	
		if ( open WALDO, "$config{'waldo'}" )  {
			while (my $line = <WALDO>){
				if ( $line =~ m/(^FILE=)(.*)/ ) {
					$currentfile=$2;
					chomp $currentfile;
					if ($verbose) {
						print "Waldo file shows current file as $currentfile\n"
					}
				}
				if ( $line =~ m/(^RECORD=)(.*)/ ) {
					$lastrec=$2;
					chomp $lastrec;
					if ($verbose) {
						print "Waldo file shows last record as $lastrec\n"
					}
				}
			}
		} else {
 			$recnum=0;
		}
	
		if ("$currentfile" eq "$uf_file") {
			if ($verbose){
				print "Working on same file, skipping to $lastrec\n";
			}
		
		} else {
			if ($verbose){
				print "Working on new file, resetting last record to 0\n";
			}
			$lastrec=0;
		}

		while (1) {
		  $old_uf_file = $uf_file;
		  $uf_file = &get_latest_file($config{'basefilename'}) || die "no files to get";
 	 
		  if ( $old_uf_file ne $uf_file ) {
		    closeSnortUnified();
		    $UF_Data = openSnortUnified($uf_file) || die "cannot open $uf_file";
		    if ($verbose) {
			print "- New file, resetting record count \n";
		    }
		    $lastrec=0;
		  }
		  &unified_read();
		}
	} else {
		print "Working on single file $oneFile\n";
		$uf_file=$oneFile;
		unless ( -r $uf_file) {
			die("Access denied on $uf_file. Check file permissions");
		}
		$UF_Data = openSnortUnified($uf_file) || die "Unable to open $uf_file";
		unified_read();
	}

	closeSnortUnified();

	if ($oneFile) {
		if ($verbose) {
			print "- In total $numOfUpdates were make to the KML file\n";
		}
	}

} elsif ("$config{'mode'}" eq "estreamer") {
	print "Processing estreamer data from $starttime ( " . localtime($starttime) . " )...\n";
	req_data($socket, $starttime, $FLAG_METADATA::SFStreamer);  # Function defined in SFStreamer to request data
	while ($socket) {

	        my %event = get_feed($socket);
	        # eStreamer gives us multiple record types, dependinog on the record
	        # type, we want different info out of it
	        # So lets grab the key bits of data we want to have out of each estreamer record types

	        #print "Event type is " . $event{'rec_type'} . "\n";
	        if ($event{'rec_type'} == $SFStreamer::RECORD_EVENT) {
        	        my $priority = $event{'priority'};
                	my $impact = $event{'impact_flag'};
       	         	my $src_addr = $event{'src_addr'};
       		        my $dst_addr = $event{'dst_addr'};
                	my $gid = $event{'gen'};
                	my $sid = $event{'sid'};
                	my $src_port = $event{'src_port'};
                	my $dst_port = $event{'src_port'};
                	my $srccity=0;
                	my $dstcity=0;
                	my $srclongitude=0;
                	my $srclatitude=0;
                	my $dstlongitude=0;
                	my $dstlatitude=0;
                	my $srccountry_name=0;
                	my $dstcountry_name=0;
                	my $srccountry_code3=0;
                	my $dstcountry_code3=0;
                	my $msg=$rule_map{$event{'gen'}.":".$event{'sid'}};
			# It turns out that $event{'event_sec'} isn't in epoch as expected, and it lacks a TZ
				
			$event{'event_sec'} = `date -d \"$event{'event_sec'}\ UTC" +%s`;
			chomp $event{'event_sec'};
     		        my $timestamp = $event{'event_sec'};

			my $flag = "Unknown flag color";
        		my $blocked = "No";
			
			if ($pause) {
				print "Pause ....\n";
				my $foo=<STDIN>;
			}

        		if ( $event{'impact_flag'} == 0 ) { 
                		$flag = "Grey";
 		        } elsif (  $event{'impact_flag'} == 1 ){
                		$flag = "Blue" ;
		        } elsif (  $event{'impact_flag'} == 3 ){
                		$flag = "Yellow" ;
        		} elsif (  $event{'impact_flag'} == 7 ){
                		$flag = "Orange" ;
        		} elsif (  $event{'impact_flag'} == 11 ){
                		$flag = "Red" ;
        		} elsif (  $event{'impact_flag'} == 15 ){
                		$flag = "Red" ;
        		} elsif (  $event{'impact_flag'} == 19 ){
                		$flag = "Red" ;
        		} elsif (  $event{'impact_flag'} == 23 ){
                		$flag = "Red" ;
        		} elsif (  $event{'impact_flag'} == 27 ){
                		$flag = "Red" ;
        		} elsif (  $event{'impact_flag'} == 31 ){
                		$flag = "Red" ;
        		} elsif (  $event{'impact_flag'} == 32 ){
                		$flag = "Grey" ;
                		$blocked = "Yes";
        		} elsif (  $event{'impact_flag'} == 33 ){
                		$flag = "Blue" ;
                		$blocked = "Yes";
        		} elsif (  $event{'impact_flag'} == 35 ){
                		$flag = "Yellow" ;
                		$blocked = "Yes";
        		} elsif (  $event{'impact_flag'} == 39 ){
                		$flag = "Orange" ;
                		$blocked = "Yes";
        		} elsif (  $event{'impact_flag'} == 43 ){
                		$flag = "Red" ;
                		$blocked = "Yes";
        		} elsif (  $event{'impact_flag'} == 47 ){
                		$flag = "Red" ;
                		$blocked = "Yes";
        		} elsif (  $event{'impact_flag'} == 51 ){
                		$flag = "Red" ;
                		$blocked = "Yes";
        		} elsif (  $event{'impact_flag'} == 55 ){
                		$flag = "Red" ;
                		$blocked = "Yes";
        		} elsif (  $event{'impact_flag'} == 59 ){
                		$flag = "Red" ;
                		$blocked = "Yes";
        		} elsif (  $event{'impact_flag'} == 63 ){
                		$flag = "Red" ;
                		$blocked = "Yes";
        		}   

			if ($verbose) {
                        	print "********* New Event *********\n";
                        	print "* Got event " . localtime($timestamp) . " $gid:$sid - $msg $src_addr -> $dst_addr : Pri $priority : Impact $impact : Flag $flag\n";
                	}

			my $shortmsg="$msg";
			my $longmsg="$timestamp $gid:$sid - $msg $src_addr -> $dst_addr : Priority $priority : Impact $flag\n";
			$recnum++;	
			unless ( (grep {$_ eq $src_addr} @ignoresource) or (grep {$_ eq $sid} @ignoresids)) {
				processevent("$src_addr","$dst_addr","$flag","$shortmsg","$longmsg","$timestamp");
                	} else {
				print "Processing Record [$recnum] S\r";
                        	if ($verbose) { 
                                	print "- Ignoring record sid $sid with source IP of $src_addr as requested in config\n"; 
                        	}
                	}

        	} elsif ( $event{'rec_type'} == $SFStreamer::RECORD_RULE ) {
                	$rule_map{$event{'generator_id'}.":".$event{'rule_id'}} = $event{'msg'};
        	}
	ack_data($socket);
	}

	close($socket);

} elsif ("$config{'mode'}" eq "csv") {
	print "Processing CSV file $oneFile...\n";

	while (my $line=<CSVFILE>) {
		unless ($line =~ m/^[#\s]/) { # Skip comments 
			if ($debug) {
				print "Log line is : $line\n";
			}
			(my $src_addr, my $dst_addr,  my $short_msg, my $long_msg) = split(/,/, $line);
			if ($debug) {
				print "Entry Details :\n\t\tsrc_addr = $src_addr \n\t\tdst_addr = $dst_addr \n\t\tshort = $short_msg \n\t\tlong = $long_msg\n";
			}
			processevent("$src_addr", "$dst_addr", "Attack", "$short_msg", "$long_msg","0");
		}
	}
	print "KML file $outputFile created.\n";
}
