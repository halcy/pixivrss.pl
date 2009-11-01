#!/usr/bin/perl

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Cookies;
use CGI;

# Config
my $PIXIV_ID = 'yourusername';
my $PASSWORD = 'yourpassword';
my $IMAGE_BASE_URL = 'http://url/for/images';
my $IMAGE_DIR = '/storage/directory/for/images';

# Set up LWP
my $ua;
$ua = LWP::UserAgent->new();
$ua->agent( 'Mozilla/5.0 Gecko/2009090217 Firefox' );
$ua->timeout( 60 );
my $cookie_jar = HTTP::Cookies->new(
	file => 'pixiv_cookie',
	autosave => '1',
);
$ua->cookie_jar( $cookie_jar );

# Log in
$ua->get( 'http://www.pixiv.net/' ) or die( 'Getting mainpage failed.' );
$ua->post(
	'http://www.pixiv.net/index.php',
	Content => [
		mode  => 'login',
		pixiv_id => $PIXIV_ID,
		pass => $PASSWORD,
	],
) or die "Login failed!";

# Grab New Illust
my $res = $ua->get( 'http://www.pixiv.net/bookmark_new_illust.php' );
if( !$res->is_success() ) {
	die( "Getting new illust failed." );
}

# Preparse
my $html = $res->content();
$html =~ s/illust_c5">(.*)<script type="text\/javascript"/$1/s;

# Output header
print <<RSS
Content-type: application/xhtml+xml

<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
  <channel>
    <title>Pixiv</title>
    <icon>http://www.pixiv.net/favicon.ico</icon>
    <link>http://www.pixiv.net/</link>
    <description>Pixiv bookmarks</description>
    <language>ja</language>
    <ttl>30</ttl>
RSS
;

# Parse and output.
while( $html =~ /<a href="([^"]*)".*?src="([^"]*)".*?alt="([^"]*)".*?<br/gi ) {

	# Get fields.
	my $desc = $3;
	my $url = $1;
	my $thumb = $2;
	my ($user,$thumb_file) = ($thumb =~ m|img/([^/]*)/(.*)$|);

	# Sanitize. You never know. YOU NEVER KNOW.
	$thumb_file =~ s/(?:\.\.|\$|\/)//gi;
	my $thumb_save = $IMAGE_DIR . $thumb_file;
	
	# Grab thumb, if need to.
	if( !-e $thumb_file ) {
		system(
			'wget',
			'-q',
			'--referer=http://www.pixiv.net/',
			'--user-agent=Mozilla/5.0 Gecko/2009090217 Firefox',
			'-O',
			$thumb_save,
			$thumb,
		);
	}
	
	# Build RSS item.
	$url =~ s/&/&amp;/;
	print "<item>\n";
	print "<title>$user: $desc</title>\n";
	print "<description><![CDATA[";
	print '<img src="' . $IMAGE_BASE_URL . $thumb_file . '" />';
	print "]]></description>\n";
	print "<guid>http://www.pixiv.net/$url</guid>\n";
	print "<link>http://www.pixiv.net/$url</link>\n";
	print "</item>\n";
}

# Output footer
print "</channel>\n</rss>\n";
