package Util;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw (
    printslow
    print_state_new
    print_state_main
    print_message
    log_in
    register
    get_key
    get_input
    get_text
);

use Time::HiRes qw(usleep);
use Term::ReadKey;
use Text::ASCIITable; # Text::ANSITable is way to fancy
use File::Temp qw/tempfile/;
use Text::Autoformat;



sub printslow {
    $| = 1; # Autoflush
    my $input = shift;
    for my $c (split '', $input) {
        print $c;
        usleep(1000*25*0.5); # 25ms ~ 300Baud; 12.5ms ~ 600Baud
    }
}

sub print_state_new {
    my $greeting = <<'EOF';
              | |
 __      _____| | ___ ___  _ __ ___   ___
 \ \ /\ / / _ \ |/ __/ _ \| '_ ` _ \ / _ \
  \ V  V /  __/ | (_| (_) | | | | | |  __/
   \_/\_/_\___|_|\___\___/|_| |_| |_|\___|
        | |        | | | |
        | |_ ___   | |_| |__   ___
        | __/ _ \  | __| '_ \ / _ \
        | || (_) | | |_| | | |  __/
         \__\___/  _\__|_|_|_|\___|
            |  _ \|  _ \ / ____|
            | |_) | |_) | (___
            |  _ <|  _ < \___ \
            | |_) | |_) |____) |
            |____/|____/|_____/
EOF
    printslow $greeting;
    printslow "\n";
    printslow "[L]og in\n";
    printslow "[G]uest usage\n";
    printslow "[R]egister\n";
    printslow "[Q]uit\n";
}

sub print_state_main {
    my $posts = shift;
    my $session = shift;
    printslow sprintf "Number of messages: %s\n", $posts->count;
    printslow "Current messages:\n";
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
    return $input
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
    my $ret = system('nano', $filename);
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
    return autoformat($newcontent, { all => 1 });
}

1;
