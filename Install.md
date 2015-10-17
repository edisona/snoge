# SnoGE from scratch #
_Leon Ward - leon@rm-rf.co.uk_

## About ##

SnoGE a security event visualisation tool, it takes in an event input feed from one of three data source types and proceeds to summarise and display those security events in a KML formatted file for use in a tool like Google Earth. Supported input modes are currently

  * Sort Unified files
  * CSV file
  * Sourcefire Estreamer (from Defense Center or 3D Sensor)

## Installation ##

These instructions were performed on a "clean" installation of Debian Lenny and they should be similar for any Debian based Linux distribution such as Ubuntu.

### Platform Set-up ###

SnoGE has multiple dependancies that you need to satisfy before it can run. Many of these dependancies may already be on your platform, others you will need to download and install yourself. Depending on the input mode you want to use, the dependancy list changes so you may not need everything.

Firstly lets install a few extra packages from Debian's repository to prepare our platform.
```
sudo apt-get install build-essential subversion apache2 unzip libio-socket-ssl-perl
```

### Download SnoGE from GoogleCode ###

For a "stable" installation, please use the latest tarball found in the downloads section. Those who like to live on the bleeding edge can check the source out of svn. You can expect the code in SVN to be broken, so it's best to start off with a tarball release unless you want bleeding edge features.

To download the latest tarsal visit http://googlecode.com/p/snoge/ . Once downloaded, copy and untar the archive into a tomporary location. In my example I will be using ~/Build (that equates to /home/<username/Build as an absolute path).

If you choose to download the bleeding edge Version from SVN (that is most likely broken), use the following command.

```
cd ~/Build
svn checkout http://snoge.googlecode.com/svn/trunk/ snoge-read-only
```

### Geolocation dependencies ###
Regardless of input mode, you will need to get hold of the Geolocation (looks up geographical location of an IP address) library for use in Perl. To do this you can use CPAN. A CPAN tutorial is out of scope for this document, if you are not familiar with it I suggest you google for a while.

If this is the first time you have used cpan, it may need configuring, and unless you are running some archaic version most of this configuration should be performed automatically.
```
cd ~/Build
sudo cpan -i Geo::IP::PurePerl
sudo cpan -i Module::Load
wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
gunzip ./GeoLiteCity.dat.gz
sudo mkdir /usr/local/share/GeoIP
sudo cp GeoLiteCity.dat /usr/local/share/GeoIP/
```

## Operation ##
SnoGE can operate in a one-shot mode where it processes a single unified or CSV file, writes an output KML, and then quits. It can also run in a more interesting auto-updating mode for use on big displays that SOC people like to hand on walls. The auto-update mode refreshes the event data every X seconds (this is a user controlled time value) and uses a static parent -> dynamic child operation style. The user opens the static parent KML file in their Google Earth client, this parent KML file makes the client (google earth) re-load the data from the clild KML every X seconds.


The below diagram hopefully explains this process a little better.

<img src='http://rm-rf.co.uk/downloads/SnoGE_Diagram1.png'>

To use the auto-update mode you will need a webserver to provide the client KML file running on the same system as the snoge process.<br>
<br>
Set up an output directory that can be accessed via http. You can of course complete a more secure / complex apache configuration, but this is out of scope for this install doc.<br>
<br>
<pre><code>sudo mkdir /var/www/snoge<br>
sudo chown lward /var/www/snoge<br>
</code></pre>

Firstly, lets test snoge in CSV mode to make sure that the Geolocation and your perl environment works as you would expect.<br>
<br>
<h3>Test SnoGE for CSV mode</h3>

./snoge.pl -c csv-example.conf --onefile example.csv -w /var/www/snoge/snoge.kml<br>
<br>
You should see output that looks a little like the below<br>
<br>
CSV File mode (processing example.csv)<br>
Processing CSV file example.csv...<br>
KML file /var/www/snoge/snogei.kml created.<br>
<br>
Open the KML file in google earth. If you have installed apache is installed on this device, you should be able to point a web browser to http://<br>
<br>
<hostname><br>
<br>
/snoge/snoge.kml<br>
<br>
Assuming this works, you can then move on to the next step of linking SnoGE into Snort, or Sourcefire's Defense Center.<br>
<br>
<br>
<h2>SnoGE and Snort</h2>

Snoge is able to process unified and unified2 log files by using Jason Brvenik's snort-unified-perl perl module that can be found on googlecode. To use SnoGE with Snort you need this installed and working.<br>
<br>
<pre><code>cd ~/Build<br>
wget http://snort-unified-perl.googlecode.com/files/SnortUnified_Perl.20100308.tgz<br>
cd snort-unified-perl/<br>
sudo cp SnortUnified.pm /usr/local/lib/perl/5.10.0<br>
sudo cp -r SnortUnified /usr/local/lib/perl/5.10.0<br>
cd ~/Build<br>
sudo cpan NetPacket::Ethernet<br>
</code></pre>

Find a unified1 alert, or a unified2 log file to test with, and give it a shot:<br>
<br>
./snoge -c unified-example.conf --onefile <unified file> -w /var/www/snoge/snoge.kml<br>
<br>
<pre><code>You should see output a little like this<br>
Unified mode * Importing functions:<br>
- Now processing unified file(s).....<br>
Working on single file /tmp/snort.alert.1248270139<br>
lward@snogeinstall:~/Dev/snoge$ <br>
</code></pre>

If something doesn't work, add a "-v" argument for verbose mode and try to work out what's not installed correctly on your platform.<br>
<br>
<h2>SnoGE and Sourcefire</h2>

