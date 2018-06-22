#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use DateTime;

binmode(STDOUT, ":utf8");
binmode(STDIN, ":utf8");

use MyModel;
use Util qw(
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

my $states = {
    NEW => 0,
    GUEST => 1,
    LOGGING_IN => 2,
    LOGGED_IN => 3,
    LOGGED_OUT => 4,
    MAIN => 5,
    MESSAGE_LIST => 6,
    MESSAGE_DISPLAY => 7,
    WRITE_MESSAGE => 8,
    REGISTER => 9,
    REPLY => 10
};

my $connection = MyModel->connect('mongodb://127.0.0.1/bbs');
my $users = $connection->collection('user');
my $posts = $connection->collection('post');

my $session = {};
$session->{state} = $states->{NEW};
$session->{page} = 0; # Paging of message list

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

while ($session->{state} != $states->{LOGGED_OUT}) {
    if ($session->{state} == $states->{NEW}) {
        print_state_new;
        my $input = get_key;
        if ($input =~ m/l/i) {
            $session->{state} = $states->{LOGGING_IN};
        } elsif ($input =~ m/g/i) {
            $session->{state} = $states->{MESSAGE_LIST};
            $session->{auth} = 0;
        } elsif ($input =~ m/r/i) {
            $session->{state} = $states->{REGISTER};
        } elsif ($input =~ m/q/i) {
            $session->{state} = $states->{LOGGED_OUT};
        } elsif ($input =~ m/a/i) {
            print_about;
	    $session->{state} = $states->{NEW};
	}
    } elsif ($session->{state} == $states->{LOGGING_IN}) {
        $session->{user} = log_in $users;
        printslow sprintf "Welcome back %s\n", $session->{user}->name;
        $session->{state} = $states->{MESSAGE_LIST};
    } elsif ($session->{state} == $states->{REGISTER}) {
        $session->{user} = register $users ;
        printslow sprintf "Welcome %s\n", $session->{user}->name;
        $session->{state} = $states->{MESSAGE_LIST};
    } elsif ($session->{state} == $states->{MESSAGE_LIST}) {
        print_state_main($posts, $session);
        my $input = get_key;
        if ($input =~ m/#/i) {
            printslow "#: ";
            $session->{post_nr} = get_input;
            $session->{state} = $states->{MESSAGE_DISPLAY};
        } elsif ($input =~ m/w/i) {
            $session->{state} = $states->{WRITE_MESSAGE};
        } elsif ($input =~ m/n/i) {
            ++$session->{page};
        } elsif ($input =~ m/p/i) {
            --$session->{page};
            $session->{page} = 0 if $session->{page} < 0;
        } elsif ($input =~ m/f/i) {
            fefe;
        } elsif ($input =~ m/q/i) {
            $session->{state} = $states->{LOGGED_OUT};
        }
    } elsif ($session->{state} == $states->{WRITE_MESSAGE}) {
        if (not $session->{user}) {
            printslow "Only for registered users!\n";
            $session->{state} = $states->{NEW};
        } else {
            $session->{state} = $states->{MESSAGE_LIST}; # After we are done
            printslow "Subject: ";
            my $subject = get_input;
            my $text = get_text "Your text goes here!";
            my $date = DateTime->now;
            if (not $text or not $subject) {
                printslow "Ok then, you changed your mind. That is fine.\n";
            } else {
                $subject =~ s/.{45}\K.*//s; # truncate; substr doesn't like if the string is to short
                my $post = $posts->create({ subject => $subject, text => $text, date => $date});
                $post->user($session->{user} || 'Anonymous');
                $post->save;
            }
        }
    } elsif ($session->{state} == $states->{MESSAGE_DISPLAY}) {
        print_message($posts, $session->{post_nr});
        my $input = get_key;
        if ($input =~ m/#/i) {
            printslow "#: ";
            $session->{post_nr} = get_input;
        } elsif ($input =~ m/r/i) {
            $session->{state} = $states->{REPLY};
        } elsif ($input =~ m/l/i) {
            $session->{state} = $states->{MESSAGE_LIST};
        } elsif ($input =~ m/q/i) {
            $session->{state} = $states->{LOGGED_OUT};
        }
    } elsif ($session->{state} == $states->{REPLY}) {
        if (not $session->{user}) {
            printslow "Only for registered users!\n";
            $session->{state} = $states->{NEW};
            delete $session->{post_nr};
        } else {
            $session->{state} = $states->{MESSAGE_LIST}; # After we are done
            my $reply_to = @{ $posts->all }[$session->{post_nr} - 1];
            my $subject = $reply_to->subject;
            $subject =~s/^Re: //;
            $subject = sprintf "Re: %s", $subject;
            $subject =~ s/.{45}\K.*//s; # truncate; substr doesn't like if the string is to short
            my $quote = $reply_to->text;
            $quote =~ s/^/: /m;
            $quote = sprintf "On %s, %s wrote:\n%s\n", $reply_to->date, $reply_to->user->name, $quote;
            my $text = get_text $quote;
            my $date = DateTime->now;
            if (not $text or not $subject) {
                printslow "Ok then, you changed your mind. That is fine.\n";
            } else {
                my $post = $posts->create({ subject => $subject, text => $text, date => $date, parent => $reply_to });
                $post->user($session->{user} || 'Anonymous');
                $post->save;
            }
            delete $session->{post_nr};
        }
    }
}
printslow("OK, bye for now\n")


# Mandel Cheat-Sheet:

# Fields
# User;                                                          
#   name => ( isa => Str );                                                   
#   pw => ( isa => Str );                                                     
#   has_many posts => 'MyModel::Post';                                              
# Post;                                                          
#   subject => ( isa => Str );                                                
#   date => ( isa => DateTimeUTC );                                           
#   belongs_to user => 'MyModel::User';                                           
#   text => ( isa => Str );                                                   
#   has_one parent => 'MyModel::Post';          

## Find all posts by user
#for my $p (@{ $u1->posts }) {
#  warn $p->subject;
#  warn $p->user->name;
#  warn $p->date;
#}
