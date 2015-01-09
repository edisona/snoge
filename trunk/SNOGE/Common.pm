package SNOGE::Common;


#########################################################################################
# Copyright (C) 2012 Leon Ward 
# SNOGE::Common
#
# Contact: leon@rm-rf.co.uk
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#########################################################################################

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Exporter;

@EXPORT = qw(wlog);
@EXPORT_OK = qw(ALL);
$VERSION = '0.5';


sub dumpstyle{
    my $KML_FILE=shift; #open filehandle
    my $config=shift;    # Either ios|mac
    
    die ("Bad Style $config->{'style'}. Must be mac or ios") unless ($config->{'style'} eq "mac" || "ios");
    
    print "VERBOSE - Dumping Style is $config->{'style'} to $config->{'kmlfile'}\n" if ($config->{'verbose'});
    
    print $KML_FILE "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <kml xmlns=\"http://www.opengis.net/kml/2.2\"> 
    <Document>
        <Style id=\"snort\">
                <IconStyle>
                        <Icon>
                                <href>$config->{'imageurl'}/$config->{'sensoricon'}</href>
                        </Icon>
                </IconStyle>
        </Style>
        <Style id=\"3D\">
                <IconStyle>
                        <scale>2</scale>
                        <Icon>
                                <href>$config->{'imageurl'}/3DSensor_logo.png</href>
                        </Icon>
                </IconStyle>
        </Style>
        <Style id=\"warning\">
                <IconStyle>
                        <scale>0.2</scale>
                        <Icon>
                                <href>$config->{'imageurl'}/warning.png</href>
                        </Icon>
                </IconStyle>
        </Style>

        <Style id=\"Last\">
                <IconStyle>
                        <Icon>
                                <href>$config->{'imageurl'}/$config->{'eventicon'}</href>
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
                                <href>$config->{'imageurl'}//$config->{'eventicon'}</href>
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
                                <href>$config->{'imageurl'}//red.gif</href>
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
                                <href>$config->{'imageurl'}//orange.gif</href>
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
                                <href>$config->{'imageurl'}//yellow.gif</href>
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
                                <href>$config->{'imageurl'}//blue.gif</href>
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
                                <href>$config->{'imageurl'}//grey.gif</href>
                        </Icon>
                </IconStyle>
                <LineStyle>
                        <color>ff0000cc</color>
                        <width>0.5</width>
                </LineStyle>
        </Style>
";

    if ($config->{'style'} eq "mac") {
        
        print $KML_FILE "
        <Style id=\"onebar\">
                <LineStyle>
                        <color>7f00ff00</color>
                        <width>1.0</width>
                </LineStyle>
                <PolyStyle>
                        <!-- <color>66009900</color> This is a little light-->
                        <color>7f00ff00</color>
                </PolyStyle>
        </Style>

	<Style id=\"twobar\">
                <LineStyle>
                        <color>7fff0000</color>
                        <width>1.0</width>
                </LineStyle>
                <PolyStyle>
                        <color>7fff0000</color>
                </PolyStyle>
        </Style>


        <Style id=\"threebar\">
                <LineStyle>
                        <color>7f0000ff</color>
                        <width>1.0</width>
                </LineStyle>
                <PolyStyle>
                        <color>7f0000ff</color>
                </PolyStyle>
        </Style>

        <Style id=\"citylabel\">
                <IconStyle>
                <scale>0.1</scale>
                </IconStyle>
        </Style>\n ";
    } elsif ($config->{'style'} eq "ios") {
        
        # IOS STYLES
        
        print $KML_FILE "
          <Style id=\"onebar\">
                <LineStyle>
                        <color>7f0000ff</color>
                        <width>1.0</width>
                </LineStyle>
                <PolyStyle>
                        <!-- <color>66009900</color> This is a little light-->
                        <color>7f0000ff</color>
                </PolyStyle>
        </Style>

	<Style id=\"twobar\">
                <LineStyle>
                        <color>7fffffff</color>
                        <width>1.0</width>
                </LineStyle>
                <PolyStyle>
                        <color>7fffffff</color>
                </PolyStyle>
        </Style>


        <Style id=\"threebar\">
                <LineStyle>
                        <color>7f0000ff</color>
                        <width>1.0</width>
                </LineStyle>
                <PolyStyle>
                        <color>7f0000ff</color>
                </PolyStyle>
        </Style>

        <Style id=\"citylabel\">
                <IconStyle>
                <scale>0.1</scale>
                </IconStyle>
        </Style>\n ";
    } else {
        die "Unknwn style $config->{'style'}";
    }
}


sub parentKML{
    my $parent=shift;
    my $config=shift;
    
	print "Creating a parent KML to serve event updates 
	- Filename: $parent
	- Update interval: $config->{'refreshsecs'}
	- UpdateURLs: $config->{'updateurls'}
	- ImageURL: $config->{'imageurl'}
	- Banner: $config->{'banner'} \n";
	
	my @netlinks = split(/,/, $config->{'updateurls'});
	
	open SERVERKML, ">", "$parent" or die "Unable to open $parent for writing";
	print SERVERKML "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<kml xmlns=\"http://earth.google.com/kml/2.0\">
	<Folder>
        	<open>1</open>
        	<name>$config->{'foldername'}</name>
        	<ScreenOverlay>
                	<name>Banner</name>
                	<Icon>
                        	<href>$config->{'imageurl'}/$config->{'banner'}</href>
                	</Icon>";
                        
                        if ($config->{'style'} eq "ios") {
                            print SERVERKML "
                            <overlayXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>
                            <screenXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>
                            <rotationXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>
                            <size x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/> ";
                        } else {
                            print SERVERKML "
                            <overlayXY x=\"0\" y=\"1\" xunits=\"fraction\" yunits=\"fraction\"/>
                            <screenXY x=\"0\" y=\"1\" xunits=\"fraction\" yunits=\"fraction\"/>
                            <rotationXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>
                            <size x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>
                            ";
                        }

                print SERVERKML "
        	</ScreenOverlay>" . "\n";
                
		foreach (@netlinks) {
			print "        - Adding network link $_\n";
			print SERVERKML "		
			<NetworkLink>
				 <name>Data</name>
				<visibility>1</visibility>
				<!--<flyToView>1</flyToView>-->
				<Url>
					<href>$_</href>
				";
				if ($config->{'refreshsecs'}) {
					print SERVERKML " <refreshMode>onInterval</refreshMode>
					  <refreshInterval>$config->{'refreshsecs'}</refreshInterval> \n"
				}
				print SERVERKML "
				</Url>
				<refreshVisibility>1</refreshVisibility>
			</NetworkLink>\n";
		}
		
		print SERVERKML "
		</Folder>
	</kml>
	";
        close SERVERKML;
}


1;