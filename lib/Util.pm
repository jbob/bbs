package Util;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw (
    printslow
    print_state_new
    print_state_main
    print_message
    get_key
    get_input
);

use Time::HiRes qw(usleep);
use Term::ReadKey;
use Text::ASCIITable; # Text::ANSITable is way to fancy

sub printslow {
    $| = 1; # Autoflush
    my $input = shift;
    for my $c (split '', $input) {
        print $c;
        usleep(1000*25); # 25ms ~ 300Baud
    }
}

sub print_state_new {
    printslow "Hello there\n";
    printslow "Welcome to the super awesomme bbs!\n";
    printslow "[L]og in\n";
    printslow "[G]uest usage\n";
    printslow "[R]egister\n";
    printslow "[Q]uit\n";
}

sub print_state_main {
    my $posts = shift;
    my $auth = shift;
    printslow sprintf "Number of messages: %s\n", $posts->count;
    printslow "Current messages:\n";
    my $table = Text::ASCIITable->new;
    $table->setCols(qw(# Subject Author Date));
    my $cnt = 1;
    for my $post (@{ $posts->all }) {
        $table->addRow($cnt, $post->subject, $post->user->name, $post->date);
        ++$cnt;
    }
    printslow $table;
    printslow "\n";
    printslow "[#] Read message\n";
    printslow "[Q]uit\n";
}

sub print_message {
    my $posts = shift;
    my $post_nr = shift;
    my $post = @{ $posts->all }[$post_nr - 1]; # Probably not the fastest method.
    printslow sprintf "Author: %s\n", $post->user->name;
    printslow sprintf "Subject: %s\n", $post->subject;
    printslow sprintf "Date (UTC): %s\n", $post->date;
    printslow sprintf "%s\n", $post->text;
    printslow "\n";
    printslow "[#] Read other message\n";
    printslow "[L]ist messages again\n";
    printslow "[Q]uit\n";
}

sub get_key {
    ReadMode 4;
    my $input = ReadKey(0);
    ReadMode 0;
    return $input
}

sub get_input {
    my $input = <>;
    chomp $input;
    return $input;
}

1;
