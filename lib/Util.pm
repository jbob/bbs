package Util;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw (
    printslow
    print_about
    print_state_new
    print_state_main
    print_message
    log_in
    register
    get_key
    get_input
    get_text
    fefe
);

use Time::HiRes qw(usleep);
use Term::ReadKey;
use Text::ASCIITable; # Text::ANSITable is way to fancy
use File::Temp qw/tempfile/;
use Text::Autoformat;
use XML::RSS::Parser::Lite;
use LWP::Simple;

sub printslow {
    $| = 1; # Autoflush
    my $input = shift;
    for my $c (split '', $input) {
        print $c;
        usleep(1000*25*0.3); # 25ms ~ 300Baud; 12.5ms ~ 600Baud
    }
}

sub print_about {
    my $about_text = <<'EOF';
    This bbs software/system is brought to you by jbob.

    Why?

    Your upload filters, imprints, gdpr and other bullshit has now power here.

    How?

    Perl and MongoDB of course

    I wan't feature X!

    Then write a message, ideally with "feature request" or something like this in the subject.

    Is it secure?

    You are using telnet to connect, passwords are not encrypted and there might very well be security bugs in the code.
    This is all part of the retro experience. Think of this more as art instead of professional software.

    Why is it so slow?

    Also part of the retro experience, ... bitch!

    Code?

    Currently sady only via http/git:

    $ git clone https://github.com/jbob/bbs.git
EOF
    printslow "\n";
    printslow autoformat $about_text, { all => 1 };
    printslow "\n";

}

sub print_state_new {
    printslow "[L]og in\n";
    printslow "[G]uest usage\n";
    printslow "[R]egister\n";
    printslow "[A]bout\n";
    printslow "[Q]uit\n";
}

sub print_state_main {
    my $posts = shift;
    my $session = shift;
    my $table = Text::ASCIITable->new;
    $table->setOptions('hide_FirstLine', 1);
    #$table->setOptions('hide_HeadLine', 1);
    $table->setOptions('hide_LastLine', 1);
    $table->setCols(qw(# Subject Author Date));
    my $cnt = $posts->count;
    my $pagesize = 7;
    my @all_posts = reverse @{ $posts->all };
    #--$session->{page} while $session->{page} * $pagesize > scalar @all_posts;

    $cnt -= $session->{page} * $pagesize; # Subtract already displayed messages
    for my $post (@all_posts[$session->{page}*$pagesize .. $session->{page}*$pagesize+$pagesize]) {
        last if $cnt == 0;
        $table->addRow($cnt, $post->subject, $post->user->name, $post->date);
        --$cnt;
        last if $posts->count >= $cnt+$pagesize*($session->{page}+1);
    }
    printslow $table;
    printslow "\n";
    printslow "[#] Read message\n";
    printslow "[N]ext message page\n";
    printslow "[P]revious message page\n";
    printslow "[W]rite new message\n";
    printslow "[F]efes Blog Reader\n";
    printslow "[Q]uit\n";
}

sub print_message {
    my $posts = shift;
    my $post_nr = shift;
    my $post = @{ $posts->all }[$post_nr - 1]; # Probably not the fastest method.
    if (not $post) {
        printslow "Nope";
        exit 1;
    }
    printslow sprintf "Author: %s\n", $post->user->name;
    printslow sprintf "Subject: %s\n", $post->subject;
    printslow sprintf "Date (UTC): %s\n", $post->date;
    printslow "\n";
    printslow sprintf "%s\n", $post->text;
    printslow "\n";
    printslow "[#] Read other message\n";
    printslow "[R]eply to message\n";
    printslow "[L]ist messages again\n";
    printslow "[Q]uit\n";
}

sub log_in {
    my $users = shift;
    printslow "Username: ";
    my $username = get_input();
    printslow "Password: ";
    my $password = get_secret_input();
    if (not $username or not $password) {
        printslow "You should have entered something\n";
        exit 1;
    }
    $username =~ s/\p{XPosixCntrl}//g; # Sanitize;
    my $clone = $users->search({ name => $username });
    if ($clone->count != 1) {
        printslow "Nope\n";
        exit 1;
    }
    if ($clone->single->pw ne $password) {
        printslow "Nope\n";
        exit 1;
    }
    return $clone->single;;
}

sub register {
    my $users = shift;
    printslow "Username: ";
    my $username = get_input();
    printslow "Password: ";
    my $password = get_secret_input();
    printslow "Password (again): ";
    my $password2 = get_secret_input();
    if ($password ne $password2) {
        printslow "Passwords do not match!\n";
        exit 1;
    }
    if (not $username or not $password) {
        printslow "You should have entered something\n";
        exit 1;
    }
    $username =~ s/\p{XPosixCntrl}//g; # Sanitize;
    my $clone = $users->search({ name => $username });
    if ($clone->count != 0) {
        printslow "Username already taken\n";
        exit 1;
    }
    my $user = $users->create({ name => $username, pw => $password});
    $user->save;
    return $user;
}

sub get_key {
    ReadMode 4;
    my $input = ReadKey(0);
    ReadMode 0;
    return $input;
}

sub get_secret_input {
    ReadMode 2;
    my $input = <>;
    ReadMode 0;
    chomp $input;
    printslow "\n"; # for the return which wasn't echod
    return $input;
}

sub get_input {
    my $input = <>;
    chomp $input;
    return $input;
}

sub get_text {
    my $content = shift;
    my ($fh, $filename) = tempfile("text_edit_XXXXX", DIR => '/tmp');
    print $fh  $content;
    close $fh;
    $ENV{LC_CTYPE} = 'en_US.UTF8';
    my $ret = system('rnano', $filename); # Restricted nano; UTF8 mode
    unless ($ret == 0) {
        my $err;
        if ($? == -1) {
           $err = "system call failed: $!\n";
        } elsif ($? & 127) {
           $err = sprintf "system call died with signal %d, %s coredump\n",
                          ($? & 127), ($? & 128) ? 'with' : 'without';
        }
        unlink $filename;
        printslow $err;
        exit 1;
    }
    open $fh, "<:encoding(UTF-8)", $filename or die "Couldn't open $filename: $!";
    my $newcontent = do { local $/; <$fh> };
    close $fh;
    unlink $filename;
    return if $content eq $newcontent;
    return autoformat $newcontent, { all => 1 };
}

sub fefe {
    printslow "Working...\n";
    my $xml = get('http://blog.fefe.de/rss.xml');
    my $rp = XML::RSS::Parser::Lite->new;
    $rp->parse($xml);

    my $output = sprintf "The latest from %s:\n\n", $rp->get('title');
    #for (my $i; $i < $rp->count(); $i++) {
    for (my $i; $i < 5; $i++) {
        my $it = $rp->get($i);
	$output .= sprintf "* %s -- %s\n\n", $it->get('title'), $it->get('url');
    }
    printslow autoformat $output, { all => 1 };
    printslow "\n\n";
}

1;