Download version 4.8 of the Event Streamer SDK from the Sourcefire support website, it can be found tucked away under Downloads / 4.8 / Utilities / EventStreamerSDK-<br>
<br>
<version><br>
<br>
.zip. Once downloaded, copy the tarball onto the target system and place it in ~/Build. <b>DO NOT USE version 4.9 of the Estreamer SDK</b>, stick with 4.8. This doesn't prevent operation with version 4.9 of the 3D System, it works fine with the 4.8 SDK.<br>
<br>
<pre><code>cd ~/Build<br>
sudo cpan NetPacket::Ethernet<br>
unzip EventStreamerSDK-4.8.0.2.zip<br>
cd examples/perl_client/ <br>
sudo cp SFStreamer.pm /usr/local/lib/perl/5.10.0/<br>
</code></pre>

<h3>Complete the following tasks on your Defense Center, or 3D Sensor</h3>

<ol><li>Navigate to Operations / Configuration / Estreamer<br>
</li><li>Click on "Create Client"<br>
</li><li>Enter the IP address or Hostname of the system running SnoGE. Leave the password field blank<br>
</li><li>Download the generated certificate and copy it onto the host running Snoge<br>
</li><li>Convert the certificate from PKCS12 format  (hint -> openssl pkcs12 -nodes -in ~/192.168.222.136.pkcs12 > ~/certfile.txt )</li></ol>

<h3>Test SnoGE with Estreamer</h3>

Edit the estreamer-example.conf file, and enter the details for your Defense Center.<br>
<pre><code>lward@snogeinstall:~/Dev/snoge$ ./snoge -c estreamer-example.conf <br>
Estreamer Mode - Importing functions<br>
Connecting to DC 192.168.222.20<br>
Connected to DC 192.168.222.20 on 8302<br>
Processing estreamer data...<br>
&lt;It will stop here while it process's the event feed&gt;<br>
</code></pre>

If you want to find re-assurance that SnoGE is functioning, add the -v (verbose) option. It will look something more like this:<br>
<pre><code>lward@snogeinstall:~/Dev/snoge$ ./snoge -c snoge.conf -m estreamer -v -p<br>
Config: Input mode is estreamer<br>
CONFIG: Creating output file /dev/null  <br>
CONFIG: Adding a sensor for location  rm-rf.co.uk<br>
CONFIG: Adding a sensor for location  sourcefire.com<br>
CONFIG: Base filename is /var/log/snort/snort.alert<br>
CONFIG: Classification.confg set to /etc/snort/classification.config<br>
CONFIG: Ignoring SID 1421<br>
CONFIG: Ignoring SID 1000000001<br>
CONFIG: Ignoring SID 13948<br>
CONFIG: Ignoring SID 12801<br>
CONFIG: Images expected at http://rm-rf.co.uk/downloads/<br>
CONFIG: Using snorty.gif as the event icon<br>
CONFIG: Using warning.png as the event icon<br>
CONFIG: Using waldo file /dev/null <br>
Config: Sid-msg file is /etc/snort/sid-msg.map<br>
CONFIG: gen-msg file is /etc/snort/gen-msg.map<br>
CONFIG: Ignoring source ip 80.68.89.43<br>
CONFIG: Maximum number of placemarks set to 50 events <br>
CONFIG: Updateinterval set to 0 events <br>
CONFIG: Maximum number of events to track in bars  set to 4000  <br>
CONFIG: Default locarion set to rm-rf.co.uk.<br>
- Default Latitude set to 53.9667 <br>
- Default Longitude set to -1.08330000000001 <br>
- Defailt City - &gt; York United Kingdom<br>
CONFIG: Default latitude for unknown location set to 53.9667  <br>
CONFIG: Update URL is http://192.168.222.136/snoge/snoge.kml for serverKML<br>
CONFIG: Banner is snort-ge-banner.png in serverKML<br>
CONFIG: Refreshing every 5  <br>
CONFIG: Defense Center IP is 192.168.222.20<br>
CONFIG: Defense Center Port is 8302<br>
CONFIG: Defense Center SSL Cert is /home/lward/certfile.txt<br>
Estreamer Mode - Importing functions<br>
Connecting to DC 192.168.222.20<br>
Connected to DC 192.168.222.20 on 8302<br>
- Adding sensor rm-rf.co.uk in York, United Kingdom <br>
- Adding sensor sourcefire.com in Columbia, United States <br>
Processing estreamer data...<br>
********* New Event *********<br>
*  Got event Fri Mar 20 11:46:18 2009 1:1287 - WEB-IIS scripts access 192.168.10.128 -&gt; 64.127.109.133 : Pri 2 : Impact 3 : Flag Yellow<br>
ProcessEvent: <br>
                src_addr= 192.168.10.128<br>
                dst_addr= 64.127.109.133<br>
                style= Yellow<br>
                shortmsg= WEB-IIS scripts access<br>
                longmsg= Fri Mar 20 11:46:18 2009 1:1287 - WEB-IIS scripts access 192.168.10.128 -&gt; 64.127.109.133 : Priority 2 : Impact Yellow<br>
<br>
- DestIP 64.127.109.133 location found in San Francisco, United States<br>
- SrcIP 192.168.10.128 location unknown, defaulting to  -1.08330000000001, 53.9667<br>
* updating dists<br>
- Got city  <br>
- City is UnknownCity<br>
- Updating Dist for UnknownCity<br>
- 10 events are now in cache for UnknownCity<br>
* Got another 1 events, time to update KML file for the 10 time<br>
- Creating a KML file : /dev/null<br>
- Calculating Ingress Bars <br>
- 11 events in collection<br>
</code></pre>

<br>
<br>
<snip><br>
<br>
<br>
<br>
<i>Good luck, and happy plotting</i>.