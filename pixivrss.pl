#!/usr/bin/perl

# pixivrss.pl - Pixiv "bookmarks" RSS feed generator.

# (c) 2009 L. Diener, licensed under the WTFPL, see below.

#             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                     Version 2, December 2004
#
#  Copyright (C) 2004 Sam Hocevar
#   14 rue de Plaisance, 75014 Paris, France
#  Everyone is permitted to copy and distribute verbatim or modified
#  copies of this license document, and changing it is allowed as long
#  as the name is changed.
#
#             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#    TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#   0. You just DO WHAT THE FUCK YOU WANT TO.

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Cookies;
use CGI;

# Config
my $PIXIV_ID = 'username';
my $PASSWORD = 'password';
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
        'https://www.secure.pixiv.net/login.php',
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
$html =~ s/.*<ul class="_image-items autopagerize_page_element">(.*)<\/ul>.*/$1/s;

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
while( $html =~ /(mode=medium&amp;illust_id=\d*)".*?<h1 class="title" title="([^"]*)".*?data-user_name="([^"]*)".*?<img src="([^"]*)"/gi ) {


        # Get fields.
        my $desc = $2;
        my $url = $1;
        $url = "member_illust.php?$url";
        my $user = $3;
        my $thumb = $4;
        my ($thumb_file) = ($thumb =~ m|img/[^/]*/(.*)$|);

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
